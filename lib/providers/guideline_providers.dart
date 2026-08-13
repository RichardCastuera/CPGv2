import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/guideline_list_item.dart';
import '../services/bookmark_manager.dart';
import '../services/download_manager.dart';
import '../services/local_db.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService.instance);

final localDbProvider = Provider<LocalDb>((ref) {
  final db = LocalDb();
  ref.onDispose(db.close);
  return db;
});

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(
    supabaseService: ref.watch(supabaseServiceProvider),
    db: ref.watch(localDbProvider),
  );
});

final bookmarkManagerProvider = Provider<BookmarkManager>((ref) {
  return BookmarkManager(
    db: ref.watch(localDbProvider),
    service: ref.watch(supabaseServiceProvider),
  );
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final showArchivedProvider = StateProvider<bool>((ref) => false);

/// Local download rows, keyed by guideline_id, kept live via Drift's watch stream.
final downloadedGuidelinesStreamProvider = StreamProvider<List<DownloadedGuideline>>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchDownloadedGuidelines();
});

/// Guidelines + their current version, merged with local download state.
/// Re-evaluates whenever the local downloads stream emits, so download/sync
/// actions are reflected immediately without a manual refresh.
final guidelineListProvider = FutureProvider<List<GuidelineListItem>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final downloadedAsync = ref.watch(downloadedGuidelinesStreamProvider);
  final downloaded = downloadedAsync.asData?.value ?? const <DownloadedGuideline>[];
  final downloadedById = {for (final d in downloaded) d.guidelineId: d};

  final guidelines = await service.fetchGuidelines();

  final items = <GuidelineListItem>[];
  for (final g in guidelines) {
    if (g.currentVersionId == null) continue;
    final version = await service.fetchCurrentVersion(g.id);
    if (version == null) continue;

    final local = downloadedById[g.id];
    final state = local == null
        ? DownloadState.notDownloaded
        : (local.versionId == version.id ? DownloadState.downloaded : DownloadState.updateAvailable);

    items.add(GuidelineListItem(
      guideline: g,
      version: version,
      downloadState: state,
      lastSyncedAt: local?.downloadedAt,
    ));
  }
  return items;
});

/// Search + Published/Archived-filtered view — what the "All guidelines"
/// section actually renders.
final filteredGuidelineListProvider = Provider<AsyncValue<List<GuidelineListItem>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final showArchived = ref.watch(showArchivedProvider);
  final asyncItems = ref.watch(guidelineListProvider);

  return asyncItems.whenData((items) {
    return items.where((item) {
      final matchesQuery = query.isEmpty || item.guideline.title.toLowerCase().contains(query);
      final matchesArchived = showArchived ? item.isArchived : !item.isArchived;
      return matchesQuery && matchesArchived;
    }).toList();
  });
});

/// "Continue reading" row — downloaded guidelines, most recently synced first.
final continueReadingProvider = Provider<AsyncValue<List<GuidelineListItem>>>((ref) {
  final asyncItems = ref.watch(guidelineListProvider);
  return asyncItems.whenData((items) {
    final downloaded = items.where((i) => i.downloadState != DownloadState.notDownloaded).toList()
      ..sort((a, b) => (b.lastSyncedAt ?? DateTime(0)).compareTo(a.lastSyncedAt ?? DateTime(0)));
    return downloaded.take(4).toList();
  });
});

/// "Featured & recently updated" — everything not already in Continue reading,
/// most recently updated first (server already orders by updated_at).
final featuredProvider = Provider<AsyncValue<List<GuidelineListItem>>>((ref) {
  final asyncItems = ref.watch(guidelineListProvider);
  return asyncItems.whenData((items) => items.take(6).toList());
});

/// Bookmarked entity IDs, for quick "is this bookmarked" lookups in cards.
final bookmarkedIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(localDbProvider);
  return db.watchBookmarks().map((rows) => rows.map((b) => b.entityId).toSet());
});

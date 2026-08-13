import 'package:drift/drift.dart' show Value;

import 'local_db.dart';
import 'supabase_service.dart';

/// Bridges bookmark writes between the local Drift DB (what the Saved tab
/// and the bookmark icons actually read from — local-first, works offline)
/// and Supabase (for cross-device sync once a device reconnects).
///
/// Local write always happens and always succeeds instantly; the Supabase
/// call is best-effort. `synced` tracks whether the remote write actually
/// went through, so a future retry pass (e.g. on reconnect) knows what
/// still needs pushing — see `LocalDb.unsyncedBookmarks()`.
class BookmarkManager {
  final LocalDb db;
  final SupabaseService service;

  BookmarkManager({required this.db, required this.service});

  Future<void> add({
    required String entityType,
    required String entityId,
    required String guidelineId,
    required String title,
  }) async {
    await db.addBookmark(BookmarksCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      guidelineId: guidelineId,
      title: title,
      synced: const Value(false),
    ));

    try {
      await service.addBookmark(entityType: entityType, entityId: entityId);
      await db.addBookmark(BookmarksCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        guidelineId: guidelineId,
        title: title,
        synced: const Value(true),
      ));
    } catch (_) {
      // Offline or the request failed — the bookmark still exists locally
      // and shows up in Saved immediately; it's just not synced remotely yet.
    }
  }

  Future<void> remove({required String entityType, required String entityId}) async {
    await db.removeBookmark(entityType, entityId);
    try {
      await service.removeBookmark(entityType: entityType, entityId: entityId);
    } catch (_) {
      // Best-effort — local removal is already reflected in the UI regardless.
    }
  }

  Future<void> clearAll(List<Bookmark> current) async {
    for (final b in current) {
      await remove(entityType: b.entityType, entityId: b.entityId);
    }
  }

  /// Retries pushing any bookmarks that were added/removed while offline.
  /// Call this opportunistically (e.g. on app resume, or when connectivity
  /// is restored) to reconcile local-only bookmarks with Supabase.
  Future<void> retrySync() async {
    final pending = await db.unsyncedBookmarks();
    for (final b in pending) {
      try {
        await service.addBookmark(entityType: b.entityType, entityId: b.entityId);
        await db.addBookmark(BookmarksCompanion.insert(
          entityType: b.entityType,
          entityId: b.entityId,
          guidelineId: b.guidelineId,
          title: b.title,
          synced: const Value(true),
        ));
      } catch (_) {
        // still offline or still failing — leave unsynced, try again next time
      }
    }
  }
}

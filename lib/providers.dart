import 'package:cpg_reader/core/database/app_database.dart';
import 'package:cpg_reader/models/guideline.dart';
import 'package:cpg_reader/models/guideline_library_item.dart';
import 'package:cpg_reader/models/guideline_version.dart';
import 'package:cpg_reader/repositories/guideline_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final guidelineRepositoryProvider = Provider<GuidelineRepository>(
  (ref) => GuidelineRepository(ref.read(appDatabaseProvider)),
);

final libraryStreamProvider = StreamProvider<List<GuidelineLibraryItem>>(
  (ref) => ref
      .watch(guidelineRepositoryProvider)
      .watchLibrary(statusFilter: ['published', 'archived']),
);

final downloadedLibraryStreamProvider =
    StreamProvider<List<GuidelineLibraryItem>>(
      (ref) => ref
          .watch(guidelineRepositoryProvider)
          .watchLibrary(downloadedOnly: true),
    );

final guidelineProvider = StreamProvider.family<Guideline?, String>(
  (ref, guidelineId) =>
      ref.watch(guidelineRepositoryProvider).watchGuideline(guidelineId),
);

final currentVersionProvider = StreamProvider.family<GuidelineVersion?, String>(
  (ref, guidelineId) =>
      ref.watch(guidelineRepositoryProvider).watchCurrentVersion(guidelineId),
);

import 'package:cpg_reader/core/database/app_database.dart';
import 'package:cpg_reader/core/downloads/download_manager.dart';
import 'package:cpg_reader/models/artifact.dart';
import 'package:cpg_reader/models/guideline.dart';
import 'package:cpg_reader/models/guideline_library_item.dart';
import 'package:cpg_reader/models/guideline_version.dart';
import 'package:cpg_reader/models/question.dart';
import 'package:cpg_reader/models/reference.dart';
import 'package:cpg_reader/models/recommendation.dart';
import 'package:cpg_reader/models/section.dart';
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

final sectionsStreamProvider = StreamProvider.family<List<Section>, String>(
  (ref, versionId) =>
      ref.watch(guidelineRepositoryProvider).watchSections(versionId),
);

final questionsStreamProvider = StreamProvider.family<List<Question>, String>(
  (ref, sectionId) =>
      ref.watch(guidelineRepositoryProvider).watchQuestions(sectionId),
);

final recommendationsStreamProvider =
    StreamProvider.family<List<Recommendation>, String>(
      (ref, questionId) => ref
          .watch(guidelineRepositoryProvider)
          .watchRecommendations(questionId),
    );

final artifactsStreamProvider = StreamProvider.family<List<Artifact>, String>(
  (ref, guidelineId) =>
      ref.watch(guidelineRepositoryProvider).watchArtifacts(guidelineId),
);

final referencesStreamProvider = StreamProvider.family<List<Reference>, String>(
  (ref, guidelineId) =>
      ref.watch(guidelineRepositoryProvider).watchReferences(guidelineId),
);

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(
    ref.read(appDatabaseProvider),
    ref.read(guidelineRepositoryProvider),
  );
});

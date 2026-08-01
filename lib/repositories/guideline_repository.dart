import 'package:drift/drift.dart';
import '../core/database/app_database.dart';
import '../core/supabase/supabase_client.dart';
import '../models/guideline.dart';
import '../models/guideline_author.dart';
import '../models/guideline_version.dart';
import '../models/section.dart';
import '../models/question.dart';
import '../models/recommendation.dart';
import '../models/artifact.dart';
import '../models/reference.dart';
import 'mappers.dart';

/// Local-first: every read method streams from Drift. Sync methods hit
/// Supabase and write results into Drift — the UI never talks to
/// Supabase directly. This is what lets every screen work offline by
/// default, with sync just being "more/fresher rows show up."
class GuidelineRepository {
  final AppDatabase _db;
  final _supabase = SupabaseService.client;

  GuidelineRepository(this._db);

  // ------------------------------------------------------------
  // LOCAL READS (what the UI actually calls)
  // ------------------------------------------------------------

  /// Library screen — all cached guidelines, optionally filtered.
  Stream<List<Guideline>> watchLibrary({
    List<String>?
    statusFilter, // e.g. ['published'] or ['published','archived']
    bool downloadedOnly = false,
  }) {
    final query = _db.select(_db.guidelines);
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query.where((g) => g.status.isIn(statusFilter));
    }
    if (downloadedOnly) {
      query.where((g) => g.isDownloaded.equals(true));
    }
    return query.watch().map((rows) => rows.map(guidelineFromRow).toList());
  }

  Stream<Guideline?> watchGuideline(String guidelineId) {
    final query = _db.select(_db.guidelines)
      ..where((g) => g.id.equals(guidelineId));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : guidelineFromRow(row),
    );
  }

  Stream<GuidelineVersion?> watchCurrentVersion(String guidelineId) {
    final query = _db.select(_db.guidelineVersions)
      ..where((v) => v.guidelineId.equals(guidelineId))
      ..where((v) => v.status.equals('published'));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : versionFromRow(row),
    );
  }

  Stream<List<GuidelineAuthor>> watchAuthors(String guidelineId) {
    final query = _db.select(_db.guidelineAuthors)
      ..where((a) => a.guidelineId.equals(guidelineId))
      ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]);
    return query.watch().map((rows) => rows.map(authorFromRow).toList());
  }

  Stream<List<Section>> watchSections(String versionId) {
    final query = _db.select(_db.sections)
      ..where((s) => s.versionId.equals(versionId))
      ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]);
    return query.watch().map((rows) => rows.map(sectionFromRow).toList());
  }

  Stream<List<Question>> watchQuestions(String sectionId) {
    final query = _db.select(_db.questions)
      ..where((q) => q.sectionId.equals(sectionId))
      ..orderBy([(q) => OrderingTerm.asc(q.sortOrder)]);
    return query.watch().map((rows) => rows.map(questionFromRow).toList());
  }

  Stream<List<Recommendation>> watchRecommendations(String questionId) {
    final query = _db.select(_db.recommendations)
      ..where((r) => r.questionId.equals(questionId))
      ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]);
    return query.watch().map(
      (rows) => rows.map(recommendationFromRow).toList(),
    );
  }

  Stream<List<Artifact>> watchArtifacts(String guidelineId) {
    final query = _db.select(_db.artifacts)
      ..where((a) => a.guidelineId.equals(guidelineId));
    return query.watch().map((rows) => rows.map(artifactFromRow).toList());
  }

  Stream<List<Reference>> watchReferences(String guidelineId) {
    final query =
        _db.select(_db.guidelineReferences).join([
            innerJoin(
              _db.references,
              _db.references.id.equalsExp(_db.guidelineReferences.referenceId),
            ),
          ])
          ..where(_db.guidelineReferences.guidelineId.equals(guidelineId))
          ..orderBy([OrderingTerm.asc(_db.guidelineReferences.sortOrder)]);
    return query.watch().map(
      (rows) => rows
          .map((row) => referenceFromRow(row.readTable(_db.references)))
          .toList(),
    );
  }

  // ------------------------------------------------------------
  // REMOTE SYNC (writes into Drift; UI finds out via the streams above)
  // ------------------------------------------------------------

  /// Fetch the guideline list (metadata only — no tree) and upsert into
  /// Drift. Call this on app start and on reconnect. Cheap: one query.
  Future<int> syncLibrary() async {
    final response = await _supabase.from('guidelines').select().inFilter(
      'status',
      ['published', 'archived'],
    );

    final remote = (response as List)
        .map((row) => Guideline.fromJson(row))
        .toList();

    await _db.transaction(() async {
      for (final g in remote) {
        // Preserve local-only download state on update.
        final existing = await (_db.select(
          _db.guidelines,
        )..where((row) => row.id.equals(g.id))).getSingleOrNull();

        await _db
            .into(_db.guidelines)
            .insertOnConflictUpdate(
              guidelineToCompanion(
                g,
                isDownloaded: existing?.isDownloaded ?? false,
                downloadedAt: existing?.downloadedAt,
                localSizeBytes: existing?.localSizeBytes,
              ),
            );
      }
    });

    return remote.length;
  }

  /// Fetch the full tree for one guideline (version, sections, questions,
  /// recommendations, artifacts, references) and upsert into Drift.
  /// Call this when opening a Guideline Overview screen (to make sure
  /// it's current) and as part of the download flow (Phase 6).
  Future<void> syncGuidelineDetail(String guidelineId) async {
    // -- version (only the published one is visible per RLS) --
    final versionRes = await _supabase
        .from('guideline_versions')
        .select()
        .eq('guideline_id', guidelineId)
        .eq('status', 'published')
        .maybeSingle();
    if (versionRes == null) return; // nothing published for this guideline
    final version = GuidelineVersion.fromJson(versionRes);

    // -- authors --
    final authorsRes = await _supabase
        .from('guideline_authors')
        .select()
        .eq('guideline_id', guidelineId)
        .order('sort_order');
    final authors = (authorsRes as List)
        .map((row) => GuidelineAuthor.fromJson(row))
        .toList();

    // -- sections --
    final sectionsRes = await _supabase
        .from('sections')
        .select()
        .eq('version_id', version.id)
        .order('sort_order');
    final sections = (sectionsRes as List)
        .map((row) => Section.fromJson(row))
        .toList();

    // -- questions (all sections at once, split client-side) --
    final sectionIds = sections.map((s) => s.id).toList();
    final questionsRes = sectionIds.isEmpty
        ? []
        : await _supabase
              .from('questions')
              .select()
              .inFilter('section_id', sectionIds)
              .order('sort_order');
    final questions = (questionsRes as List)
        .map((row) => Question.fromJson(row))
        .toList();

    // -- recommendations (all questions at once) --
    final questionIds = questions.map((q) => q.id).toList();
    final recsRes = questionIds.isEmpty
        ? []
        : await _supabase
              .from('recommendations')
              .select()
              .inFilter('question_id', questionIds)
              .order('sort_order');
    final recommendations = (recsRes as List)
        .map((row) => Recommendation.fromJson(row))
        .toList();

    // -- artifacts --
    final artifactsRes = await _supabase
        .from('artifacts')
        .select()
        .eq('guideline_id', guidelineId);
    final artifacts = (artifactsRes as List)
        .map((row) => Artifact.fromJson(row))
        .toList();

    // -- references (via join table) --
    final refJoinRes = await _supabase
        .from('guideline_references')
        .select('sort_order, references(*)')
        .eq('guideline_id', guidelineId)
        .order('sort_order');
    final references = (refJoinRes as List)
        .map((row) => Reference.fromJson(row['references']))
        .toList();

    // -- write everything in one transaction --
    await _db.transaction(() async {
      final existingVersion = await (_db.select(
        _db.guidelineVersions,
      )..where((row) => row.id.equals(version.id))).getSingleOrNull();

      await _db
          .into(_db.guidelineVersions)
          .insertOnConflictUpdate(
            versionToCompanion(
              version,
              localPdfPath: existingVersion?.localPdfPath,
            ),
          );

      for (final a in authors) {
        await _db
            .into(_db.guidelineAuthors)
            .insertOnConflictUpdate(authorToCompanion(a));
      }
      for (final s in sections) {
        await _db
            .into(_db.sections)
            .insertOnConflictUpdate(sectionToCompanion(s));
      }
      for (final q in questions) {
        await _db
            .into(_db.questions)
            .insertOnConflictUpdate(questionToCompanion(q));
      }
      for (final r in recommendations) {
        await _db
            .into(_db.recommendations)
            .insertOnConflictUpdate(recommendationToCompanion(r));
      }
      for (final art in artifacts) {
        final existingArtifact = await (_db.select(
          _db.artifacts,
        )..where((row) => row.id.equals(art.id))).getSingleOrNull();
        await _db
            .into(_db.artifacts)
            .insertOnConflictUpdate(
              artifactToCompanion(
                art,
                localFilePath: existingArtifact?.localFilePath,
              ),
            );
      }
      for (final ref in references) {
        await _db
            .into(_db.references)
            .insertOnConflictUpdate(referenceToCompanion(ref));
        await _db
            .into(_db.guidelineReferences)
            .insertOnConflictUpdate(
              GuidelineReferencesCompanion.insert(
                guidelineId: guidelineId,
                referenceId: ref.id,
              ),
            );
      }
    });
  }
}

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ------------------------------------------------------------
// Mirrors of the Supabase tables actually needed offline.
// Notably excluded: profiles, audit_log, comments, guideline_versions'
// draft/in_review/superseded rows (RLS already filters those out
// server-side — no reason to cache what the app can never see).
// ------------------------------------------------------------

@DataClassName('GuidelineRow')
class Guidelines extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get shortTitle => text().nullable()();
  TextColumn get guidelineType => text()(); // 'Compendium' | 'Interim'
  TextColumn get specialtyTags => text()(); // JSON-encoded List<String>
  TextColumn get societies => text()(); // JSON-encoded List<String>
  TextColumn get doi => text().nullable()();
  TextColumn get status => text()(); // 'published' | 'archived'
  TextColumn get currentVersionId => text().nullable()();
  DateTimeColumn get nextReviewDate => dateTime().nullable()();

  // ---- client-only columns, no Supabase equivalent ----
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  IntColumn get localSizeBytes => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GuidelineAuthorRow')
class GuidelineAuthors extends Table {
  TextColumn get id => text()();
  TextColumn get guidelineId => text().references(Guidelines, #id)();
  TextColumn get name => text()();
  TextColumn get position => text()();
  TextColumn get affiliation => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GuidelineVersionRow')
class GuidelineVersions extends Table {
  TextColumn get id => text()();
  TextColumn get guidelineId => text().references(Guidelines, #id)();
  TextColumn get versionNumber => text()();
  TextColumn get status => text()();
  TextColumn get changelog => text().nullable()();
  DateTimeColumn get effectiveDate => dateTime().nullable()();
  TextColumn get sourcePdfUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  // Local path once the full PDF has been downloaded to device storage.
  TextColumn get localPdfPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SectionRow')
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get versionId => text().references(GuidelineVersions, #id)();
  TextColumn get title => text()();
  TextColumn get overview => text().nullable()(); // JSON-encoded Tiptap doc
  TextColumn get status => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QuestionRow')
class Questions extends Table {
  TextColumn get id => text()();
  TextColumn get sectionId => text().references(Sections, #id)();
  TextColumn get title => text()();
  TextColumn get clinicalQuestion => text().nullable()();
  TextColumn get background => text().nullable()(); // JSON-encoded Tiptap doc
  TextColumn get status => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecommendationRow')
class Recommendations extends Table {
  TextColumn get id => text()();
  TextColumn get questionId => text().references(Questions, #id)();
  TextColumn get title => text()();
  TextColumn get number => text().nullable()();
  TextColumn get strength => text().nullable()();
  TextColumn get certaintyOfEvidence => text().nullable()();
  TextColumn get statement => text().nullable()(); // JSON-encoded Tiptap doc
  TextColumn get comment => text().nullable()(); // JSON-encoded Tiptap doc
  TextColumn get evidenceSummary =>
      text().nullable()(); // JSON-encoded Tiptap doc
  TextColumn get status => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ArtifactRow')
class Artifacts extends Table {
  TextColumn get id => text()();
  TextColumn get guidelineId => text().references(Guidelines, #id)();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get caption => text().nullable()();
  TextColumn get storagePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();

  // Local path once this specific artifact file has been downloaded.
  TextColumn get localFilePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReferenceRow')
class References extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get citation => text()();
  TextColumn get doiOrUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class GuidelineReferences extends Table {
  TextColumn get guidelineId => text().references(Guidelines, #id)();
  TextColumn get referenceId => text().references(References, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {guidelineId, referenceId};
}

@DriftDatabase(
  tables: [
    Guidelines,
    GuidelineAuthors,
    GuidelineVersions,
    Sections,
    Questions,
    Recommendations,
    Artifacts,
    References,
    GuidelineReferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cpg_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

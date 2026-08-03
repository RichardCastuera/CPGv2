import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('GuidelineRow')
class Guidelines extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get shortTitle => text().nullable()();
  TextColumn get guidelineType => text()();
  TextColumn get specialtyTags => text()(); // JSON-encoded List<String>
  TextColumn get societies => text()(); // JSON-encoded List<String>
  TextColumn get doi => text().nullable()();
  TextColumn get status => text()();
  TextColumn get currentVersionId => text().nullable()();
  DateTimeColumn get nextReviewDate => dateTime().nullable()();

  // NEW (schema v2) — embedded authors, JSON-encoded List<GuidelineAuthor>.
  // Replaces reliance on the separate GuidelineAuthors table below.
  TextColumn get authors => text().withDefault(const Constant('[]'))();

  // ---- client-only columns, no Supabase equivalent ----
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  IntColumn get localSizeBytes => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// Kept for now (harmless if unused) in case any old cached rows still
// reference it, and in case the CMS team reverts. Repository code no
// longer reads or writes to this table as of the authors-embedding
// change — safe to drop entirely in a future migration once confirmed
// unnecessary.
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
  TextColumn get localPdfPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SectionRow')
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get versionId => text().references(GuidelineVersions, #id)();
  TextColumn get title => text()();
  TextColumn get overview => text().nullable()();
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
  TextColumn get background => text().nullable()();
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
  TextColumn get statement => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get evidenceSummary => text().nullable()();
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

@DataClassName('GuidelineReferenceRow')
class GuidelineReferences extends Table {
  TextColumn get guidelineId => text().references(Guidelines, #id)();
  TextColumn get referenceId => text().references(References, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {guidelineId, referenceId};
}

// NEW (schema v2) — mirrors public.app_settings: flat key/value config,
// global, not guideline-scoped (feature flags, maintenance banner, etc).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON-encoded jsonb value
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
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
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // authors column added to the existing Guidelines table
        await m.addColumn(guidelines, guidelines.authors);
        // brand new table
        await m.createTable(appSettings);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cpg_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

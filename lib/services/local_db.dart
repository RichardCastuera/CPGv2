import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_db.g.dart';

/// One row per downloaded guideline. Keyed by version_id so a re-download
/// only happens when the version actually changes (per the offline sync spec).
class DownloadedGuidelines extends Table {
  TextColumn get guidelineId => text()();
  TextColumn get versionId => text()();
  TextColumn get title => text()();
  TextColumn get guidelineType => text()();
  TextColumn get status => text()(); // published | archived
  TextColumn get versionNumber => text()();
  DateTimeColumn get effectiveDate => dateTime().nullable()();
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {guidelineId};
}

/// Flattened content rows (section/question/recommendation) for a downloaded
/// version — this is both what renders the tree offline AND what the local
/// keyword search index runs against.
class DownloadedContent extends Table {
  TextColumn get id => text()();
  TextColumn get guidelineId => text()();
  TextColumn get versionId => text()();
  TextColumn get entityType => text()(); // section | question | recommendation
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get plainText => text()(); // flattened Tiptap -> plain text
  TextColumn get rawJson => text()(); // original JSON blob for full rendering
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Bookmarks extends Table {
  TextColumn get entityType => text()(); // guideline | question | recommendation
  TextColumn get entityId => text()();
  TextColumn get guidelineId => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

@DriftDatabase(tables: [DownloadedGuidelines, DownloadedContent, Bookmarks])
class LocalDb extends _$LocalDb {
  LocalDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Downloads -----------------------------------------------------

  Future<void> upsertDownloadedGuideline(DownloadedGuidelinesCompanion row) =>
      into(downloadedGuidelines).insertOnConflictUpdate(row);

  Future<DownloadedGuideline?> getDownloadedGuideline(String guidelineId) =>
      (select(downloadedGuidelines)..where((t) => t.guidelineId.equals(guidelineId)))
          .getSingleOrNull();

  Stream<List<DownloadedGuideline>> watchDownloadedGuidelines() =>
      select(downloadedGuidelines).watch();

  Future<void> removeDownload(String guidelineId) async {
    await (delete(downloadedGuidelines)..where((t) => t.guidelineId.equals(guidelineId))).go();
    await (delete(downloadedContent)..where((t) => t.guidelineId.equals(guidelineId))).go();
  }

  Future<void> replaceContentForVersion(
    String guidelineId,
    String versionId,
    List<DownloadedContentCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(downloadedContent)..where((t) => t.versionId.equals(versionId))).go();
      await batch((b) => b.insertAll(downloadedContent, rows));
    });
  }

  Future<List<DownloadedContentData>> contentForVersion(String versionId) =>
      (select(downloadedContent)..where((t) => t.versionId.equals(versionId))).get();

  // --- Local keyword search (offline fallback) ------------------------

  /// All downloaded content rows across every guideline — the search index
  /// the on-device chatbot fallback scores against (see localSearch below).
  Future<List<DownloadedContentData>> allDownloadedContent() =>
      select(downloadedContent).get();

  // --- Bookmarks (local-first, synced separately) ----------------------

  Future<void> addBookmark(BookmarksCompanion row) =>
      into(bookmarks).insertOnConflictUpdate(row);

  Future<void> removeBookmark(String entityType, String entityId) =>
      (delete(bookmarks)
            ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId)))
          .go();

  Stream<List<Bookmark>> watchBookmarks() => select(bookmarks).watch();

  Future<List<Bookmark>> unsyncedBookmarks() =>
      (select(bookmarks)..where((t) => t.synced.equals(false))).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cpg_offline.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

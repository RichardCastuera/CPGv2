import 'package:drift/drift.dart' show Value;

import '../core/tiptap.dart';
import '../models/guideline_list_item.dart';
import 'local_db.dart';
import 'supabase_service.dart';

class DownloadManager {
  final SupabaseService supabaseService;
  final LocalDb db;

  DownloadManager({required this.supabaseService, required this.db});

  /// Downloads (or re-downloads, if the version changed) the full content
  /// tree for [item]'s current version and stores it locally, keyed by
  /// version_id so unrelated versions of other guidelines are unaffected.
  Future<void> download(GuidelineListItem item) async {
    final guideline = item.guideline;
    final version = item.version;

    final sections = await supabaseService.fetchVersionTree(version.id);
    final rows = <DownloadedContentCompanion>[];
    int approxSize = 0;

    for (final section in sections) {
      final sectionText = '${section.title}. ${tiptapToText(section.overview)}';
      approxSize += sectionText.length;
      rows.add(DownloadedContentCompanion.insert(
        id: section.id,
        guidelineId: guideline.id,
        versionId: version.id,
        entityType: 'section',
        parentId: const Value(null),
        title: section.title,
        plainText: sectionText,
        rawJson: '{}', // full Tiptap JSON persistence can be added when the
        // rich-text renderer needs it; plain text is enough for offline
        // search + a readable fallback view.
        sortOrder: Value(section.sortOrder),
      ));

      for (final question in section.questions) {
        final qText =
            '${question.title}. ${question.clinicalQuestion ?? ''}. ${tiptapToText(question.background)}';
        approxSize += qText.length;
        rows.add(DownloadedContentCompanion.insert(
          id: question.id,
          guidelineId: guideline.id,
          versionId: version.id,
          entityType: 'question',
          parentId: Value(section.id),
          title: question.title,
          plainText: qText,
          rawJson: '{}',
          sortOrder: Value(question.sortOrder),
        ));

        for (final rec in question.recommendations) {
          final rText =
              '${rec.title}. Strength: ${rec.strength ?? 'n/a'}. ${tiptapToText(rec.statement)}';
          approxSize += rText.length;
          rows.add(DownloadedContentCompanion.insert(
            id: rec.id,
            guidelineId: guideline.id,
            versionId: version.id,
            entityType: 'recommendation',
            parentId: Value(question.id),
            title: rec.title,
            plainText: rText,
            rawJson: '{}',
            sortOrder: Value(rec.sortOrder),
          ));
        }
      }
    }

    await db.replaceContentForVersion(guideline.id, version.id, rows);
    await db.upsertDownloadedGuideline(DownloadedGuidelinesCompanion.insert(
      guidelineId: guideline.id,
      versionId: version.id,
      title: guideline.title,
      guidelineType: guideline.guidelineType.name,
      status: version.status.name,
      versionNumber: version.versionNumber,
      effectiveDate: Value(version.effectiveDate),
      sizeBytes: Value(approxSize),
    ));

    await supabaseService.recordSync(guidelineId: guideline.id, versionId: version.id);
  }

  Future<void> remove(String guidelineId) => db.removeDownload(guidelineId);
}

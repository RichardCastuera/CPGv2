import 'package:drift/drift.dart' show Value;
import 'dart:convert';
import '../core/database/app_database.dart';
import '../models/guideline.dart';
import '../models/guideline_author.dart';
import '../models/guideline_version.dart';
import '../models/section.dart';
import '../models/question.dart';
import '../models/recommendation.dart';
import '../models/artifact.dart';
import '../models/reference.dart';
import '../models/enums.dart';

// ------------------------------------------------------------
// Guideline
// ------------------------------------------------------------

GuidelinesCompanion guidelineToCompanion(
  Guideline g, {
  bool? isDownloaded,
  DateTime? downloadedAt,
  int? localSizeBytes,
}) {
  return GuidelinesCompanion.insert(
    id: g.id,
    title: g.title,
    shortTitle: Value(g.shortTitle),
    guidelineType: g.guidelineType.name,
    specialtyTags: jsonEncode(g.specialtyTags),
    societies: jsonEncode(g.societies),
    doi: Value(g.doi),
    status: g.status.name,
    currentVersionId: Value(g.currentVersionId),
    nextReviewDate: Value(g.nextReviewDate),
    isDownloaded: Value(isDownloaded ?? false),
    downloadedAt: Value(downloadedAt),
    localSizeBytes: Value(localSizeBytes),
  );
}

Guideline guidelineFromRow(GuidelineRow row) {
  return Guideline(
    id: row.id,
    title: row.title,
    shortTitle: row.shortTitle,
    guidelineType: GuidelineType.values.byName(row.guidelineType),
    specialtyTags: (jsonDecode(row.specialtyTags) as List).cast<String>(),
    societies: (jsonDecode(row.societies) as List).cast<String>(),
    doi: row.doi,
    status: GuidelineStatus.values.byName(row.status),
    currentVersionId: row.currentVersionId,
    nextReviewDate: row.nextReviewDate,
  );
}

// ------------------------------------------------------------
// GuidelineAuthor
// ------------------------------------------------------------

GuidelineAuthorsCompanion authorToCompanion(GuidelineAuthor a) {
  return GuidelineAuthorsCompanion.insert(
    id: a.id,
    guidelineId: a.guidelineId,
    name: a.name,
    position: a.position,
    affiliation: Value(a.affiliation),
    sortOrder: Value(a.sortOrder),
  );
}

GuidelineAuthor authorFromRow(GuidelineAuthorRow row) {
  return GuidelineAuthor(
    id: row.id,
    guidelineId: row.guidelineId,
    name: row.name,
    position: row.position,
    affiliation: row.affiliation,
    sortOrder: row.sortOrder,
  );
}

// ------------------------------------------------------------
// GuidelineVersion
// ------------------------------------------------------------

GuidelineVersionsCompanion versionToCompanion(
  GuidelineVersion v, {
  String? localPdfPath,
}) {
  return GuidelineVersionsCompanion.insert(
    id: v.id,
    guidelineId: v.guidelineId,
    versionNumber: v.versionNumber,
    status: v.status.name,
    changelog: Value(v.changelog),
    effectiveDate: Value(v.effectiveDate),
    sourcePdfUrl: Value(v.sourcePdfUrl),
    publishedAt: Value(v.publishedAt),
    localPdfPath: Value(localPdfPath),
  );
}

GuidelineVersion versionFromRow(GuidelineVersionRow row) {
  return GuidelineVersion(
    id: row.id,
    guidelineId: row.guidelineId,
    versionNumber: row.versionNumber,
    status: VersionStatus.values.byName(row.status),
    changelog: row.changelog,
    effectiveDate: row.effectiveDate,
    sourcePdfUrl: row.sourcePdfUrl,
    publishedAt: row.publishedAt,
  );
}

// ------------------------------------------------------------
// Section
// ------------------------------------------------------------

SectionsCompanion sectionToCompanion(Section s) {
  return SectionsCompanion.insert(
    id: s.id,
    versionId: s.versionId,
    title: s.title,
    overview: Value(s.overview == null ? null : jsonEncode(s.overview)),
    status: s.status.name,
    sortOrder: Value(s.sortOrder),
  );
}

Section sectionFromRow(SectionRow row) {
  return Section(
    id: row.id,
    versionId: row.versionId,
    title: row.title,
    overview: row.overview == null
        ? null
        : jsonDecode(row.overview!) as Map<String, dynamic>,
    status: NodeStatus.values.byName(row.status),
    sortOrder: row.sortOrder,
  );
}

// ------------------------------------------------------------
// Question
// ------------------------------------------------------------

QuestionsCompanion questionToCompanion(Question q) {
  return QuestionsCompanion.insert(
    id: q.id,
    sectionId: q.sectionId,
    title: q.title,
    clinicalQuestion: Value(q.clinicalQuestion),
    background: Value(q.background == null ? null : jsonEncode(q.background)),
    status: q.status.name,
    sortOrder: Value(q.sortOrder),
  );
}

Question questionFromRow(QuestionRow row) {
  return Question(
    id: row.id,
    sectionId: row.sectionId,
    title: row.title,
    clinicalQuestion: row.clinicalQuestion,
    background: row.background == null
        ? null
        : jsonDecode(row.background!) as Map<String, dynamic>,
    status: NodeStatus.values.byName(row.status),
    sortOrder: row.sortOrder,
  );
}

// ------------------------------------------------------------
// Recommendation
// ------------------------------------------------------------

RecommendationsCompanion recommendationToCompanion(Recommendation r) {
  return RecommendationsCompanion.insert(
    id: r.id,
    questionId: r.questionId,
    title: r.title,
    number: Value(r.number),
    strength: Value(r.strength),
    certaintyOfEvidence: Value(r.certaintyOfEvidence),
    statement: Value(r.statement == null ? null : jsonEncode(r.statement)),
    comment: Value(r.comment == null ? null : jsonEncode(r.comment)),
    evidenceSummary: Value(
      r.evidenceSummary == null ? null : jsonEncode(r.evidenceSummary),
    ),
    status: r.status.name,
    sortOrder: Value(r.sortOrder),
  );
}

Recommendation recommendationFromRow(RecommendationRow row) {
  return Recommendation(
    id: row.id,
    questionId: row.questionId,
    title: row.title,
    number: row.number,
    strength: row.strength,
    certaintyOfEvidence: row.certaintyOfEvidence,
    statement: row.statement == null
        ? null
        : jsonDecode(row.statement!) as Map<String, dynamic>,
    comment: row.comment == null
        ? null
        : jsonDecode(row.comment!) as Map<String, dynamic>,
    evidenceSummary: row.evidenceSummary == null
        ? null
        : jsonDecode(row.evidenceSummary!) as Map<String, dynamic>,
    status: NodeStatus.values.byName(row.status),
    sortOrder: row.sortOrder,
  );
}

// ------------------------------------------------------------
// Artifact
// ------------------------------------------------------------

ArtifactsCompanion artifactToCompanion(Artifact a, {String? localFilePath}) {
  return ArtifactsCompanion.insert(
    id: a.id,
    guidelineId: a.guidelineId,
    name: a.name,
    category: a.category.name,
    caption: Value(a.caption),
    storagePath: a.storagePath,
    mimeType: a.mimeType,
    sizeBytes: a.sizeBytes,
    localFilePath: Value(localFilePath),
  );
}

Artifact artifactFromRow(ArtifactRow row) {
  return Artifact(
    id: row.id,
    guidelineId: row.guidelineId,
    name: row.name,
    category: ArtifactCategory.values.byName(row.category),
    caption: row.caption,
    storagePath: row.storagePath,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
  );
}

// ------------------------------------------------------------
// Reference
// ------------------------------------------------------------

ReferencesCompanion referenceToCompanion(Reference r) {
  return ReferencesCompanion.insert(
    id: r.id,
    label: r.label,
    citation: r.citation,
    doiOrUrl: Value(r.doiOrUrl),
  );
}

Reference referenceFromRow(ReferenceRow row) {
  return Reference(
    id: row.id,
    label: row.label,
    citation: row.citation,
    doiOrUrl: row.doiOrUrl,
  );
}

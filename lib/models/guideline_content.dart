import 'enums.dart';

/// Maps to public.guideline_versions
class GuidelineVersion {
  final String id;
  final String guidelineId;
  final String versionNumber;
  final VersionStatus status;
  final String? changelog;
  final DateTime? effectiveDate;
  final String? sourcePdfUrl;
  final DateTime? publishedAt;

  const GuidelineVersion({
    required this.id,
    required this.guidelineId,
    required this.versionNumber,
    required this.status,
    this.changelog,
    this.effectiveDate,
    this.sourcePdfUrl,
    this.publishedAt,
  });

  factory GuidelineVersion.fromJson(Map<String, dynamic> json) {
    return GuidelineVersion(
      id: json['id'] as String,
      guidelineId: json['guideline_id'] as String,
      versionNumber: json['version_number'] as String,
      status: VersionStatus.fromString(json['status'] as String),
      changelog: json['changelog'] as String?,
      effectiveDate: json['effective_date'] != null
          ? DateTime.parse(json['effective_date'] as String)
          : null,
      sourcePdfUrl: json['source_pdf_url'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
    );
  }
}

/// Maps to public.sections. `overview` is stored as Tiptap JSON server-side;
/// keep it as a raw Map here and flatten/render it in the UI layer.
class GuidelineSection {
  final String id;
  final String versionId;
  final String title;
  final Map<String, dynamic>? overview;
  final int sortOrder;
  final List<GuidelineQuestion> questions;

  const GuidelineSection({
    required this.id,
    required this.versionId,
    required this.title,
    this.overview,
    this.sortOrder = 0,
    this.questions = const [],
  });

  factory GuidelineSection.fromJson(Map<String, dynamic> json) {
    return GuidelineSection(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      title: json['title'] as String,
      overview: json['overview'] as Map<String, dynamic>?,
      sortOrder: json['sort_order'] as int? ?? 0,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => GuidelineQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Maps to public.questions
class GuidelineQuestion {
  final String id;
  final String sectionId;
  final String title;
  final String? clinicalQuestion;
  final Map<String, dynamic>? background;
  final int sortOrder;
  final List<Recommendation> recommendations;

  const GuidelineQuestion({
    required this.id,
    required this.sectionId,
    required this.title,
    this.clinicalQuestion,
    this.background,
    this.sortOrder = 0,
    this.recommendations = const [],
  });

  factory GuidelineQuestion.fromJson(Map<String, dynamic> json) {
    return GuidelineQuestion(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      title: json['title'] as String,
      clinicalQuestion: json['clinical_question'] as String?,
      background: json['background'] as Map<String, dynamic>?,
      sortOrder: json['sort_order'] as int? ?? 0,
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Maps to public.recommendations
class Recommendation {
  final String id;
  final String questionId;
  final String title;
  final String? number;
  final String? strength;
  final String? certaintyOfEvidence;
  final Map<String, dynamic>? statement;
  final int sortOrder;

  const Recommendation({
    required this.id,
    required this.questionId,
    required this.title,
    this.number,
    this.strength,
    this.certaintyOfEvidence,
    this.statement,
    this.sortOrder = 0,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      title: json['title'] as String,
      number: json['number'] as String?,
      strength: json['strength'] as String?,
      certaintyOfEvidence: json['certainty_of_evidence'] as String?,
      statement: json['statement'] as Map<String, dynamic>?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Maps to public.guideline_authors — distinct from the `authors` jsonb
/// column on `guidelines`; this is the structured, per-author table with
/// position/affiliation, which is what the Authors section on the detail
/// screen actually renders.
class GuidelineAuthorRow {
  final String id;
  final String guidelineId;
  final String name;
  final String position;
  final String? affiliation;
  final int sortOrder;

  const GuidelineAuthorRow({
    required this.id,
    required this.guidelineId,
    required this.name,
    required this.position,
    this.affiliation,
    this.sortOrder = 0,
  });

  factory GuidelineAuthorRow.fromJson(Map<String, dynamic> json) {
    return GuidelineAuthorRow(
      id: json['id'] as String,
      guidelineId: json['guideline_id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      affiliation: json['affiliation'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Maps to public.references
class GuidelineReference {
  final String id;
  final String label;
  final String citation;
  final String? doiOrUrl;

  const GuidelineReference({
    required this.id,
    required this.label,
    required this.citation,
    this.doiOrUrl,
  });

  factory GuidelineReference.fromJson(Map<String, dynamic> json) {
    return GuidelineReference(
      id: json['id'] as String,
      label: json['label'] as String,
      citation: json['citation'] as String,
      doiOrUrl: json['doi_or_url'] as String?,
    );
  }
}

/// Maps to public.artifacts
class GuidelineArtifact {
  final String id;
  final String guidelineId;
  final String name;
  final String category;
  final String? caption;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final String? sectionId;
  final String? questionId;

  const GuidelineArtifact({
    required this.id,
    required this.guidelineId,
    required this.name,
    required this.category,
    this.caption,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    this.sectionId,
    this.questionId,
  });

  factory GuidelineArtifact.fromJson(Map<String, dynamic> json) {
    return GuidelineArtifact(
      id: json['id'] as String,
      guidelineId: json['guideline_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      caption: json['caption'] as String?,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      sectionId: json['section_id'] as String?,
      questionId: json['question_id'] as String?,
    );
  }
}

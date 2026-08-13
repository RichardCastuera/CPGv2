import 'enums.dart';

/// Maps to public.guidelines
class Guideline {
  final String id;
  final String title;
  final String? shortTitle;
  final GuidelineType guidelineType;
  final List<String> specialtyTags;
  final List<String> societies;
  final String? doi;
  final GuidelineStatus status;
  final String? currentVersionId;
  final DateTime? nextReviewDate;
  final List<Map<String, dynamic>> authors;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Guideline({
    required this.id,
    required this.title,
    this.shortTitle,
    required this.guidelineType,
    this.specialtyTags = const [],
    this.societies = const [],
    this.doi,
    required this.status,
    this.currentVersionId,
    this.nextReviewDate,
    this.authors = const [],
    this.source = 'authored',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Guideline.fromJson(Map<String, dynamic> json) {
    return Guideline(
      id: json['id'] as String,
      title: json['title'] as String,
      shortTitle: json['short_title'] as String?,
      guidelineType: GuidelineType.fromString(json['guideline_type'] as String),
      specialtyTags: List<String>.from(json['specialty_tags'] ?? const []),
      societies: List<String>.from(json['societies'] ?? const []),
      doi: json['doi'] as String?,
      status: GuidelineStatus.fromString(json['status'] as String),
      currentVersionId: json['current_version_id'] as String?,
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'] as String)
          : null,
      authors: List<Map<String, dynamic>>.from(json['authors'] ?? const []),
      source: json['source'] as String? ?? 'authored',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'short_title': shortTitle,
        'guideline_type': guidelineType.name,
        'specialty_tags': specialtyTags,
        'societies': societies,
        'doi': doi,
        'status': status.name,
        'current_version_id': currentVersionId,
        'next_review_date': nextReviewDate?.toIso8601String(),
        'authors': authors,
        'source': source,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';
import 'guideline_author.dart';
import 'guideline_version.dart';

part 'guideline.freezed.dart';
part 'guideline.g.dart';

/// Flat row shape, matching the `guidelines` table exactly.
@freezed
class Guideline with _$Guideline {
  const factory Guideline({
    required String id,
    required String title,
    @JsonKey(name: 'short_title') String? shortTitle,
    @JsonKey(name: 'guideline_type') required GuidelineType guidelineType,
    @JsonKey(name: 'specialty_tags') @Default([]) List<String> specialtyTags,
    @Default([]) List<String> societies,
    String? doi,
    required GuidelineStatus status,
    @JsonKey(name: 'current_version_id') String? currentVersionId,
    @JsonKey(name: 'next_review_date') DateTime? nextReviewDate,
  }) = _Guideline;

  factory Guideline.fromJson(Map<String, dynamic> json) =>
      _$GuidelineFromJson(json);
}

/// Composite shape the reader actually consumes: a Guideline plus
/// its (single, published) current version and its authors —
/// assembled by the repository layer in Phase 4 via a join query,
/// not a 1:1 mirror of any single table.
@freezed
class GuidelineDetail with _$GuidelineDetail {
  const factory GuidelineDetail({
    required Guideline guideline,
    required GuidelineVersion currentVersion,
    @Default([]) List<GuidelineAuthor> authors,
  }) = _GuidelineDetail;
}

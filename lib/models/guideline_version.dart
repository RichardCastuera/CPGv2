import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'guideline_version.freezed.dart';
part 'guideline_version.g.dart';

@freezed
class GuidelineVersion with _$GuidelineVersion {
  const factory GuidelineVersion({
    required String id,
    @JsonKey(name: 'guideline_id') required String guidelineId,
    @JsonKey(name: 'version_number') required String versionNumber,
    required VersionStatus status,
    String? changelog,
    @JsonKey(name: 'effective_date') DateTime? effectiveDate,
    @JsonKey(name: 'source_pdf_url') String? sourcePdfUrl,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
  }) = _GuidelineVersion;

  factory GuidelineVersion.fromJson(Map<String, dynamic> json) =>
      _$GuidelineVersionFromJson(json);
}

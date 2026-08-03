import 'package:freezed_annotation/freezed_annotation.dart';

part 'guideline_author.freezed.dart';
part 'guideline_author.g.dart';

@freezed
class GuidelineAuthor with _$GuidelineAuthor {
  const factory GuidelineAuthor({
    String? id,
    @JsonKey(name: 'guideline_id') String? guidelineId,
    required String name,
    required String position,
    String? affiliation,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _GuidelineAuthor;

  factory GuidelineAuthor.fromJson(Map<String, dynamic> json) =>
      _$GuidelineAuthorFromJson(json);
}

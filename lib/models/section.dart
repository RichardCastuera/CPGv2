import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'section.freezed.dart';
part 'section.g.dart';

@freezed
class Section with _$Section {
  const factory Section({
    required String id,
    @JsonKey(name: 'version_id') required String versionId,
    required String title,
    // Raw Tiptap JSON — parsed by the renderer built in Phase 2.5.
    Map<String, dynamic>? overview,
    required NodeStatus status,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _Section;

  factory Section.fromJson(Map<String, dynamic> json) =>
      _$SectionFromJson(json);
}

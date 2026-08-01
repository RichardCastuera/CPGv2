import 'package:freezed_annotation/freezed_annotation.dart';

part 'reference.freezed.dart';
part 'reference.g.dart';

@freezed
class Reference with _$Reference {
  const factory Reference({
    required String id,
    required String label,
    required String citation,
    @JsonKey(name: 'doi_or_url') String? doiOrUrl,
  }) = _Reference;

  factory Reference.fromJson(Map<String, dynamic> json) =>
      _$ReferenceFromJson(json);
}

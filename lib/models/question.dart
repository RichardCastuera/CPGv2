import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'question.freezed.dart';
part 'question.g.dart';

@freezed
class Question with _$Question {
  const factory Question({
    required String id,
    @JsonKey(name: 'section_id') required String sectionId,
    required String title,
    @JsonKey(name: 'clinical_question') String? clinicalQuestion,
    Map<String, dynamic>? background,
    required NodeStatus status,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

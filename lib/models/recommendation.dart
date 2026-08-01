import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'recommendation.freezed.dart';
part 'recommendation.g.dart';

@freezed
class Recommendation with _$Recommendation {
  const factory Recommendation({
    required String id,
    @JsonKey(name: 'question_id') required String questionId,
    required String title,
    String? number,
    String? strength,
    @JsonKey(name: 'certainty_of_evidence') String? certaintyOfEvidence,
    Map<String, dynamic>? statement,
    Map<String, dynamic>? comment,
    @JsonKey(name: 'evidence_summary') Map<String, dynamic>? evidenceSummary,
    required NodeStatus status,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}

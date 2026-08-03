import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'artifact.freezed.dart';
part 'artifact.g.dart';

@freezed
class Artifact with _$Artifact {
  const factory Artifact({
    required String id,
    @JsonKey(name: 'guideline_id') required String guidelineId,
    required String name,
    required ArtifactCategory category,
    String? caption,
    @JsonKey(name: 'storage_path') required String storagePath,
    @JsonKey(name: 'mime_type') required String mimeType,
    @JsonKey(name: 'size_bytes') required int sizeBytes,
    @JsonKey(name: 'local_file_path') String? localFilePath,
  }) = _Artifact;

  factory Artifact.fromJson(Map<String, dynamic> json) =>
      _$ArtifactFromJson(json);

  const Artifact._();

  /// Resolves storage_path -> a public Supabase Storage URL.
  /// Filled in properly once the SupabaseClient is wired (Phase 4) —
  /// placeholder signature so callers don't need to change later.
}

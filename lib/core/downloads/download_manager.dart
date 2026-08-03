import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../supabase/supabase_client.dart';
import '../../models/artifact.dart';
import '../../repositories/guideline_repository.dart';

class DownloadProgress {
  final int bytesDownloaded;
  final int totalBytes; // -1 if not yet known (e.g. before PDF headers arrive)
  final String currentFileName;

  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.currentFileName,
  });

  double get fraction =>
      totalBytes <= 0 ? 0 : (bytesDownloaded / totalBytes).clamp(0, 1);
}

class DownloadCancelledException implements Exception {}

/// Tracks in-flight downloads so the UI can offer a cancel button per
/// guideline (matches the "Downloading — cancel (X)" state from the design).
class _CancelToken {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

class DownloadManager {
  final AppDatabase _db;
  final GuidelineRepository _repository;
  final _supabase = SupabaseService.client;
  final _httpClient = http.Client();

  final Map<String, _CancelToken> _activeTokens = {};

  DownloadManager(this._db, this._repository);

  /// Downloads everything needed for offline access to one guideline:
  /// the structured content (already handled by syncGuidelineDetail),
  /// every artifact file, and the full source PDF — bundled as a
  /// single operation per the "PDF is mandatory, not opt-in" decision.
  Future<void> downloadGuideline(
    String guidelineId, {
    required void Function(DownloadProgress) onProgress,
  }) async {
    final token = _CancelToken();
    _activeTokens[guidelineId] = token;

    try {
      // Ensure we have the latest metadata before downloading files —
      // avoids downloading artifacts for a stale/removed recommendation.
      await _repository.syncGuidelineDetail(guidelineId);

      final versionRow =
          await (_db.select(_db.guidelineVersions)
                ..where((v) => v.guidelineId.equals(guidelineId))
                ..where((v) => v.status.equals('published')))
              .getSingleOrNull();
      if (versionRow == null) {
        throw StateError(
          'No published version found for $guidelineId — sync may have failed.',
        );
      }

      final artifactRows = await (_db.select(
        _db.artifacts,
      )..where((a) => a.guidelineId.equals(guidelineId))).get();

      final docsDir = await getApplicationDocumentsDirectory();
      final guidelineDir = Directory(
        p.join(docsDir.path, 'downloads', guidelineId),
      );
      await guidelineDir.create(recursive: true);

      // Known sizes up front (artifacts.size_bytes is stored in the
      // schema); PDF size isn't known until its response headers arrive,
      // so overall progress is approximate until that request starts.
      final knownArtifactBytes = artifactRows.fold<int>(
        0,
        (sum, a) => sum + a.sizeBytes,
      );
      int cumulativeDownloaded = 0;
      int runningTotalEstimate = knownArtifactBytes;
      int actualTotalOnDisk = 0;

      // -- artifacts --
      for (final artifact in artifactRows) {
        _throwIfCancelled(token);

        final signedUrlRes = await _supabase.storage
            .from('artifacts')
            .createSignedUrl(artifact.storagePath, 60);

        final destFile = File(
          p.join(
            guidelineDir.path,
            '${artifact.id}_${p.basename(artifact.storagePath)}',
          ),
        );

        final bytesWritten = await _streamDownload(
          url: signedUrlRes,
          destFile: destFile,
          token: token,
          fileName: artifact.name,
          onChunk: (chunkLen) {
            cumulativeDownloaded += chunkLen;
            onProgress(
              DownloadProgress(
                bytesDownloaded: cumulativeDownloaded,
                totalBytes: runningTotalEstimate,
                currentFileName: artifact.name,
              ),
            );
          },
        );
        actualTotalOnDisk += bytesWritten;

        await (_db.update(_db.artifacts)
              ..where((a) => a.id.equals(artifact.id)))
            .write(ArtifactsCompanion(localFilePath: Value(destFile.path)));
      }

      // -- full source PDF (mandatory, bundled) --
      if (versionRow.sourcePdfUrl != null) {
        _throwIfCancelled(token);

        final pdfDestFile = File(p.join(guidelineDir.path, 'source.pdf'));
        final bytesWritten = await _streamDownload(
          url: versionRow.sourcePdfUrl!,
          destFile: pdfDestFile,
          token: token,
          fileName: 'Full Guideline PDF',
          onTotalKnown: (pdfTotal) {
            runningTotalEstimate = knownArtifactBytes + pdfTotal;
          },
          onChunk: (chunkLen) {
            cumulativeDownloaded += chunkLen;
            onProgress(
              DownloadProgress(
                bytesDownloaded: cumulativeDownloaded,
                totalBytes: runningTotalEstimate,
                currentFileName: 'Full Guideline PDF',
              ),
            );
          },
        );
        actualTotalOnDisk += bytesWritten;

        await (_db.update(
          _db.guidelineVersions,
        )..where((v) => v.id.equals(versionRow.id))).write(
          GuidelineVersionsCompanion(localPdfPath: Value(pdfDestFile.path)),
        );
      }

      // -- mark the guideline as downloaded --
      await (_db.update(
        _db.guidelines,
      )..where((g) => g.id.equals(guidelineId))).write(
        GuidelinesCompanion(
          isDownloaded: const Value(true),
          downloadedAt: Value(DateTime.now()),
          localSizeBytes: Value(actualTotalOnDisk),
        ),
      );
    } on DownloadCancelledException {
      // Clean up partial files on cancel so we don't leave orphaned
      // half-downloaded artifacts claiming to be "available offline."
      await _deleteGuidelineFiles(guidelineId);
      rethrow;
    } finally {
      _activeTokens.remove(guidelineId);
    }
  }

  void cancelDownload(String guidelineId) {
    _activeTokens[guidelineId]?.cancel();
  }

  Future<String> downloadArtifact(
    String guidelineId,
    Artifact artifact, {
    required void Function(DownloadProgress) onProgress,
  }) async {
    final token = _CancelToken();
    _activeTokens[artifact.id] = token;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final guidelineDir = Directory(
        p.join(docsDir.path, 'downloads', guidelineId),
      );
      await guidelineDir.create(recursive: true);

      final signedUrlRes = await _supabase.storage
          .from('artifacts')
          .createSignedUrl(artifact.storagePath, 60);

      final destFile = File(
        p.join(
          guidelineDir.path,
          '${artifact.id}_${p.basename(artifact.storagePath)}',
        ),
      );

      int cumulativeDownloaded = 0;
      await _streamDownload(
        url: signedUrlRes,
        destFile: destFile,
        token: token,
        fileName: artifact.name,
        onTotalKnown: (total) {
          onProgress(
            DownloadProgress(
              bytesDownloaded: 0,
              totalBytes: total,
              currentFileName: artifact.name,
            ),
          );
        },
        onChunk: (chunkLen) {
          cumulativeDownloaded += chunkLen;
          onProgress(
            DownloadProgress(
              bytesDownloaded: cumulativeDownloaded,
              totalBytes: artifact.sizeBytes,
              currentFileName: artifact.name,
            ),
          );
        },
      );

      await (_db.update(_db.artifacts)..where((a) => a.id.equals(artifact.id)))
          .write(ArtifactsCompanion(localFilePath: Value(destFile.path)));

      return destFile.path;
    } on DownloadCancelledException {
      if (_activeTokens.containsKey(artifact.id)) {
        await _deleteGuidelineFiles(guidelineId);
      }
      rethrow;
    } finally {
      _activeTokens.remove(artifact.id);
    }
  }

  /// Removes a downloaded guideline's local files and clears the
  /// download flags, without touching its cached metadata (the
  /// guideline stays in the Library, just no longer marked offline).
  Future<void> removeDownload(String guidelineId) async {
    await _deleteGuidelineFiles(guidelineId);

    await (_db.update(
      _db.guidelines,
    )..where((g) => g.id.equals(guidelineId))).write(
      const GuidelinesCompanion(
        isDownloaded: Value(false),
        downloadedAt: Value(null),
        localSizeBytes: Value(null),
      ),
    );

    final versionRow = await (_db.select(
      _db.guidelineVersions,
    )..where((v) => v.guidelineId.equals(guidelineId))).getSingleOrNull();
    if (versionRow != null) {
      await (_db.update(_db.guidelineVersions)
            ..where((v) => v.id.equals(versionRow.id)))
          .write(const GuidelineVersionsCompanion(localPdfPath: Value(null)));
    }

    final artifactRows = await (_db.select(
      _db.artifacts,
    )..where((a) => a.guidelineId.equals(guidelineId))).get();
    for (final a in artifactRows) {
      await (_db.update(_db.artifacts)..where((row) => row.id.equals(a.id)))
          .write(const ArtifactsCompanion(localFilePath: Value(null)));
    }
  }

  Future<void> _deleteGuidelineFiles(String guidelineId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final guidelineDir = Directory(
      p.join(docsDir.path, 'downloads', guidelineId),
    );
    if (await guidelineDir.exists()) {
      await guidelineDir.delete(recursive: true);
    }
  }

  void _throwIfCancelled(_CancelToken token) {
    if (token.isCancelled) throw DownloadCancelledException();
  }

  /// Streams a URL to a local file, reporting each chunk as it arrives.
  /// Returns total bytes written. Throws DownloadCancelledException if
  /// the token is cancelled mid-stream.
  Future<int> _streamDownload({
    required String url,
    required File destFile,
    required _CancelToken token,
    required String fileName,
    void Function(int totalBytes)? onTotalKnown,
    required void Function(int chunkLength) onChunk,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download $fileName: HTTP ${response.statusCode}',
      );
    }

    if (response.contentLength != null) {
      onTotalKnown?.call(response.contentLength!);
    }

    final sink = destFile.openWrite();
    int written = 0;
    try {
      await for (final chunk in response.stream) {
        if (token.isCancelled) {
          throw DownloadCancelledException();
        }
        sink.add(chunk);
        written += chunk.length;
        onChunk(chunk.length);
      }
    } finally {
      await sink.close();
    }
    return written;
  }

  void dispose() {
    _httpClient.close();
  }
}

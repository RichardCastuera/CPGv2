import 'package:cpg_reader/core/downloads/download_manager.dart';
import 'package:cpg_reader/features/guideline_detail/pdf_preview_page.dart';
import 'package:cpg_reader/models/artifact.dart';
import 'package:cpg_reader/models/question.dart';
import 'package:cpg_reader/models/section.dart';
import 'package:cpg_reader/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GuidelineDetailPage extends ConsumerStatefulWidget {
  const GuidelineDetailPage({required this.guidelineId, super.key});

  final String guidelineId;

  @override
  ConsumerState<GuidelineDetailPage> createState() =>
      _GuidelineDetailPageState();
}

class _GuidelineDetailPageState extends ConsumerState<GuidelineDetailPage> {
  bool _isSyncing = false;
  bool _isDownloading = false;
  DownloadProgress? _downloadProgress;

  DownloadManager get _downloadManager => ref.read(downloadManagerProvider);

  Future<void> _syncDetails() async {
    setState(() => _isSyncing = true);
    try {
      await ref
          .read(guidelineRepositoryProvider)
          .syncGuidelineDetail(widget.guidelineId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guideline details synchronized.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _downloadResources() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = const DownloadProgress(
        bytesDownloaded: 0,
        totalBytes: -1,
        currentFileName: 'Preparing',
      );
    });

    try {
      await _downloadManager.downloadGuideline(
        widget.guidelineId,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download complete.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _downloadArtifact(Artifact artifact) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = DownloadProgress(
        bytesDownloaded: 0,
        totalBytes: artifact.sizeBytes,
        currentFileName: artifact.name,
      );
    });

    try {
      await _downloadManager.downloadArtifact(
        widget.guidelineId,
        artifact,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${artifact.name} downloaded.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guidelineAsync = ref.watch(guidelineProvider(widget.guidelineId));
    final versionAsync = ref.watch(currentVersionProvider(widget.guidelineId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guideline Details'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncDetails,
            tooltip: 'Sync details',
          ),
          IconButton(
            icon: _isDownloading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.download_for_offline),
            onPressed: _isDownloading ? null : _downloadResources,
            tooltip: 'Download artifacts and PDF',
          ),
        ],
      ),
      body: guidelineAsync.when(
        data: (guideline) {
          if (guideline == null) {
            return const Center(child: Text('Guideline not found locally.'));
          }
          return versionAsync.when(
            data: (version) {
              if (version == null) {
                return const Center(
                  child: Text('No published version available locally.'),
                );
              }
              return _buildDetailBody(context, widget.guidelineId, version.id);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Failed to load version: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Failed to load guideline: $error')),
      ),
    );
  }

  Widget _buildDetailBody(
    BuildContext context,
    String guidelineId,
    String versionId,
  ) {
    final sectionsAsync = ref.watch(sectionsStreamProvider(versionId));
    final artifactsAsync = ref.watch(artifactsStreamProvider(guidelineId));
    final referencesAsync = ref.watch(referencesStreamProvider(guidelineId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_downloadProgress != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: _downloadProgress!.fraction),
              const SizedBox(height: 8),
              Text(
                '${_downloadProgress!.currentFileName} · ${_downloadProgress!.bytesDownloaded} / ${_downloadProgress!.totalBytes > 0 ? _downloadProgress!.totalBytes : '...'} bytes',
              ),
              const SizedBox(height: 16),
            ],
          ),
        Text('Sections', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        sectionsAsync.when(
          data: (sections) {
            if (sections.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No sections are available for this version.'),
              );
            }
            return Column(
              children: sections
                  .map((section) => _SectionPanel(section: section))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Failed to load sections: $error'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Artifacts', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        artifactsAsync.when(
          data: (artifacts) {
            if (artifacts.isEmpty) {
              return const Text(
                'No artifacts are available for this guideline.',
              );
            }
            return Column(
              children: artifacts
                  .map(
                    (artifact) => ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(artifact.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(artifact.category.name),
                          Text(artifact.mimeType),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (artifact.localFilePath != null &&
                              artifact.mimeType == 'application/pdf')
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              tooltip: 'Preview PDF',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PdfPreviewPage(
                                      filePath: artifact.localFilePath!,
                                      title: artifact.name,
                                    ),
                                  ),
                                );
                              },
                            )
                          else if (artifact.localFilePath != null)
                            const Icon(Icons.check, color: Colors.green),
                          if (artifact.localFilePath == null)
                            IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: 'Download this artifact',
                              onPressed: _isDownloading
                                  ? null
                                  : () => _downloadArtifact(artifact),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Failed to load artifacts: $error'),
        ),
        const SizedBox(height: 24),
        Text('References', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        referencesAsync.when(
          data: (references) {
            if (references.isEmpty) {
              return const Text(
                'No references are available for this guideline.',
              );
            }
            return Column(
              children: references
                  .map(
                    (reference) => ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(reference.label),
                      subtitle: Text(reference.citation),
                      isThreeLine: reference.doiOrUrl != null,
                      trailing: reference.doiOrUrl != null
                          ? const Icon(Icons.open_in_new)
                          : null,
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Failed to load references: $error'),
        ),
      ],
    );
  }
}

class _SectionPanel extends ConsumerWidget {
  const _SectionPanel({required this.section});

  final Section section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsStreamProvider(section.id));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(section.title),
        subtitle: Text('Order ${section.sortOrder} · ${section.status.name}'),
        children: [
          questionsAsync.when(
            data: (questions) {
              if (questions.isEmpty) {
                return const ListTile(
                  title: Text('No questions available for this section.'),
                );
              }
              return Column(
                children: questions
                    .map((question) => _QuestionPanel(question: question))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load questions: $error'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPanel extends ConsumerWidget {
  const _QuestionPanel({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(
      recommendationsStreamProvider(question.id),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ExpansionTile(
          title: Text(question.title),
          subtitle: Text(
            'Order ${question.sortOrder} · ${question.status.name}',
          ),
          children: [
            if (question.clinicalQuestion != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Clinical question: ${question.clinicalQuestion}'),
              ),
            recommendationsAsync.when(
              data: (recommendations) {
                if (recommendations.isEmpty) {
                  return const ListTile(
                    title: Text('No recommendations available.'),
                  );
                }
                return Column(
                  children: recommendations
                      .map(
                        (recommendation) => ListTile(
                          title: Text(recommendation.title),
                          subtitle: Text(
                            '${recommendation.strength ?? 'No strength'} · ${recommendation.certaintyOfEvidence ?? 'No certainty'}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load recommendations: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                : const Icon(Icons.download),
            onPressed: _isSyncing ? null : _syncDetails,
            tooltip: 'Sync details',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            guidelineAsync.when(
              data: (guideline) {
                if (guideline == null) {
                  return const Text('Guideline not found locally.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guideline.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Type: ${guideline.guidelineType.name}'),
                    Text('Status: ${guideline.status.name}'),
                    if (guideline.societies.isNotEmpty)
                      Text('Societies: ${guideline.societies.join(', ')}'),
                    if (guideline.currentVersionId != null)
                      Text('Current version id: ${guideline.currentVersionId}'),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Failed to load guideline: $error'),
            ),
            const SizedBox(height: 24),
            Text(
              'Current published version',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            versionAsync.when(
              data: (version) {
                if (version == null) {
                  return const Text('No published version available locally.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version: ${version.versionNumber}'),
                    Text('Status: ${version.status.name}'),
                    if (version.effectiveDate != null)
                      Text('Effective: ${version.effectiveDate!.toLocal()}'),
                    if (version.sourcePdfUrl != null)
                      Text('PDF URL: ${version.sourcePdfUrl}'),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Failed to load version: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

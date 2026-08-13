import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/guideline_providers.dart';
import '../../widgets/empty_state.dart';

class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadedGuidelinesStreamProvider);
    final db = ref.watch(localDbProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          downloadsAsync.maybeWhen(
            data: (rows) => rows.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () async {
                      for (final r in rows) {
                        await db.removeDownload(r.guidelineId);
                      }
                    },
                    child: const Text('Remove all'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load downloads: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: EmptyState(
                title: 'Nothing downloaded yet',
                message:
                    'Download a guideline from the Library to read it fully offline.',
              ),
            );
          }

          final totalBytes = rows.fold<int>(0, (sum, r) => sum + r.sizeBytes);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${rows.length} guideline${rows.length == 1 ? '' : 's'} downloaded',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(_formatBytes(totalBytes),
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'v${r.versionNumber} · ${r.status.toUpperCase()} · ${_formatBytes(r.sizeBytes)}\nSynced ${DateFormat('MMM d, h:mm a').format(r.downloadedAt)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => db.removeDownload(r.guidelineId),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

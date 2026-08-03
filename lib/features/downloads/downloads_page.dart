import 'package:cpg_reader/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadedLibraryStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloaded Guidelines')),
      body: downloadsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No downloaded guidelines yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(
                  '${item.guidelineType.name} · ${item.status.name}',
                ),
                trailing: const Icon(Icons.download_done),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Failed to load downloads: $error')),
      ),
    );
  }
}

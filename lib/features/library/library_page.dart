import 'package:cpg_reader/features/guideline_detail/guideline_detail_page.dart';
import 'package:cpg_reader/models/guideline_library_item.dart';
import 'package:cpg_reader/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _isSyncing = false;

  Future<void> _syncLibrary() async {
    setState(() => _isSyncing = true);
    try {
      final count = await ref.read(guidelineRepositoryProvider).syncLibrary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $count guideline(s) from Supabase')),
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
    final libraryAsync = ref.watch(libraryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guideline Library'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncLibrary,
            tooltip: 'Sync library',
          ),
        ],
      ),
      body: libraryAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No guidelines found. Tap sync to download library data.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = items[index];
              return _GuidelineTile(
                item: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GuidelineDetailPage(guidelineId: item.id),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Library load failed: $error')),
      ),
    );
  }
}

class _GuidelineTile extends StatelessWidget {
  const _GuidelineTile({required this.item, required this.onTap});

  final GuidelineLibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(item.title),
      subtitle: Text('${item.guidelineType.name} · ${item.status.name}'),
      trailing: item.isDownloaded ? const Icon(Icons.download_done) : null,
    );
  }
}

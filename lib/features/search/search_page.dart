import 'package:cpg_reader/providers.dart';
import 'package:cpg_reader/features/guideline_detail/guideline_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryStreamProvider);
    final filteredItems = libraryAsync.maybeWhen(
      data: (items) {
        if (_query.isEmpty) return items;
        return items.where((item) {
          final lowerQuery = _query.toLowerCase();
          return item.title.toLowerCase().contains(lowerQuery) ||
              item.guidelineType.name.toLowerCase().contains(lowerQuery) ||
              item.status.name.toLowerCase().contains(lowerQuery);
        }).toList();
      },
      orElse: () => const [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Search Guidelines')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by title, type, or status',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: libraryAsync.when(
              data: (items) {
                if (filteredItems.isEmpty) {
                  return const Center(child: Text('No results found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.guidelineType.name} · ${item.status.name}',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GuidelineDetailPage(guidelineId: item.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('Search failed: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

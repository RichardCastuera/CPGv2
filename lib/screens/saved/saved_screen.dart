import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/guideline_providers.dart';
import '../../services/local_db.dart';
import '../../widgets/empty_state.dart';
import '../guideline_detail/guideline_detail_screen.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(localDbProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: StreamBuilder<List<Bookmark>>(
        stream: db.watchBookmarks(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final filtered = _query.isEmpty
              ? all
              : all
                  .where((b) =>
                      b.title.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _Header(count: all.length, bookmarks: all)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search saved items…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    title:
                        all.isEmpty ? 'No bookmarks yet' : 'No matches found',
                    message: all.isEmpty
                        ? "Bookmark a guideline, question, or recommendation and it'll show up here for quick recall — even offline."
                        : 'No saved items match "$_query".',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BookmarkCard(bookmark: filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final int count;
  final List<Bookmark> bookmarks;
  const _Header({required this.count, required this.bookmarks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Saved',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('$count bookmark${count == 1 ? '' : 's'}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
          ),
          if (count > 0)
            TextButton.icon(
              onPressed: () => _confirmClearAll(context, ref),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE85D5D),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Clear all',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: Text(
            'This removes all $count saved item${count == 1 ? '' : 's'}. This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all',
                style: TextStyle(color: Color(0xFFE85D5D))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(bookmarkManagerProvider).clearAll(bookmarks);
    }
  }
}

class _BookmarkCard extends ConsumerWidget {
  final Bookmark bookmark;
  const _BookmarkCard({required this.bookmark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (badgeBg, badgeFg, label) = switch (bookmark.entityType) {
      'guideline' => (
          AppColors.badgeActiveBg,
          AppColors.badgeActiveFg,
          'GUIDELINE'
        ),
      'recommendation' => (
          AppColors.badgeRecommendationBg,
          AppColors.badgeRecommendationFg,
          'RECOMMENDATION'
        ),
      _ => (AppColors.badgeInterimBg, AppColors.badgeInterimFg, 'QUESTION'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(label,
                        style: TextStyle(
                            color: badgeFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ),
                ),
                Icon(Icons.bookmark_rounded,
                    size: 20, color: AppColors.primaryGreen),
              ],
            ),
            const SizedBox(height: 8),
            Text(bookmark.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                    'Saved ${DateFormat('yyyy-MM-dd').format(bookmark.createdAt)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GuidelineDetailScreen(
                          guidelineId: bookmark.guidelineId),
                    )),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Open', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85D5D),
                      side: const BorderSide(color: Color(0xFFE85D5D)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => ref.read(bookmarkManagerProvider).remove(
                        entityType: bookmark.entityType,
                        entityId: bookmark.entityId),
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label:
                        const Text('Remove', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

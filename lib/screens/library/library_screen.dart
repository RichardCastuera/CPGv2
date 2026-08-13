import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/guideline_list_item.dart';
import '../../providers/guideline_providers.dart';
import '../guideline_detail/guideline_detail_screen.dart';
import '../../widgets/empty_state.dart';
import 'widgets/guideline_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueReading = ref.watch(continueReadingProvider);
    final featured = ref.watch(featuredProvider);
    final filtered = ref.watch(filteredGuidelineListProvider);
    final bookmarked =
        ref.watch(bookmarkedIdsProvider).asData?.value ?? const <String>{};
    final showArchived = ref.watch(showArchivedProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(guidelineListProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _SectionTitle('Continue reading'),
                  const SizedBox(height: 10),
                  _ContinueReadingRow(
                      async: continueReading, bookmarked: bookmarked, ref: ref),
                  const SizedBox(height: 24),
                  _SectionTitle('Featured & recently updated'),
                  const SizedBox(height: 10),
                  _FeaturedList(
                      async: featured, bookmarked: bookmarked, ref: ref),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle('All guidelines'),
                      _ArchiveToggle(showArchived: showArchived, ref: ref),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _AllGuidelinesList(
                      async: filtered, bookmarked: bookmarked, ref: ref),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning!'
        : (hour < 18 ? 'Good afternoon!' : 'Good evening!');
    final dateLabel =
        DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(dateLabel,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 0.6)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Search guidelines, questions, recommendations…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
  }
}

class _ArchiveToggle extends StatelessWidget {
  final bool showArchived;
  final WidgetRef ref;
  const _ArchiveToggle({required this.showArchived, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Published'),
          selected: !showArchived,
          onSelected: (_) =>
              ref.read(showArchivedProvider.notifier).state = false,
          selectedColor: AppColors.primaryGreen,
          labelStyle: TextStyle(
            color: !showArchived ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.divider),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Archived'),
          selected: showArchived,
          onSelected: (_) =>
              ref.read(showArchivedProvider.notifier).state = true,
          selectedColor: AppColors.primaryGreen,
          labelStyle: TextStyle(
            color: showArchived ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.divider),
        ),
      ],
    );
  }
}

void _openDetail(BuildContext context, GuidelineListItem item) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GuidelineDetailScreen(guidelineId: item.guideline.id),
  ));
}

Future<void> _handleDownloadTap(WidgetRef ref, GuidelineListItem item) async {
  final manager = ref.read(downloadManagerProvider);
  await manager.download(item);
}

Future<void> _handleBookmarkTap(
    WidgetRef ref, GuidelineListItem item, bool isBookmarked) async {
  final manager = ref.read(bookmarkManagerProvider);
  if (isBookmarked) {
    await manager.remove(entityType: 'guideline', entityId: item.guideline.id);
  } else {
    await manager.add(
      entityType: 'guideline',
      entityId: item.guideline.id,
      guidelineId: item.guideline.id,
      title: item.guideline.title,
    );
  }
}

class _ContinueReadingRow extends StatelessWidget {
  final AsyncValue<List<GuidelineListItem>> async;
  final Set<String> bookmarked;
  final WidgetRef ref;
  const _ContinueReadingRow(
      {required this.async, required this.bookmarked, required this.ref});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('Could not load: $e'),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Nothing downloaded yet',
            message: "Downloaded guidelines you're reading will show up here.",
            size: 100,
          );
        }
        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => ContinueReadingCard(
              item: items[i],
              onOpen: () => _openDetail(context, items[i]),
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedList extends StatelessWidget {
  final AsyncValue<List<GuidelineListItem>> async;
  final Set<String> bookmarked;
  final WidgetRef ref;
  const _FeaturedList(
      {required this.async, required this.bookmarked, required this.ref});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load: $e'),
      data: (items) => Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GuidelineCard(
                    item: item,
                    isBookmarked: bookmarked.contains(item.guideline.id),
                    onOpen: () => _openDetail(context, item),
                    onDownloadTap: () => _handleDownloadTap(ref, item),
                    onBookmarkTap: () => _handleBookmarkTap(
                        ref, item, bookmarked.contains(item.guideline.id)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AllGuidelinesList extends StatelessWidget {
  final AsyncValue<List<GuidelineListItem>> async;
  final Set<String> bookmarked;
  final WidgetRef ref;
  const _AllGuidelinesList(
      {required this.async, required this.bookmarked, required this.ref});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load: $e'),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
                title: 'No guidelines found',
                message: 'Try a different search or filter.'),
          );
        }
        return Column(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GuidelineCard(
                      item: item,
                      isBookmarked: bookmarked.contains(item.guideline.id),
                      onOpen: () => _openDetail(context, item),
                      onDownloadTap: () => _handleDownloadTap(ref, item),
                      onBookmarkTap: () => _handleBookmarkTap(
                          ref, item, bookmarked.contains(item.guideline.id)),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

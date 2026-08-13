import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../models/guideline.dart';
import '../../models/guideline_content.dart';
import '../../providers/guideline_providers.dart';
import '../../widgets/empty_state.dart';

/// Local to this page, same reasoning as ArtifactsPage's provider — the
/// private one in guideline_detail_screen.dart isn't shared across files.
final _pageReferencesProvider =
    FutureProvider.family<List<GuidelineReference>, String>((ref, guidelineId) {
  return ref.watch(supabaseServiceProvider).fetchReferences(guidelineId);
});

class ReferencesPage extends ConsumerWidget {
  final Guideline guideline;
  const ReferencesPage({super.key, required this.guideline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referencesAsync = ref.watch(_pageReferencesProvider(guideline.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: referencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load references: $e')),
        data: (references) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  guideline: guideline,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: references.isEmpty
                    ? const SliverToBoxAdapter(
                        child: EmptyState(
                            title: 'No references',
                            message:
                                'No references listed for this guideline.'),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReferenceCard(
                                number: i + 1, reference: references[i]),
                          ),
                          childCount: references.length,
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

class _Header extends StatelessWidget {
  final Guideline guideline;
  final VoidCallback onBack;

  const _Header({required this.guideline, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('REFERENCES',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text(guideline.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.25)),
          const SizedBox(height: 6),
          const Text('Numbers match in-text citations',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final int number;
  final GuidelineReference reference;
  const _ReferenceCard({required this.number, required this.reference});

  @override
  Widget build(BuildContext context) {
    // DOIs/URLs are usually stored with a scheme; strip it for a cleaner,
    // shorter display the way the design shows ("doi.org/..." not
    // "https://doi.org/...") while still linking to the full URL.
    final displayUrl =
        reference.doiOrUrl?.replaceFirst(RegExp(r'^https?://'), '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.badgePublishedBg, shape: BoxShape.circle),
              child: Text('$number',
                  style: const TextStyle(
                      color: AppColors.badgePublishedFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reference.citation,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (displayUrl != null) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(reference.doiOrUrl!)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link_rounded,
                              size: 13, color: AppColors.statusDownload),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              displayUrl,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.statusDownload,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined,
                  size: 18, color: AppColors.textSecondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reference.citation));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Citation copied'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

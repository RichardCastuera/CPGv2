import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/artifact_style.dart';
import '../../theme/app_theme.dart';
import '../../models/guideline.dart';
import '../../models/guideline_content.dart';
import '../../providers/guideline_providers.dart';
import '../../widgets/empty_state.dart';

/// Local to this page — the private artifacts provider in
/// guideline_detail_screen.dart isn't accessible across files, and this
/// fetch is cheap enough not to warrant sharing one.
final _pageArtifactsProvider =
    FutureProvider.family<List<GuidelineArtifact>, String>((ref, guidelineId) {
  return ref.watch(supabaseServiceProvider).fetchArtifacts(guidelineId);
});

// Category styling now lives in core/artifact_style.dart (shared with the
// inline reader cards, so both places render categories identically).

class ArtifactsPage extends ConsumerStatefulWidget {
  final Guideline guideline;
  final GuidelineVersion version;
  const ArtifactsPage(
      {super.key, required this.guideline, required this.version});

  @override
  ConsumerState<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends ConsumerState<ArtifactsPage> {
  String? _activeFilter; // null = All

  @override
  Widget build(BuildContext context) {
    final artifactsAsync =
        ref.watch(_pageArtifactsProvider(widget.guideline.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: artifactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load artifacts: $e')),
        data: (artifacts) {
          final categories =
              artifacts.map((a) => a.category.toLowerCase()).toSet();
          // Fixed, sensible order when present; anything unrecognized falls
          // through and still gets its own chip via the loop below.
          const preferredOrder = [
            'figure',
            'table',
            'flowchart',
            'chart',
            'pdf',
            'document'
          ];
          final orderedCategories = [
            ...preferredOrder.where(categories.contains),
            ...categories.where((c) => !preferredOrder.contains(c)),
          ];

          final visible = _activeFilter == null
              ? artifacts
              : artifacts
                  .where((a) => a.category.toLowerCase() == _activeFilter)
                  .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  guideline: widget.guideline,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                            label: 'All',
                            selected: _activeFilter == null,
                            onTap: () => setState(() => _activeFilter = null)),
                        const SizedBox(width: 8),
                        ...orderedCategories.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: artifactStyleFor(c).label,
                                selected: _activeFilter == c,
                                onTap: () => setState(() => _activeFilter = c),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (widget.version.sourcePdfUrl != null) ...[
                      _PdfSummaryCard(url: widget.version.sourcePdfUrl!),
                      const SizedBox(height: 16),
                    ],
                    if (visible.isEmpty)
                      const EmptyState(
                          title: 'No attachments',
                          message: 'Nothing in this category yet.',
                          size: 120)
                    else
                      ...visible.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ArtifactCard(artifact: a),
                          )),
                  ]),
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
          const Text('ARTIFACTS',
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
          const Text('All figures, tables, flowcharts, charts and documents',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryGreen : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected ? null : Border.all(color: AppColors.divider),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              )),
        ),
      ),
    );
  }
}

class _PdfSummaryCard extends StatelessWidget {
  final String url;
  const _PdfSummaryCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.picture_as_pdf_outlined,
              color: AppColors.primaryGreen),
        ),
        title: const Text('Full Guideline PDF',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        onTap: () => launchUrl(Uri.parse(url)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textSecondary),
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  final GuidelineArtifact artifact;
  const _ArtifactCard({required this.artifact});

  @override
  Widget build(BuildContext context) {
    final style = artifactStyleFor(artifact.category);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 130,
                color: style.bg,
                alignment: Alignment.center,
                child: Icon(style.icon, color: style.fg, size: 44),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(style.label,
                      style: TextStyle(
                          color: style.fg,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artifact.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (artifact.caption != null) ...[
                  const SizedBox(height: 4),
                  Text(artifact.caption!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen),
                    // Deep-linking to the exact place this artifact is referenced
                    // in the content tree is on the roadmap (same underlying
                    // work as the chatbot source-chip deep-linking) — stubbed
                    // for now so the button is honest about not doing that yet.
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Jump-to-reference is coming soon.')),
                      );
                    },
                    icon: const Icon(Icons.open_in_full_rounded, size: 15),
                    label: const Text('Jump to where this appears',
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

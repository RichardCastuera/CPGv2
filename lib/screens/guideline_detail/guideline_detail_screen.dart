import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../core/tiptap.dart';
import '../../models/enums.dart';
import '../../models/guideline.dart';
import '../../models/guideline_content.dart';
import '../../models/guideline_list_item.dart';
import '../../providers/guideline_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/inline_artifact_card.dart';
import '../../widgets/tiptap_renderer.dart';
import 'artifacts_page.dart';
import 'references_page.dart';

final _guidelineProvider =
    FutureProvider.family<Guideline, String>((ref, id) async {
  final service = ref.watch(supabaseServiceProvider);
  final all = await service.fetchGuidelines();
  return all.firstWhere((g) => g.id == id);
});

final _versionHistoryProvider =
    FutureProvider.family<List<GuidelineVersion>, String>((ref, id) {
  return ref.watch(supabaseServiceProvider).fetchVersionHistory(id);
});

final selectedVersionIdProvider =
    StateProvider.family<String?, String>((ref, guidelineId) => null);

final _versionTreeProvider =
    FutureProvider.family<List<GuidelineSection>, String>((ref, versionId) {
  return ref.watch(supabaseServiceProvider).fetchVersionTree(versionId);
});

final _authorsProvider =
    FutureProvider.family<List<GuidelineAuthorRow>, String>((ref, guidelineId) {
  return ref.watch(supabaseServiceProvider).fetchAuthors(guidelineId);
});

final _artifactsProvider =
    FutureProvider.family<List<GuidelineArtifact>, String>((ref, guidelineId) {
  return ref.watch(supabaseServiceProvider).fetchArtifacts(guidelineId);
});

final _referencesProvider =
    FutureProvider.family<List<GuidelineReference>, String>((ref, guidelineId) {
  return ref.watch(supabaseServiceProvider).fetchReferences(guidelineId);
});

enum _DetailTab { contents, artifacts, references }

class GuidelineDetailScreen extends ConsumerStatefulWidget {
  final String guidelineId;
  const GuidelineDetailScreen({super.key, required this.guidelineId});

  @override
  ConsumerState<GuidelineDetailScreen> createState() =>
      _GuidelineDetailScreenState();
}

class _GuidelineDetailScreenState extends ConsumerState<GuidelineDetailScreen> {
  _DetailTab _tab = _DetailTab.contents;

  @override
  Widget build(BuildContext context) {
    final guidelineAsync = ref.watch(_guidelineProvider(widget.guidelineId));
    final historyAsync = ref.watch(_versionHistoryProvider(widget.guidelineId));
    final bookmarked = ref
            .watch(bookmarkedIdsProvider)
            .asData
            ?.value
            .contains(widget.guidelineId) ??
        false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: guidelineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load guideline: $e')),
        data: (guideline) {
          return historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load versions: $e')),
            data: (versions) {
              final selectedId =
                  ref.watch(selectedVersionIdProvider(widget.guidelineId)) ??
                      guideline.currentVersionId;
              final selectedVersion = versions.firstWhere(
                (v) => v.id == selectedId,
                orElse: () => versions.first,
              );

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      guideline: guideline,
                      version: selectedVersion,
                      isBookmarked: bookmarked,
                      onBack: () => Navigator.of(context).pop(),
                      onBookmarkToggle: () async {
                        final manager = ref.read(bookmarkManagerProvider);
                        if (bookmarked) {
                          await manager.remove(
                              entityType: 'guideline', entityId: guideline.id);
                        } else {
                          await manager.add(
                            entityType: 'guideline',
                            entityId: guideline.id,
                            guidelineId: guideline.id,
                            title: guideline.title,
                          );
                        }
                      },
                    ),
                  ),
                  if (selectedVersion.status == VersionStatus.archived)
                    SliverToBoxAdapter(
                      child: _ArchivedBanner(
                        onJumpToCurrent: guideline.currentVersionId == null
                            ? null
                            : () => ref
                                .read(selectedVersionIdProvider(
                                        widget.guidelineId)
                                    .notifier)
                                .state = guideline.currentVersionId,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DownloadCard(
                              guideline: guideline, version: selectedVersion),
                          const SizedBox(height: 10),
                          _PdfCard(version: selectedVersion),
                          const SizedBox(height: 20),
                          const Text('Version',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _VersionSelector(
                            versions: versions,
                            selected: selectedVersion,
                            onChanged: (id) => ref
                                .read(selectedVersionIdProvider(
                                        widget.guidelineId)
                                    .notifier)
                                .state = id,
                          ),
                          if (selectedVersion.changelog != null &&
                              selectedVersion.changelog!.trim().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _WhatsNewCard(version: selectedVersion),
                          ],
                          const SizedBox(height: 16),
                          _TabSelector(
                            tab: _tab,
                            onChanged: (t) {
                              if (t == _DetailTab.artifacts) {
                                // Artifacts has its own dedicated page (green
                                // header, category filters, jump-to actions)
                                // rather than switching inline like the other
                                // tabs — push it and leave _tab untouched.
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ArtifactsPage(
                                      guideline: guideline,
                                      version: selectedVersion),
                                ));
                              } else if (t == _DetailTab.references) {
                                // Same pattern as Artifacts — References is
                                // its own dedicated page too.
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      ReferencesPage(guideline: guideline),
                                ));
                              } else {
                                setState(() => _tab = t);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          switch (_tab) {
                            _DetailTab.contents => _ContentsTab(
                                guideline: guideline,
                                versionId: selectedVersion.id),
                            _DetailTab.artifacts =>
                              _ArtifactsTab(guidelineId: guideline.id),
                            _DetailTab.references =>
                              _ReferencesTab(guidelineId: guideline.id),
                          },
                          const SizedBox(height: 24),
                          _AuthorsSection(guidelineId: guideline.id),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Guideline guideline;
  final GuidelineVersion version;
  final bool isBookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmarkToggle;

  const _Header({
    required this.guideline,
    required this.version,
    required this.isBookmarked,
    required this.onBack,
    required this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = version.effectiveDate != null
        ? DateFormat('yyyy-MM-dd').format(version.effectiveDate!)
        : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              _CircleIconButton(
                icon: isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: onBookmarkToggle,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${guideline.guidelineType.label} · ${version.status.label}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            guideline.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.25),
          ),
          if (guideline.specialtyTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: guideline.specialtyTags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          if (guideline.societies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Published by ${guideline.societies.join(', ')}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.3),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _HeaderStat(
                      label: 'VERSION', value: 'v${version.versionNumber}')),
              Expanded(
                  child: _HeaderStat(label: 'EFFECTIVE', value: dateLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 10.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  final VoidCallback? onJumpToCurrent;
  const _ArchivedBanner({this.onJumpToCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.badgeArchivedBg,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppColors.badgeArchivedFg),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Archived — superseded by a newer version.',
                style: TextStyle(
                    color: AppColors.badgeArchivedFg, fontSize: 12.5)),
          ),
          if (onJumpToCurrent != null)
            TextButton(
                onPressed: onJumpToCurrent, child: const Text('View current')),
        ],
      ),
    );
  }
}

class _DownloadCard extends ConsumerWidget {
  final Guideline guideline;
  final GuidelineVersion version;
  const _DownloadCard({required this.guideline, required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadedGuidelinesStreamProvider);
    final downloads = downloadsAsync.asData?.value ?? const [];
    final matches = downloads.where((d) => d.guidelineId == guideline.id);
    final local = matches.isEmpty ? null : matches.first;
    final isCurrent = local != null && local.versionId == version.id;
    final sizeLabel = local != null
        ? '${(local.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final manager = ref.read(downloadManagerProvider);
          await manager.download(
              GuidelineListItem(guideline: guideline, version: version));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isCurrent ? Icons.check_rounded : Icons.download_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isCurrent ? 'Downloaded' : 'Download',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      isCurrent
                          ? '$sizeLabel · content · full PDF'
                          : 'Content + full PDF for offline reading',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfCard extends StatelessWidget {
  final GuidelineVersion version;
  const _PdfCard({required this.version});

  @override
  Widget build(BuildContext context) {
    final hasPdf = version.sourcePdfUrl != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Full Guideline PDF',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    hasPdf
                        ? 'Not yet available for offline reading'
                        : 'No PDF attached to this version',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: hasPdf
                  ? () => launchUrl(Uri.parse(version.sourcePdfUrl!))
                  : null,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionSelector extends StatelessWidget {
  final List<GuidelineVersion> versions;
  final GuidelineVersion selected;
  final ValueChanged<String> onChanged;

  const _VersionSelector(
      {required this.versions,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dateLabel = selected.effectiveDate != null
        ? DateFormat('yyyy-MM-dd').format(selected.effectiveDate!)
        : null;

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showVersionPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.history_rounded,
                    size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'v${selected.versionNumber} · ${selected.status.label}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (dateLabel != null)
                      Text('Effective $dateLabel',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more_rounded,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showVersionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Select version',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ...versions.map((v) {
              final isSelected = v.id == selected.id;
              final vDate = v.effectiveDate != null
                  ? DateFormat('yyyy-MM-dd').format(v.effectiveDate!)
                  : null;
              return ListTile(
                onTap: () {
                  onChanged(v.id);
                  Navigator.pop(sheetContext);
                },
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                ),
                title: Text('v${v.versionNumber} · ${v.status.label}',
                    style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500)),
                subtitle: vDate != null ? Text('Effective $vDate') : null,
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final _DetailTab tab;
  final ValueChanged<_DetailTab> onChanged;
  const _TabSelector({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _DetailTab.values.map((t) {
        final selected = t == tab;
        final label = switch (t) {
          _DetailTab.contents => 'Contents',
          _DetailTab.artifacts => 'Artifacts',
          _DetailTab.references => 'References',
        };
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: t != _DetailTab.values.last ? 8 : 0),
            child: Material(
              color:
                  selected ? AppColors.primaryGreen : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border:
                        selected ? null : Border.all(color: AppColors.divider),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ContentsTab extends ConsumerWidget {
  final Guideline guideline;
  final String versionId;
  const _ContentsTab({required this.guideline, required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(_versionTreeProvider(versionId));

    return treeAsync.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('Could not load content: $e'),
      data: (sections) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contents',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...sections.asMap().entries.map((e) => _SectionCard(
              index: e.key + 1,
              section: e.value,
              guideline: guideline,
              allSections: sections)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final int index;
  final GuidelineSection section;
  final Guideline guideline;
  final List<GuidelineSection> allSections;
  const _SectionCard({
    required this.index,
    required this.section,
    required this.guideline,
    required this.allSections,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${widget.index}. ${widget.section.title}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                if (widget.section.overview != null)
                  Text(tiptapToText(widget.section.overview),
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                if (widget.section.questions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...widget.section.questions.asMap().entries.map((qEntry) {
                    final questionIndex = qEntry.key + 1;
                    final question = qEntry.value;
                    final recNumbers = question.recommendations
                        .map((r) => r.number)
                        .whereType<String>()
                        .toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF6E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${widget.index}.$questionIndex ${question.title}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5)),
                          if (recNumbers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: recNumbers
                                  .map((n) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFCEBD5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('Rec $n',
                                            style: const TextStyle(
                                                color: AppColors.badgeInterimFg,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SectionReaderPage(
                        guideline: widget.guideline,
                        allSections: widget.allSections,
                        sectionIndex: widget.index - 1,
                      ),
                    )),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('Read section'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactsTab extends ConsumerWidget {
  final String guidelineId;
  const _ArtifactsTab({required this.guidelineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_artifactsProvider(guidelineId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load artifacts: $e'),
      data: (artifacts) {
        if (artifacts.isEmpty) {
          return const EmptyState(
            title: 'No attachments',
            message: 'No figures, tables, or attachments for this guideline.',
            size: 120,
          );
        }
        return Column(
          children: artifacts
              .map((a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.image_outlined,
                          color: AppColors.primaryGreen),
                      title: Text(a.name),
                      subtitle: a.caption != null ? Text(a.caption!) : null,
                      trailing: Text(
                          '${(a.sizeBytes / 1024).toStringAsFixed(0)} KB',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ReferencesTab extends ConsumerWidget {
  final String guidelineId;
  const _ReferencesTab({required this.guidelineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_referencesProvider(guidelineId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Could not load references: $e'),
      data: (refs) {
        if (refs.isEmpty) {
          return const EmptyState(
            title: 'No references',
            message: 'No references listed for this guideline.',
            size: 120,
          );
        }
        return Column(
          children: refs
              .map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Text(r.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      title: Text(r.citation,
                          style: const TextStyle(fontSize: 12.5)),
                      subtitle: r.doiOrUrl != null
                          ? Text(r.doiOrUrl!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.statusDownload))
                          : null,
                      onTap: r.doiOrUrl != null
                          ? () => launchUrl(Uri.parse(r.doiOrUrl!))
                          : null,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _WhatsNewCard extends StatelessWidget {
  final GuidelineVersion version;
  const _WhatsNewCard({required this.version});

  @override
  Widget build(BuildContext context) {
    // changelog is a plain-text column (not jsonb), so authors typically
    // write one change per line — split on newlines and drop any blanks.
    final lines = version.changelog!
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's new in v${version.versionNumber}",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(Icons.circle,
                                  size: 6, color: AppColors.statusDownload),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(line,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthorsSection extends ConsumerWidget {
  final String guidelineId;
  const _AuthorsSection({required this.guidelineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_authorsProvider(guidelineId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (authors) {
        if (authors.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Authors',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...authors.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.background,
                          child: Icon(Icons.person_outline_rounded,
                              size: 18, color: AppColors.primaryGreen)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                            if (a.affiliation != null)
                              Text(a.affiliation!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
}

/// Full reading view for a single section, pushed from "Read section".
/// Shows breadcrumb + progress against the guideline's full section list,
/// full rich-text rendering (via TiptapRenderer), per-question bookmarking,
/// and a fixed bottom bar for Next section / bookmark / share.
class SectionReaderPage extends ConsumerWidget {
  final Guideline guideline;
  final List<GuidelineSection> allSections;
  final int sectionIndex;

  const SectionReaderPage({
    super.key,
    required this.guideline,
    required this.allSections,
    required this.sectionIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = allSections[sectionIndex];
    final total = allSections.length;
    final isLast = sectionIndex >= total - 1;
    final artifactsAsync = ref.watch(_artifactsProvider(guideline.id));
    final artifacts =
        artifactsAsync.asData?.value ?? const <GuidelineArtifact>[];
    final sectionArtifacts =
        artifacts.where((a) => a.sectionId == section.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ReaderTopBar(
                guideline: guideline,
                section: section,
                sectionIndex: sectionIndex,
                total: total),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text('${sectionIndex + 1}. ${section.title}',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TiptapRenderer(document: section.overview, baseFontSize: 14),
                  for (final a in sectionArtifacts)
                    InlineArtifactCard(artifact: a),
                  const SizedBox(height: 4),
                  ...section.questions.map((q) => _QuestionCard(
                      guideline: guideline, question: q, artifacts: artifacts)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ReaderBottomBar(
        guideline: guideline,
        isLast: isLast,
        onNext: isLast
            ? null
            : () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => SectionReaderPage(
                    guideline: guideline,
                    allSections: allSections,
                    sectionIndex: sectionIndex + 1,
                  ),
                )),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  final Guideline guideline;
  final GuidelineSection section;
  final int sectionIndex;
  final int total;

  const _ReaderTopBar({
    required this.guideline,
    required this.section,
    required this.sectionIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  guideline.shortTitle ?? guideline.title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'Section ${sectionIndex + 1} of $total · ${sectionIndex + 1}. ${section.title}',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (sectionIndex + 1) / total,
              minHeight: 4,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends ConsumerStatefulWidget {
  final Guideline guideline;
  final GuidelineQuestion question;
  final List<GuidelineArtifact> artifacts;
  const _QuestionCard(
      {required this.guideline,
      required this.question,
      required this.artifacts});

  @override
  ConsumerState<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<_QuestionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final bookmarked = ref
            .watch(bookmarkedIdsProvider)
            .asData
            ?.value
            .contains(widget.question.id) ??
        false;

    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.question.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                      bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: bookmarked
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary),
                  onPressed: () async {
                    final manager = ref.read(bookmarkManagerProvider);
                    if (bookmarked) {
                      await manager.remove(
                          entityType: 'question', entityId: widget.question.id);
                    } else {
                      await manager.add(
                        entityType: 'question',
                        entityId: widget.question.id,
                        guidelineId: widget.guideline.id,
                        title: widget.question.title,
                      );
                    }
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textSecondary),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            if (_expanded) ...[
              if (widget.question.clinicalQuestion != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.question.clinicalQuestion!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              TiptapRenderer(
                  document: widget.question.background, baseFontSize: 13.5),
              for (final a in widget.artifacts
                  .where((a) => a.questionId == widget.question.id))
                InlineArtifactCard(artifact: a),
              ...widget.question.recommendations
                  .map((r) => _RecommendationCard(recommendation: r)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommendation.number != null)
                Text('${recommendation.number}  ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen)),
              Expanded(
                child: Text(recommendation.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (recommendation.strength != null)
                _MiniTag(recommendation.strength!),
              if (recommendation.certaintyOfEvidence != null)
                _MiniTag('Evidence: ${recommendation.certaintyOfEvidence}'),
            ],
          ),
          const SizedBox(height: 8),
          TiptapRenderer(document: recommendation.statement, baseFontSize: 13),
        ],
      ),
    );
  }
}

class _ReaderBottomBar extends ConsumerWidget {
  final Guideline guideline;
  final bool isLast;
  final VoidCallback? onNext;
  const _ReaderBottomBar(
      {required this.guideline, required this.isLast, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bookmarks this button, this bookmarks the guideline rather than the
    // section — `bookmarks.entity_type` only allows guideline/question/
    // recommendation server-side today. Extend that CHECK constraint to
    // include 'section' if per-section bookmarking is wanted specifically.
    final bookmarked =
        ref.watch(bookmarkedIdsProvider).asData?.value.contains(guideline.id) ??
            false;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isLast ? AppColors.divider : AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: onNext,
                icon: Icon(
                    isLast
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18),
                label: Text(isLast ? 'Last section' : 'Next section'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              icon: Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: bookmarked
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary),
              onPressed: () async {
                final manager = ref.read(bookmarkManagerProvider);
                if (bookmarked) {
                  await manager.remove(
                      entityType: 'guideline', entityId: guideline.id);
                } else {
                  await manager.add(
                    entityType: 'guideline',
                    entityId: guideline.id,
                    guidelineId: guideline.id,
                    title: guideline.title,
                  );
                }
              },
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              icon: const Icon(Icons.share_outlined,
                  color: AppColors.textSecondary),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing is coming soon.')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(label,
          style:
              const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../models/guideline_list_item.dart';
import '../../../widgets/status_badge.dart';

class GuidelineCard extends StatelessWidget {
  final GuidelineListItem item;
  final VoidCallback onOpen;
  final VoidCallback onDownloadTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;

  const GuidelineCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDownloadTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = item.guideline;
    final v = item.version;
    final dateLabel = v.effectiveDate != null
        ? DateFormat('yyyy-MM-dd').format(v.effectiveDate!)
        : '—';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuidelineBadgeRow(
                type: g.guidelineType,
                versionStatus: v.status,
                guidelineStatus: g.status,
              ),
              const SizedBox(height: 8),
              Text(
                g.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if ((g.shortTitle ?? g.specialtyTags.join(', ')).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  g.shortTitle ?? g.specialtyTags.join(', '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('v${v.versionNumber}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  const Icon(Icons.event_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text('Effective $dateLabel',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DownloadStatusIndicator(
                      state: item.downloadState, onTap: onDownloadTap),
                  if (onBookmarkTap != null)
                    InkWell(
                      onTap: onBookmarkTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                        color: isBookmarked
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal-scroll variant for the "Continue reading" row.
class ContinueReadingCard extends StatelessWidget {
  final GuidelineListItem item;
  final VoidCallback onOpen;

  const ContinueReadingCard(
      {super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final g = item.guideline;
    final v = item.version;

    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuidelineBadgeRow(
                  type: g.guidelineType,
                  versionStatus: v.status,
                  guidelineStatus: g.status,
                ),
                const SizedBox(height: 8),
                Text(
                  g.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

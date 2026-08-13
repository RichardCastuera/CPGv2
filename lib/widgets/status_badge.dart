import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/enums.dart';

class _BadgeColors {
  final Color bg;
  final Color fg;
  const _BadgeColors(this.bg, this.fg);
}

_BadgeColors _typeColors(GuidelineType type) {
  return switch (type) {
    GuidelineType.interim =>
      const _BadgeColors(AppColors.badgeInterimBg, AppColors.badgeInterimFg),
    GuidelineType.compendium => const _BadgeColors(
        AppColors.badgeCompendiumBg, AppColors.badgeCompendiumFg),
    GuidelineType.omnibus =>
      const _BadgeColors(AppColors.badgeOmnibusBg, AppColors.badgeOmnibusFg),
  };
}

_BadgeColors _statusColors(
    {required VersionStatus version, GuidelineStatus? guidelineStatus}) {
  if (guidelineStatus == GuidelineStatus.active &&
      version != VersionStatus.archived) {
    return const _BadgeColors(AppColors.badgeActiveBg, AppColors.badgeActiveFg);
  }
  return switch (version) {
    VersionStatus.published => const _BadgeColors(
        AppColors.badgePublishedBg, AppColors.badgePublishedFg),
    VersionStatus.archived =>
      const _BadgeColors(AppColors.badgeArchivedBg, AppColors.badgeArchivedFg),
    _ =>
      const _BadgeColors(AppColors.badgeArchivedBg, AppColors.badgeArchivedFg),
  };
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool outlined;

  const _Pill(
      {required this.label,
      required this.bg,
      required this.fg,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bg,
        border: outlined ? Border.all(color: fg.withValues(alpha: 0.6)) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// The pair of pills shown on every guideline card: type (INTERIM /
/// COMPENDIUM / OMNIBUS) and status (ACTIVE / PUBLISHED / ARCHIVED).
class GuidelineBadgeRow extends StatelessWidget {
  final GuidelineType type;
  final VersionStatus versionStatus;
  final GuidelineStatus? guidelineStatus;

  const GuidelineBadgeRow({
    super.key,
    required this.type,
    required this.versionStatus,
    this.guidelineStatus,
  });

  @override
  Widget build(BuildContext context) {
    final typeColors = _typeColors(type);
    final statusColors =
        _statusColors(version: versionStatus, guidelineStatus: guidelineStatus);
    final statusLabel = guidelineStatus == GuidelineStatus.active &&
            versionStatus != VersionStatus.archived
        ? 'ACTIVE'
        : versionStatus.label;

    return Wrap(
      spacing: 6,
      children: [
        _Pill(
            label: type.label,
            bg: typeColors.bg,
            fg: typeColors.fg,
            outlined: true),
        _Pill(label: statusLabel, bg: statusColors.bg, fg: statusColors.fg),
      ],
    );
  }
}

/// The bottom-of-card status row: Update Available / Available Offline / Download.
class DownloadStatusIndicator extends StatelessWidget {
  final DownloadState state;
  final VoidCallback? onTap;

  const DownloadStatusIndicator({super.key, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      DownloadState.updateAvailable => (
          Icons.refresh_rounded,
          'Update Available',
          AppColors.statusUpdateAvailable,
        ),
      DownloadState.downloaded => (
          Icons.check_circle_rounded,
          'Available Offline',
          AppColors.statusAvailableOffline,
        ),
      DownloadState.downloading => (
          Icons.downloading_rounded,
          'Downloading…',
          AppColors.statusDownload,
        ),
      DownloadState.notDownloaded => (
          Icons.download_rounded,
          'Download',
          AppColors.statusDownload,
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

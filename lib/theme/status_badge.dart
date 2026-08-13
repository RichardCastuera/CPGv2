import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Small pill badge for guideline status, type/society tags, and
/// download-related states. Built against the real AppColors tokens —
/// no new colors invented here.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  const StatusBadge.published({super.key, this.label = 'PUBLISHED'})
    : background = AppColors.primaryLight,
      foreground = AppColors.primary;

  const StatusBadge.archived({super.key, this.label = 'ARCHIVED'})
    : background = AppColors.ink100,
      foreground = AppColors.ink500;

  StatusBadge.updateAvailable({super.key, this.label = 'UPDATE AVAILABLE'})
    : background = AppColors.warning.withValues(alpha: 0.12),
      foreground = AppColors.warning;

  StatusBadge.inReview({super.key, this.label = 'IN REVIEW'})
    : background = AppColors.warning.withValues(alpha: 0.12),
      foreground = AppColors.warning;

  const StatusBadge.neutral({super.key, required this.label})
    : background = AppColors.ink100,
      foreground = AppColors.ink700;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

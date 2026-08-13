import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

/// Standard "nothing here" state — used anywhere a list/search/query comes
/// back empty (Library filters, Saved bookmarks, Downloads, Artifacts,
/// References). Keeps the empty-state treatment consistent across the app
/// instead of each screen inventing its own wording/layout.
class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final double size;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.size = 160,
    this.padding = const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animations/no_results.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

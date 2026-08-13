import 'package:flutter/material.dart';

/// Palette pulled directly from the Library screen design: deep forest green
/// header/accent, warm cream background, soft card shadows, and a small set
/// of badge colors for guideline type / status pills.
class AppColors {
  static const primaryGreen = Color(0xFF1F3D2B);
  static const primaryGreenLight = Color(0xFF2E5940);
  static const background = Color(0xFFF7F4EE);
  static const cardBackground = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1C1C1C);
  static const textSecondary = Color(0xFF6B6B6B);
  static const divider = Color(0xFFE7E2D8);

  // Badge / pill colors
  static const badgeInterimBg = Color(0xFFFCEBD5);
  static const badgeInterimFg = Color(0xFFB4661A);
  static const badgeCompendiumBg = Color(0xFFFCE3D0);
  static const badgeCompendiumFg = Color(0xFFC1521A);
  static const badgeOmnibusBg = Color(0xFFF9DDE3);
  static const badgeOmnibusFg = Color(0xFFB23A55);

  static const badgeActiveBg = Color(0xFFDCEBFB);
  static const badgeActiveFg = Color(0xFF215E9E);
  static const badgePublishedBg = Color(0xFFDCEEDE);
  static const badgePublishedFg = Color(0xFF1F7A3E);
  static const badgeArchivedBg = Color(0xFFE9E5DC);
  static const badgeArchivedFg = Color(0xFF7A7365);

  static const badgeRecommendationBg = Color(0xFFE6DEF7);
  static const badgeRecommendationFg = Color(0xFF6B46C1);

  static const statusUpdateAvailable = Color(0xFFC1521A);
  static const statusAvailableOffline = Color(0xFF1F7A3E);
  static const statusDownload = Color(0xFF215E9E);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryGreen,
        surface: AppColors.cardBackground,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primaryGreen.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primaryGreen : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryGreen : AppColors.textSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

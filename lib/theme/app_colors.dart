import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF0F6E5C); // deep teal — trust, clinical
  static const primaryLight = Color(0xFFE3F2EF);
  static const primaryDark = Color(0xFF0A4C40);

  // Neutrals (used far more than brand color — text, surfaces, borders)
  static const ink900 = Color(0xFF1A1D1E); // primary text
  static const ink700 = Color(0xFF4A4F52); // secondary text
  static const ink500 = Color(0xFF7C8286); // tertiary/hint text
  static const ink300 = Color(0xFFD3D6D8); // borders, dividers
  static const ink100 = Color(0xFFF3F4F5); // subtle surface/background
  static const white = Color(0xFFFFFFFF);

  // Semantic — recommendation strength
  static const strengthStrong = Color(0xFF1B7A4C);
  static const strengthConditional = Color(0xFFC77E10);

  // Semantic — certainty of evidence
  static const certaintyHigh = Color(0xFF0F6E5C);
  static const certaintyModerate = Color(0xFF4A7FBF);
  static const certaintyLow = Color(0xFF9C8B3D);
  static const certaintyVeryLow = Color(0xFF9A6B4F);

  // Artifact categories — mirrored from the web CMS for cross-app consistency
  static const artifactFigureBg = Color(0xFFD1FAE5);
  static const artifactFigureIcon = Color(0xFF047857);
  static const artifactTableBg = Color(0xFFFEF3C7);
  static const artifactTableIcon = Color(0xFFB45309);
  static const artifactFlowchartBg = Color(0xFFE0E7FF);
  static const artifactFlowchartIcon = Color(0xFF4338CA);
  static const artifactChartBg = Color(0xFFFFE4E6);
  static const artifactChartIcon = Color(0xFFBE123C);
  static const artifactPdfBg = Color(0xFFEDE9FE);
  static const artifactPdfIcon = Color(0xFF6D28D9);

  // Status (kept muted — end users mostly shouldn't see draft/needs-review)
  static const statusComplete = Color(0xFF1B7A4C);
  static const statusNeedsReview = Color(0xFFC77E10);

  // Feedback
  static const error = Color(0xFFB3261E);
  static const success = Color(0xFF1B7A4C);
  static const warning = Color(0xFFC77E10);
}

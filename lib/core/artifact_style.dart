import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class ArtifactStyle {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  const ArtifactStyle(this.bg, this.fg, this.icon, this.label);
}

ArtifactStyle artifactStyleFor(String category) {
  switch (category.toLowerCase()) {
    case 'figure':
      return const ArtifactStyle(Color(0xFFD9EFE6), Color(0xFF1F8A63), Icons.image_outlined, 'Figure');
    case 'table':
      return const ArtifactStyle(Color(0xFFFBEBD0), Color(0xFFB4661A), Icons.table_chart_outlined, 'Table');
    case 'flowchart':
      return const ArtifactStyle(Color(0xFFE1E4F7), Color(0xFF3D4FA0), Icons.account_tree_outlined, 'Flowchart');
    case 'chart':
      return const ArtifactStyle(Color(0xFFF7E1E4), Color(0xFFB23A55), Icons.bar_chart_rounded, 'Chart');
    case 'pdf':
    case 'document':
      return const ArtifactStyle(Color(0xFFEDE1F7), Color(0xFF6B46C1), Icons.picture_as_pdf_outlined, 'PDF');
    default:
      return const ArtifactStyle(AppColors.badgeArchivedBg, AppColors.badgeArchivedFg, Icons.attachment_outlined, 'Other');
  }
}

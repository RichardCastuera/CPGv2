import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/artifact_style.dart';
import '../theme/app_theme.dart';
import '../models/guideline_content.dart';
import '../providers/guideline_providers.dart';

/// Inline figure/flowchart/chart/table card embedded directly between
/// paragraphs in the section reader — compact badge + image + tap-to-zoom +
/// caption. Distinct from the cards on the dedicated Artifacts page (bigger,
/// meant for browsing); this one is sized to sit inline in reading flow.
///
/// Note: there's no offline caching for artifact images yet (only the text
/// content tree gets downloaded for offline reading today) — the "Offline"
/// indicator from the original design is intentionally left out until that's
/// built, rather than showing a badge that would lie about actual state.
class InlineArtifactCard extends ConsumerWidget {
  final GuidelineArtifact artifact;
  const InlineArtifactCard({super.key, required this.artifact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = artifactStyleFor(artifact.category);
    final url =
        ref.read(supabaseServiceProvider).artifactUrl(artifact.storagePath);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: style.bg, borderRadius: BorderRadius.circular(20)),
              child: Text(style.label,
                  style: TextStyle(
                      color: style.fg,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _ArtifactZoomView(url: url, title: artifact.name),
              fullscreenDialog: true,
            )),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (context, _) => Container(
                    height: 160,
                    color: AppColors.background,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, _, __) => Container(
                    height: 120,
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Tap to zoom',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4),
                children: [
                  TextSpan(
                    text: artifact.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  if (artifact.caption != null)
                    TextSpan(text: '. ${artifact.caption}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactZoomView extends StatelessWidget {
  final String url;
  final String title;
  const _ArtifactZoomView({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

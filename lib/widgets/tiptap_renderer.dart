import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../providers/settings_providers.dart';

/// Renders Tiptap-JSON rich text (as stored in `overview`, `background`,
/// `statement` jsonb columns) as real Flutter widgets — paragraphs, bold/
/// italic/underline/strike, superscript citation markers, links, and lists.
///
/// Built directly on TextSpan rather than routing through flutter_html, so
/// styling (colors, superscript treatment, spacing) stays fully under our
/// control and matches the app's own design system exactly.
///
/// This is the "online" rendering path. The offline path (`core/tiptap.dart`'s
/// `tiptapToText`) stays plain-text — it doubles as the on-device search
/// index and doesn't need formatting.
///
/// [baseFontSize] is further multiplied by the user's Settings > Reading
/// Preferences > Text size choice (`textScaleProvider`), so every reading
/// surface using this widget respects that setting automatically.
class TiptapRenderer extends ConsumerWidget {
  final Map<String, dynamic>? document;
  final double baseFontSize;
  final Color textColor;

  const TiptapRenderer({
    super.key,
    required this.document,
    this.baseFontSize = 14,
    this.textColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (document == null) return const SizedBox.shrink();
    final content = (document!['content'] as List<dynamic>?) ?? const [];
    if (content.isEmpty) return const SizedBox.shrink();

    final scale = ref.watch(textScaleProvider);
    final size = baseFontSize * scale;

    final blocks = <Widget>[];
    for (final node in content) {
      final widget = _buildBlock(Map<String, dynamic>.from(node as Map),
          depth: 0, size: size);
      if (widget != null) blocks.add(widget);
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget? _buildBlock(Map<String, dynamic> node,
      {required int depth, required double size}) {
    final type = node['type'] as String?;
    final content = (node['content'] as List<dynamic>?) ?? const [];

    switch (type) {
      case 'paragraph':
        if (content.isEmpty) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: _inlineSpans(content, size))),
        );

      case 'heading':
        final level = (node['attrs']?['level'] as int?)?.clamp(1, 6) ?? 1;
        final sizes = {1: size + 8, 2: size + 5, 3: size + 2};
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: sizes[level] ?? size + 1,
                  fontWeight: FontWeight.w800,
                  color: textColor),
              children: _inlineSpans(content, size),
            ),
          ),
        );

      case 'bulletList':
      case 'orderedList':
        final items = content.asMap().entries.map((e) {
          final marker = type == 'orderedList' ? '${e.key + 1}.' : '•';
          final itemContent =
              (Map<String, dynamic>.from(e.value as Map)['content']
                      as List<dynamic>?) ??
                  const [];
          return Padding(
            padding: EdgeInsets.only(left: 8.0 * (depth + 1), bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 18,
                    child: Text(marker,
                        style: TextStyle(fontSize: size, color: textColor))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: itemContent
                        .map((c) => _buildBlock(
                            Map<String, dynamic>.from(c as Map),
                            depth: depth + 1,
                            size: size))
                        .whereType<Widget>()
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList();
        return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(children: items));

      case 'listItem':
        // Reached only if a list item's content is processed directly
        // (shouldn't normally happen — bulletList/orderedList handle this).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content
              .map((c) => _buildBlock(Map<String, dynamic>.from(c as Map),
                  depth: depth, size: size))
              .whereType<Widget>()
              .toList(),
        );

      case 'blockquote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: AppColors.primaryGreen, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content
                .map((c) => _buildBlock(Map<String, dynamic>.from(c as Map),
                    depth: depth, size: size))
                .whereType<Widget>()
                .toList(),
          ),
        );

      case 'horizontalRule':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: AppColors.divider, height: 1),
        );

      default:
        // Unknown block type — fall back to any inline text it contains
        // rather than dropping the content silently.
        if (content.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: _inlineSpans(content, size))),
        );
    }
  }

  List<InlineSpan> _inlineSpans(List<dynamic> nodes, double size) {
    final spans = <InlineSpan>[];
    for (final n in nodes) {
      final node = Map<String, dynamic>.from(n as Map);
      if (node['type'] == 'hardBreak') {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      if (node['type'] != 'text') continue;

      final text = node['text'] as String? ?? '';
      final marks = (node['marks'] as List<dynamic>?) ?? const [];

      var fontWeight = FontWeight.normal;
      var fontStyle = FontStyle.normal;
      var decoration = TextDecoration.none;
      var fontSize = size;
      var baseline = TextBaseline.alphabetic;
      var offset = 0.0;
      var color = textColor;
      String? href;

      for (final m in marks) {
        final mark = Map<String, dynamic>.from(m as Map);
        switch (mark['type'] as String?) {
          case 'bold':
            fontWeight = FontWeight.w700;
          case 'italic':
            fontStyle = FontStyle.italic;
          case 'underline':
            decoration = TextDecoration.underline;
          case 'strike':
            decoration = TextDecoration.lineThrough;
          case 'superscript':
            fontSize = size * 0.7;
            offset = -size * 0.35;
            color = AppColors.statusUpdateAvailable;
            fontWeight = FontWeight.w700;
          case 'subscript':
            fontSize = size * 0.7;
            offset = size * 0.15;
          case 'link':
            href = (mark['attrs'] as Map?)?['href'] as String?;
            color = AppColors.statusDownload;
            decoration = TextDecoration.underline;
        }
      }

      final style = TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: decoration,
        color: color,
        height: 1.5,
      );

      if (offset != 0) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          baseline: baseline,
          child: Transform.translate(
              offset: Offset(0, offset), child: Text(text, style: style)),
        ));
      } else if (href != null) {
        spans.add(TextSpan(
          text: text,
          style: style,
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(href!)),
        ));
      } else {
        spans.add(TextSpan(text: text, style: style));
      }
    }
    return spans;
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a Tiptap/ProseMirror JSON document (as produced by the CMS's
/// RichTextEditor) as native Flutter widgets.
///
/// Supported block nodes: paragraph, heading, bulletList, orderedList,
/// listItem, blockquote, codeBlock, horizontalRule, table/tableRow/
/// tableHeader/tableCell, image.
/// Supported marks: bold, italic, underline, subscript, superscript, link.
class TiptapRenderer extends StatelessWidget {
  final Map<String, dynamic>? document;
  final TextStyle? baseStyle;

  const TiptapRenderer({super.key, required this.document, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    if (document == null) return const SizedBox.shrink();
    final content = (document!['content'] as List?) ?? const [];
    final style = baseStyle ?? Theme.of(context).textTheme.bodyLarge!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildBlocks(context, content, style),
    );
  }

  List<Widget> _buildBlocks(
    BuildContext context,
    List content,
    TextStyle style,
  ) {
    return content
        .map(
          (raw) => _buildBlockNode(context, raw as Map<String, dynamic>, style),
        )
        .toList();
  }

  Widget _buildBlockNode(
    BuildContext context,
    Map<String, dynamic> node,
    TextStyle style,
  ) {
    switch (node['type'] as String?) {
      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRichText(context, node, style),
        );

      case 'heading':
        final level = (node['attrs']?['level'] as int?) ?? 1;
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: _buildRichText(context, node, _headingStyle(context, level)),
        );

      case 'bulletList':
        return _buildList(context, node, style, ordered: false);

      case 'orderedList':
        return _buildList(context, node, style, ordered: true);

      case 'blockquote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildBlocks(
              context,
              (node['content'] as List?) ?? [],
              style.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        );

      case 'codeBlock':
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _extractPlainText(node),
            style: style.copyWith(fontFamily: 'monospace'),
          ),
        );

      case 'horizontalRule':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        );

      case 'image':
        final src = node['attrs']?['src'] as String?;
        if (src == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _TiptapImage(src: src, alt: node['attrs']?['alt'] as String?),
        );

      case 'table':
        return _buildTable(context, node, style);

      default:
        // Unknown node type — degrade gracefully rather than crash the
        // whole reader over one unexpected node from the CMS.
        final content = node['content'] as List?;
        return content != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildBlocks(context, content, style),
              )
            : const SizedBox.shrink();
    }
  }

  TextStyle _headingStyle(BuildContext context, int level) {
    final t = Theme.of(context).textTheme;
    switch (level) {
      case 1:
        return t.headlineMedium ??
            const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
      case 2:
        return t.headlineSmall ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
      case 3:
        return t.titleLarge ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
      default:
        return t.titleMedium ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    }
  }

  Widget _buildList(
    BuildContext context,
    Map<String, dynamic> node,
    TextStyle style, {
    required bool ordered,
  }) {
    final items = (node['content'] as List?) ?? [];
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(ordered ? '${i + 1}.' : '•', style: style),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildBlocks(
                    context,
                    (item['content'] as List?) ?? [],
                    style,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    Map<String, dynamic> node,
    TextStyle style,
  ) {
    final rows = (node['content'] as List?) ?? [];
    final tableRows = rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      final cells = (row['content'] as List?) ?? [];
      return TableRow(
        children: cells.map((rawCell) {
          final cell = rawCell as Map<String, dynamic>;
          final isHeader = cell['type'] == 'tableHeader';
          return Container(
            padding: const EdgeInsets.all(8),
            color: isHeader
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildBlocks(
                context,
                (cell['content'] as List?) ?? [],
                isHeader ? style.copyWith(fontWeight: FontWeight.bold) : style,
              ),
            ),
          );
        }).toList(),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: tableRows,
        ),
      ),
    );
  }

  Widget _buildRichText(
    BuildContext context,
    Map<String, dynamic> node,
    TextStyle style,
  ) {
    final content = (node['content'] as List?) ?? [];
    final spans = <InlineSpan>[];
    for (final raw in content) {
      spans.addAll(
        _buildInlineSpans(context, raw as Map<String, dynamic>, style),
      );
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }

  List<InlineSpan> _buildInlineSpans(
    BuildContext context,
    Map<String, dynamic> node,
    TextStyle baseStyle,
  ) {
    final type = node['type'] as String?;
    if (type == 'hardBreak') return const [TextSpan(text: '\n')];
    if (type != 'text') return const [];

    final text = node['text'] as String? ?? '';
    final marks = (node['marks'] as List?) ?? [];

    var style = baseStyle;
    String? linkUrl;
    double scriptOffset = 0;

    for (final raw in marks) {
      final mark = raw as Map<String, dynamic>;
      switch (mark['type']) {
        case 'bold':
          style = style.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'italic':
          style = style.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'underline':
          style = style.copyWith(decoration: TextDecoration.underline);
          break;
        case 'subscript':
          style = style.copyWith(fontSize: (style.fontSize ?? 14) * 0.7);
          scriptOffset = 4;
          break;
        case 'superscript':
          style = style.copyWith(fontSize: (style.fontSize ?? 14) * 0.7);
          scriptOffset = -4;
          break;
        case 'link':
          linkUrl = mark['attrs']?['href'] as String?;
          style = style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          );
          break;
      }
    }

    if (scriptOffset != 0) {
      return [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.translate(
            offset: Offset(0, scriptOffset),
            child: Text(text, style: style),
          ),
        ),
      ];
    }

    if (linkUrl != null) {
      final url = linkUrl;
      return [
        TextSpan(
          text: text,
          style: style,
          recognizer: TapGestureRecognizer()
            ..onTap = () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      ];
    }

    return [TextSpan(text: text, style: style)];
  }

  String _extractPlainText(Map<String, dynamic> node) {
    final buffer = StringBuffer();
    void walk(Map<String, dynamic> n) {
      if (n['type'] == 'text') buffer.write(n['text'] ?? '');
      final content = n['content'] as List?;
      if (content != null) {
        for (final c in content) walk(c as Map<String, dynamic>);
      }
    }

    walk(node);
    return buffer.toString();
  }
}

class _TiptapImage extends StatelessWidget {
  final String src;
  final String? alt;
  const _TiptapImage({required this.src, this.alt});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        src,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (context, error, stackTrace) => Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Row(
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alt ?? 'Image unavailable offline or failed to load',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flattens Tiptap-style rich text JSON (as stored in `overview`, `background`,
/// `statement` jsonb columns) into plain text — used for offline plain-text
/// rendering fallback and for building the local search index. Mirrors the
/// `tiptapToText` helper used in the `regenerate-embeddings` Edge Function so
/// online and offline search "see" the same content.
String tiptapToText(dynamic node) {
  if (node == null) return '';
  if (node is String) return node;
  if (node is! Map) return '';

  final map = Map<String, dynamic>.from(node);
  var text = '';
  if (map['text'] != null) text += map['text'] as String;

  final content = map['content'];
  if (content is List) {
    for (final child in content) {
      text += '${tiptapToText(child)} ';
    }
  }
  return text.trim();
}

import 'local_db.dart';

class OfflineSearchResult {
  final DownloadedContentData entry;
  final double score;
  const OfflineSearchResult(this.entry, this.score);
}

List<String> tokenize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toList();
}

/// Simple, no-embeddings keyword scoring — coverage of query tokens plus an
/// exact-phrase bonus, with a slight boost for recommendations/questions over
/// sections since they tend to be the more specific match. Runs entirely
/// on-device against whatever's already downloaded.
double _score(List<String> queryTokens, DownloadedContentData entry) {
  if (queryTokens.isEmpty) return 0;

  final entryTokens = tokenize('${entry.plainText} ${entry.title}').toSet();
  final matched = queryTokens.where(entryTokens.contains).length;
  final coverage = matched / queryTokens.length;

  final phrase = queryTokens.join(' ');
  final exactBonus = entry.plainText.toLowerCase().contains(phrase) ? 2.0 : 0.0;

  final typeBoost = switch (entry.entityType) {
    'recommendation' => 1.15,
    'question' => 1.05,
    _ => 1.0,
  };

  return (coverage + exactBonus) * typeBoost;
}

List<OfflineSearchResult> localSearch(
  String query,
  List<DownloadedContentData> index, {
  int topK = 5,
}) {
  final queryTokens = tokenize(query);
  final scored = index
      .map((e) => OfflineSearchResult(e, _score(queryTokens, e)))
      .where((r) => r.score > 0)
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return scored.take(topK).toList();
}

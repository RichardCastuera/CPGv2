import 'guideline.dart';
import 'enums.dart';

class GuidelineLibraryItem {
  final Guideline guideline;
  final bool isDownloaded;
  final DateTime? downloadedAt;
  final int? localSizeBytes;

  const GuidelineLibraryItem({
    required this.guideline,
    required this.isDownloaded,
    this.downloadedAt,
    this.localSizeBytes,
  });

  // Forwarding getters for convenient access in UI code
  String get id => guideline.id;
  String get title => guideline.title;
  GuidelineType get guidelineType => guideline.guidelineType;
  GuidelineStatus get status => guideline.status;
  List<String> get societies => guideline.societies;
}

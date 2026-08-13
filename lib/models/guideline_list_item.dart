import 'enums.dart';
import 'guideline.dart';
import 'guideline_content.dart';

/// A guideline paired with the version being displayed (usually current,
/// but could be an archived one the user is browsing) plus local download
/// state. This is the shape the Library screen cards actually bind to.
class GuidelineListItem {
  final Guideline guideline;
  final GuidelineVersion version;
  final DownloadState downloadState;
  final DateTime? lastSyncedAt;

  const GuidelineListItem({
    required this.guideline,
    required this.version,
    this.downloadState = DownloadState.notDownloaded,
    this.lastSyncedAt,
  });

  bool get isArchived => version.status == VersionStatus.archived;

  GuidelineListItem copyWith({
    DownloadState? downloadState,
    DateTime? lastSyncedAt,
  }) {
    return GuidelineListItem(
      guideline: guideline,
      version: version,
      downloadState: downloadState ?? this.downloadState,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

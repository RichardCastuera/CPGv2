/// Mirrors `guideline_type` USER-DEFINED enum in the CMS schema.
enum GuidelineType {
  interim,
  compendium,
  omnibus;

  static GuidelineType fromString(String value) {
    return GuidelineType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => GuidelineType.compendium,
    );
  }

  String get label => name.toUpperCase();
}

/// Mirrors `guideline_status` USER-DEFINED enum on `guidelines.status`.
enum GuidelineStatus {
  active,
  inactive;

  static GuidelineStatus fromString(String value) {
    return GuidelineStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => GuidelineStatus.active,
    );
  }

  String get label => name.toUpperCase();
}

/// Mirrors `version_status` USER-DEFINED enum on `guideline_versions.status`.
/// The mobile app only ever reads `published` and `archived` rows (RLS-enforced
/// server-side too), but we model all four so the type is honest.
enum VersionStatus {
  draft,
  review,
  published,
  archived;

  static VersionStatus fromString(String value) {
    return VersionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => VersionStatus.published,
    );
  }

  String get label => name.toUpperCase();

  bool get isVisibleToMobile => this == published || this == archived;
}

/// Local, on-device download state — not a DB column, purely client-side.
enum DownloadState {
  notDownloaded,
  downloading,
  downloaded,
  updateAvailable,
}

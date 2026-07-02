/// Parsed shape of the GitHub-hosted `version.json` that drives Scampi's
/// self-update system (the app isn't distributed through the Play Store,
/// so it can't rely on Play's built-in update mechanism).
///
/// Expected JSON shape:
/// ```json
/// {
///   "latest_version": "1.2.0",
///   "version_code": 12,
///   "apk_url": "https://github.com/USERNAME/scampi/releases/download/v1.2.0/scampi-v1.2.0.apk",
///   "release_notes": ["Added fasting improvements", "Improved food search"]
/// }
/// ```
class VersionInfo {
  const VersionInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final int versionCode;
  final String apkUrl;
  final List<String> releaseNotes;

  factory VersionInfo.fromJson(Map<String, Object?> json) {
    final rawNotes = json['release_notes'];
    return VersionInfo(
      latestVersion: (json['latest_version'] as String?)?.trim() ?? '0.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      apkUrl: (json['apk_url'] as String?)?.trim() ?? '',
      releaseNotes: rawNotes is List
          ? rawNotes.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

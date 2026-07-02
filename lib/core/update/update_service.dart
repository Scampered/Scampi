import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'version_info.dart';

const _lastCheckedPrefsKey = 'scampi_update_last_checked';

/// Where the update manifest lives. Update this to your actual GitHub
/// username/repo once Scampi has a release published — see the
/// version.json shape documented on [VersionInfo].
///
/// Points at `raw.githubusercontent.com` rather than the GitHub API so
/// checking for updates doesn't count against GitHub's (much lower)
/// unauthenticated API rate limit.
const String kVersionManifestUrl =
    'https://raw.githubusercontent.com/Scampered/Scampi/main/version.json';

class UpdateCheckException implements Exception {
  UpdateCheckException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UpdateDownloadException implements Exception {
  UpdateDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Result of comparing the installed app against the manifest.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.currentVersionCode,
    required this.remote,
    required this.updateAvailable,
  });

  final String currentVersion;
  final int currentVersionCode;
  final VersionInfo remote;
  final bool updateAvailable;
}

/// Self-update system for a sideloaded (non-Play-Store) APK: checks a
/// GitHub-hosted `version.json`, and if newer, downloads the APK and
/// hands it to the system package installer. Nothing here touches the
/// app's own SQLite database or SharedPreferences — a normal Android APK
/// upgrade-install (same package name, same signing key) preserves all
/// app data automatically, so "preserve local data" requires no special
/// handling as long as the update is installed as an upgrade rather than
/// an uninstall+reinstall.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> currentVersionName() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<DateTime?> lastChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastCheckedPrefsKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> _recordChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckedPrefsKey, DateTime.now().toIso8601String());
  }

  /// Fetches version.json and compares it against the installed version.
  /// Throws [UpdateCheckException] with a user-presentable message on any
  /// network failure, timeout, bad status code, or malformed JSON —
  /// callers should catch this specifically rather than letting a raw
  /// network exception surface, since "GitHub is down" and "no internet"
  /// are both expected, non-crashing outcomes here.
  Future<UpdateCheckResult> checkForUpdate() async {
    final currentVersion = await currentVersionName();
    final currentCode = await currentVersionCode();

    late final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(kVersionManifestUrl))
          .timeout(const Duration(seconds: 12));
    } on SocketException {
      throw UpdateCheckException('No internet connection.');
    } on HttpException {
      throw UpdateCheckException("Couldn't reach the update server.");
    } catch (_) {
      throw UpdateCheckException('Update check timed out — try again later.');
    }

    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'Update server returned an error (${response.statusCode}). Try again later.',
      );
    }

    late final VersionInfo remote;
    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      remote = VersionInfo.fromJson(decoded);
    } catch (_) {
      throw UpdateCheckException("Couldn't read the update manifest — it may be malformed.");
    }

    await _recordChecked();

    return UpdateCheckResult(
      currentVersion: currentVersion,
      currentVersionCode: currentCode,
      remote: remote,
      updateAvailable: isNewer(
        currentVersion: currentVersion,
        currentVersionCode: currentCode,
        remote: remote,
      ),
    );
  }

  /// True if [remote] is newer than the installed version. Compares
  /// semantic version strings numerically (so "1.10.0" > "1.9.0", unlike
  /// a naive string compare), falling back to versionCode if the version
  /// strings are equal or fail to parse — versionCode is the more
  /// reliable signal since it's a plain monotonic integer.
  static bool isNewer({
    required String currentVersion,
    required int currentVersionCode,
    required VersionInfo remote,
  }) {
    final cmp = compareSemver(remote.latestVersion, currentVersion);
    if (cmp != 0) return cmp > 0;
    return remote.versionCode > currentVersionCode;
  }

  /// Downloads the APK at [info.apkUrl] to app-private external storage
  /// (no storage permission needed on modern Android) and opens it with
  /// the system package installer. [onProgress] receives 0.0–1.0, or -1
  /// if the server didn't report a content length (so the caller can
  /// show an indeterminate spinner instead of a stuck progress bar).
  ///
  /// Throws [UpdateDownloadException] on network failure, a non-200
  /// response, or a size mismatch (truncated/corrupted download) — the
  /// partial file is deleted in that case rather than left behind.
  Future<void> downloadAndInstall(
    VersionInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    if (info.apkUrl.isEmpty) {
      throw UpdateDownloadException('No download URL in the update manifest.');
    }

    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final fileName = 'scampi-update-${info.latestVersion}.apk';
    final file = File('${dir.path}/$fileName');

    http.StreamedResponse response;
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      response = await _client.send(request).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw UpdateDownloadException('No internet connection.');
    } catch (_) {
      throw UpdateDownloadException('Failed to start the download — try again.');
    }

    if (response.statusCode != 200) {
      throw UpdateDownloadException('Download failed (HTTP ${response.statusCode}).');
    }

    final expectedBytes = response.contentLength;
    var receivedBytes = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (expectedBytes != null && expectedBytes > 0) {
          onProgress(receivedBytes / expectedBytes);
        } else {
          onProgress(-1);
        }
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw UpdateDownloadException('Download was interrupted — try again.');
    }

    if (expectedBytes != null && expectedBytes > 0 && receivedBytes != expectedBytes) {
      if (await file.exists()) await file.delete();
      throw UpdateDownloadException('Downloaded file looks corrupted — try again.');
    }

    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw UpdateDownloadException(
        "Downloaded the update but couldn't launch the installer: ${result.message}",
      );
    }
  }
}

/// Compares two dotted semantic-version-ish strings numerically,
/// segment by segment (so "1.10.0" > "1.9.0"). Non-numeric or missing
/// segments are treated as 0. Returns >0 if [a] > [b], <0 if [a] < [b],
/// 0 if equal.
int compareSemver(String a, String b) {
  final aParts = a.split('.');
  final bParts = b.split('.');
  final length = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < length; i++) {
    final aVal = i < aParts.length ? int.tryParse(aParts[i]) ?? 0 : 0;
    final bVal = i < bParts.length ? int.tryParse(bParts[i]) ?? 0 : 0;
    if (aVal != bVal) return aVal - bVal;
  }
  return 0;
}

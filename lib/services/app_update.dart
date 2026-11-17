import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'release_channel.dart';
import 'release_notes.dart';
import 'update_mirror.dart';

/// GitHub Releases based OTA updates.
///
/// Version scheme mirrors CI (scripts/prepare_app_version.py): the release
/// name is `MusicX 0.8.11(018)` and the app is built with
/// `--dart-define=APP_DISPLAY_VERSION=0.8.11(018)`. An update is available
/// when the release's (major, minor, patch, sequence) beats the local one.
///
/// Both the API call and the APK download go through [UpdateMirrorStore]: the
/// user-selected accelerator is tried first, then direct GitHub, then the rest
/// of the built-in routes.
class AppUpdateService {
  AppUpdateService._();

  /// 发布仓库：源码仓库转私有后由 CI 的 `--dart-define=RELEASE_REPO` 指向
  /// 公开的发布仓库，见 `release_channel.dart`。
  static const _repo = kReleaseRepo;
  static const _apiBase = kLatestReleaseApi;

  /// Downloaded APKs older than this are pruned on the next update.
  static const Duration cachedApkTtl = Duration(days: 7);

  /// Display version baked in at build time by CI; matches the release name.
  static String get currentVersion => const String.fromEnvironment(
      'APP_DISPLAY_VERSION',
      defaultValue: '0.7.8(001)');

  static final _versionRe = RegExp(r'(\d+)\.(\d+)\.(\d+)\((\d+)\)');

  static final _displayRe = RegExp(r'MusicX\s+(.+)');

  /// Parsed display version: (major, minor, patch, sequence).
  static (int, int, int, int)? parseVersion(String text) {
    final m = _versionRe.firstMatch(text);
    if (m == null) return null;
    return (
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
    );
  }

  static bool isNewer(String releaseVersionText) {
    final release = parseVersion(releaseVersionText);
    final current = parseVersion(currentVersion);
    if (release == null || current == null) return false;
    final r = <int>[release.$1, release.$2, release.$3, release.$4];
    final c = <int>[current.$1, current.$2, current.$3, current.$4];
    for (var i = 0; i < 4; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  /// Fetch the latest release.
  ///
  /// All routes race in parallel and the first valid answer wins: sequential
  /// probing would stall for a full timeout on the blocked direct route before
  /// ever reaching the accelerators. Worst case equals a single timeout.
  static Future<ReleaseInfo?> fetchLatest({http.Client? client}) async {
    final json = await _raceJson(_apiBase, client: client);
    if (json is! Map) return null;
    return ReleaseInfo.fromJson(json);
  }

  /// Release notes for [release], ready to render.
  ///
  /// The workflow writes a changelog into the release body; older releases were
  /// published with an empty body, so those fall back to the commits between
  /// this build tag and the previous one.
  static Future<ReleaseNotes> fetchNotes(
    ReleaseInfo release, {
    http.Client? client,
  }) async {
    final fromBody = ReleaseNotes.parse(release.body);
    if (!fromBody.isEmpty) return fromBody;

    final number = _buildNumber(release.tagName);
    if (number == null || number <= 1) return ReleaseNotes.empty;
    // A failed workflow run leaves no tag behind; walk back a few builds before
    // giving up so a single skipped release does not hide the whole changelog.
    for (var step = 1; step <= 4 && number - step >= 1; step++) {
      final previous = 'build-${number - step}';
      final json = await _raceJson(
        'https://api.github.com/repos/$_repo/compare/$previous...${release.tagName}',
        client: client,
        timeout: const Duration(seconds: 10),
      );
      if (json is! Map) continue;
      final commits = json['commits'];
      if (commits is! List || commits.isEmpty) continue;
      final subjects = <String>[];
      for (final entry in commits) {
        if (entry is! Map) continue;
        final commit = entry['commit'];
        final message = commit is Map ? commit['message'] as String? : null;
        if (message == null || message.trim().isEmpty) continue;
        subjects.add(message.trim().split('\n').first);
        if (subjects.length >= 40) break;
      }
      final notes = ReleaseNotes.fromCommits(subjects);
      if (!notes.isEmpty) return notes;
    }
    return ReleaseNotes.empty;
  }

  /// Race every mirror and return the first valid JSON answer.
  static Future<Object?> _raceJson(
    String apiUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final store = UpdateMirrorStore.instance;
    await store.ensureLoaded();
    final routes = store.probeOrder;
    if (routes.isEmpty) return null;

    final completer = Completer<Object?>();
    var pending = routes.length;

    void settle(Object? json) {
      if (json != null && !completer.isCompleted) completer.complete(json);
    }

    for (final mirror in routes) {
      final owned = client == null;
      final httpClient = client ?? http.Client();
      unawaited(() async {
        try {
          final resp = await httpClient.get(
            Uri.parse(mirror.resolve(apiUrl)),
            headers: const {'Accept': 'application/vnd.github+json'},
          ).timeout(timeout);
          if (resp.statusCode != 200) return;
          settle(jsonDecode(utf8.decode(resp.bodyBytes)));
        } catch (_) {
          // Route unavailable — another route may still win.
        } finally {
          if (owned) httpClient.close();
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }());
    }
    return completer.future;
  }

  static final RegExp _tagNumberRe = RegExp(r'build-(\d+)');

  static int? _buildNumber(String tagName) {
    final match = _tagNumberRe.firstMatch(tagName);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String? _pickApk(List assets) {
    for (final asset in assets) {
      if (asset is Map && (asset['name'] as String).endsWith('.apk')) {
        return asset['browser_download_url'] as String;
      }
    }
    return null;
  }

  static int? _pickApkSize(List assets) {
    for (final asset in assets) {
      if (asset is Map && (asset['name'] as String).endsWith('.apk')) {
        final size = asset['size'];
        if (size is int) return size;
        return int.tryParse(size?.toString() ?? '');
      }
    }
    return null;
  }

  /// Download the release APK through [mirror].
  ///
  /// Accelerated routes are validated by their file header — a proxy that
  /// answers with an HTML error page would otherwise leave a broken "APK" on
  /// disk. When an accelerator fails (network error or non-APK payload) and
  /// [fallbackToDirect] is true, direct GitHub is retried once.
  ///
  /// [expectedBytes] comes from the release asset metadata: proxies sometimes
  /// return a truncated (but still ZIP-headed) file, which installs as
  /// "解析软件包时出现问题". A size mismatch rejects the file and tries the
  /// next route.
  ///
  /// Every GitHub release publishes the same asset name (`app-release.apk`),
  /// so a name straight from the URL makes all versions indistinguishable on
  /// disk — users have re-installed a stale copy that way. [label] (version or
  /// build tag) is folded into the file name instead.
  static Future<File> downloadApk(
    String url, {
    UpdateMirror mirror = const UpdateMirror.direct(),
    bool fallbackToDirect = true,
    int? expectedBytes,
    String label = '',
    void Function(double progress, String route)? onProgress,
    required bool Function() cancelled,
  }) async {
    final attempts = <UpdateMirror>[
      mirror,
      if (fallbackToDirect && !mirror.isDirect) const UpdateMirror.direct(),
    ];
    Object? lastError;
    for (var index = 0; index < attempts.length; index++) {
      final current = attempts[index];
      try {
        return await _downloadOnce(
          url,
          current,
          expectedBytes: expectedBytes,
          label: label,
          onProgress: onProgress,
          cancelled: cancelled,
        );
      } catch (error) {
        if (error is UpdateCancelled) rethrow;
        if (cancelled()) throw const UpdateCancelled();
        lastError = error;
        if (index < attempts.length - 1) onProgress?.call(0, current.label);
      }
    }
    throw UpdateDownloadException(
      lastError == null ? '所有下载线路均失败' : '所有下载线路均失败：$lastError',
    );
  }

  static Future<File> _downloadOnce(
    String url,
    UpdateMirror mirror, {
    int? expectedBytes,
    String label = '',
    required void Function(double progress, String route)? onProgress,
    required bool Function() cancelled,
  }) async {
    final target = Uri.parse(mirror.resolve(url));
    final dir = await _updateCacheDirectory();
    final file = File('${dir.path}/${downloadFileName(target, label)}');
    if (file.existsSync()) file.deleteSync();
    // Drop packages left over from earlier versions: they are all called
    // `app-release.apk`, so a stale copy is easy to install by accident.
    await _purgeOtherApks(dir, keep: file);

    final client = http.Client();
    try {
      final request = http.Request('GET', target);
      final resp =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw UpdateDownloadException('${mirror.label} HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      var cancelRequested = false;
      var lastReport = -1;
      try {
        await for (final chunk in resp.stream) {
          if (cancelled()) {
            cancelRequested = true;
            break;
          }
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            final percent = (received / total * 100).floor();
            if (percent != lastReport) {
              lastReport = percent;
              onProgress?.call(received / total, mirror.label);
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (cancelRequested) {
        _deleteQuietly(file);
        throw const UpdateCancelled();
      }
      if (received <= 0) {
        _deleteQuietly(file);
        throw UpdateDownloadException('${mirror.label} 返回空内容');
      }
      if (total > 0 && received < total) {
        _deleteQuietly(file);
        throw UpdateDownloadException('${mirror.label} 下载不完整');
      }
      if (expectedBytes != null &&
          expectedBytes > 0 &&
          received != expectedBytes) {
        _deleteQuietly(file);
        throw UpdateDownloadException(
            '${mirror.label} 安装包大小不符（${received ~/ 1024}KB / '
            '${expectedBytes ~/ 1024}KB），已丢弃');
      }
      if (!await _looksLikeApk(file)) {
        _deleteQuietly(file);
        throw UpdateDownloadException('${mirror.label} 返回的不是安装包');
      }
      onProgress?.call(1, mirror.label);
      return file;
    } catch (error) {
      if (error is! UpdateCancelled) _deleteQuietly(file);
      rethrow;
    } finally {
      client.close();
    }
  }

  /// APK is a ZIP container: the header must be `PK\x03\x04` and the archive
  /// must end with an end-of-central-directory record. Broken accelerators
  /// answer with an HTML page, and truncated transfers keep the header but lose
  /// the trailer — both install as "解析软件包时出现问题".
  static Future<bool> _looksLikeApk(File file) async {
    try {
      final raf = await file.open();
      try {
        final header = await raf.read(4);
        if (header.length < 4 ||
            header[0] != 0x50 ||
            header[1] != 0x4B ||
            header[2] != 0x03 ||
            header[3] != 0x04) {
          return false;
        }
        final length = await raf.length();
        if (length < 22) return false;
        final tailStart = length > 66560 ? length - 66560 : 0;
        await raf.setPosition(tailStart);
        final tail = await raf.read(length - tailStart);
        return _indexOfSignature(tail) >= 0;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Offset of the ZIP end-of-central-directory signature (`PK\x05\x06`).
  static int _indexOfSignature(List<int> bytes) {
    for (var i = bytes.length - 22; i >= 0; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        return i;
      }
    }
    return -1;
  }

  /// Remove leftovers from previous updates so the temp dir does not grow.
  static Future<void> cleanupExpiredApkCache(
      {Duration maxAge = cachedApkTtl}) async {
    try {
      final dir = await _updateCacheDirectory();
      if (!dir.existsSync()) return;
      final now = DateTime.now();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.apk')) continue;
        final stat = await entity.stat();
        if (now.difference(stat.modified) > maxAge) {
          _deleteQuietly(entity);
        }
      }
    } catch (_) {}
  }

  /// Delete cached APKs other than [keep] so exactly one installable package
  /// exists at any time.
  static Future<void> _purgeOtherApks(Directory dir, {File? keep}) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.apk')) continue;
        if (keep != null && entity.path == keep.path) continue;
        _deleteQuietly(entity);
      }
    } catch (_) {}
  }

  static Future<Directory> _updateCacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/musix_app_updates');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// File name carries the build tag and the display version, e.g.
  /// `musix-build-70-0.8.12(002).apk`, because the release asset itself is
  /// always `app-release.apk`.
  @visibleForTesting
  static String downloadFileName(Uri target, String label) {
    final segments = target.pathSegments;
    var tag = '';
    if (segments.length >= 2) {
      final candidate = segments[segments.length - 2].trim();
      if (candidate.isNotEmpty && !candidate.contains('.')) tag = candidate;
    }
    final parts = <String>[
      'musix',
      if (tag.isNotEmpty) tag,
      if (label.trim().isNotEmpty) label.trim(),
    ];
    if (parts.length == 1) {
      return 'musix-update-${DateTime.now().millisecondsSinceEpoch}.apk';
    }
    return '${parts.map(_sanitizeFileName).join('-')}.apk';
  }

  static String _sanitizeFileName(String value) =>
      value.replaceAll(RegExp(r'[^\w.\-()+]+'), '_');

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReleaseInfo {
  final String tagName;
  final String displayName;
  final String body;
  final String? apkUrl;
  final int? apkSize;
  final DateTime? publishedAt;
  final String? pageUrl;
  const ReleaseInfo({
    required this.tagName,
    required this.displayName,
    required this.body,
    this.apkUrl,
    this.apkSize,
    this.publishedAt,
    this.pageUrl,
  });

  factory ReleaseInfo.fromJson(Map json) => ReleaseInfo(
        tagName: json['tag_name'] as String? ?? '',
        displayName:
            json['name'] as String? ?? json['tag_name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        apkUrl: AppUpdateService._pickApk(json['assets'] as List? ?? const []),
        apkSize:
            AppUpdateService._pickApkSize(json['assets'] as List? ?? const []),
        publishedAt:
            DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal(),
        pageUrl: json['html_url'] as String?,
      );

  /// "MusicX 0.8.11(018)" -> "0.8.11(018)".
  String get displayVersion =>
      AppUpdateService._displayRe.firstMatch(displayName)?.group(1) ??
      displayName;

  bool get hasApk => (apkUrl ?? '').isNotEmpty;
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';

import 'app_update.dart';
import 'update_mirror.dart';

enum UpdateDownloadPhase { idle, downloading, ready, failed }

/// 更新包后台下载：跨页面存活，关掉弹层也不会中断。
///
/// 之前下载逻辑写在弹层 State 里，关掉面板后进度就丢了，下载完也不会提示
/// 安装（State 已 dispose）。这里用单例 [ChangeNotifier] 持有整个下载过程，
/// 面板只负责触发，进度由外壳上的 [UpdateDownloadBanner] 展示：
///
/// - 下载完成且 App 在前台 → 直接拉起系统安装器；
/// - 在后台完成 → 回到前台后横幅提示「点击安装」；
/// - 失败 → 横幅给出失败原因，点击可重试。
class UpdateDownloadController extends ChangeNotifier
    with WidgetsBindingObserver {
  UpdateDownloadController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final UpdateDownloadController instance =
      UpdateDownloadController._();

  UpdateDownloadPhase _phase = UpdateDownloadPhase.idle;
  double _progress = 0;
  String _route = '';
  String _version = '';
  String? _error;
  File? _file;
  ReleaseInfo? _release;
  bool _cancelRequested = false;
  bool _foreground = true;
  bool _installing = false;

  UpdateDownloadPhase get phase => _phase;
  double get progress => _progress;
  String get route => _route;
  String get version => _version;
  String? get error => _error;
  File? get file => _file;
  bool get busy => _phase == UpdateDownloadPhase.downloading;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    final becameForeground = foreground && !_foreground;
    _foreground = foreground;
    // Downloaded while backgrounded: offer the installer as soon as the user
    // comes back, instead of popping a dialog they cannot see.
    if (becameForeground && _phase == UpdateDownloadPhase.ready) {
      _notifyChanged();
    }
  }

  /// 开始（或重复触发时忽略）下载 [release]。
  Future<void> start(ReleaseInfo release, {UpdateMirror? mirror}) async {
    final url = release.apkUrl;
    if (url == null || url.isEmpty) {
      _fail('该版本没有可用的安装包');
      return;
    }
    if (_phase == UpdateDownloadPhase.downloading &&
        _release?.tagName == release.tagName) {
      return;
    }
    _release = release;
    _version = release.displayVersion;
    _cancelRequested = false;
    _error = null;
    _file = null;
    _progress = 0;
    final chosen = mirror ?? UpdateMirrorStore.instance.selectedMirror;
    _route = chosen.label;
    _phase = UpdateDownloadPhase.downloading;
    _notifyChanged();

    try {
      final file = await AppUpdateService.downloadApk(
        url,
        mirror: chosen,
        expectedBytes: release.apkSize,
        onProgress: (progress, route) {
          _progress = progress;
          _route = route;
          _notifyChanged();
        },
        cancelled: () => _cancelRequested,
      );
      _file = file;
      _progress = 1;
      _phase = UpdateDownloadPhase.ready;
      _notifyChanged();
      if (_foreground) await install();
    } on UpdateCancelled {
      _phase = UpdateDownloadPhase.idle;
      _progress = 0;
      _notifyChanged();
    } on UpdateDownloadException catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('下载失败：$error');
    }
  }

  /// 重试上一次失败的下载。
  Future<void> retry() async {
    final release = _release;
    if (release == null) return;
    await start(release);
  }

  void cancel() {
    if (_phase != UpdateDownloadPhase.downloading) return;
    _cancelRequested = true;
  }

  /// 重新拉起系统安装器（横幅点击、或后台下载完成后回到前台）。
  Future<void> install() async {
    final target = _file;
    if (target == null || _installing) return;
    if (!target.existsSync()) {
      _fail('安装包已被清理，请重新下载');
      return;
    }
    _installing = true;
    try {
      final result = await OpenFilex.open(target.path,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        _error = '无法启动安装器：${result.message}';
        _notifyChanged();
      }
    } catch (error) {
      _error = '无法启动安装器：$error';
      _notifyChanged();
    } finally {
      _installing = false;
    }
  }

  /// 用户手动收起横幅（不清除已下载的文件）。
  void dismiss() {
    if (_phase == UpdateDownloadPhase.downloading) return;
    _phase = UpdateDownloadPhase.idle;
    _progress = 0;
    _error = null;
    _notifyChanged();
  }

  void _fail(String message) {
    _phase = UpdateDownloadPhase.failed;
    _error = message;
    _notifyChanged();
  }

  void _notifyChanged() {
    if (hasListeners) notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _phase = UpdateDownloadPhase.idle;
    _progress = 0;
    _route = '';
    _version = '';
    _error = null;
    _file = null;
    _release = null;
    _cancelRequested = false;
  }
}

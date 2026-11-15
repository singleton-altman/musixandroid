import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../services/app_update.dart';
import '../services/release_notes.dart';
import '../services/update_history.dart';
import '../services/update_mirror.dart';
import '../services/update_speed_tester.dart';
import '../stores/ui_store.dart';
import '../theme/theme.dart';
import 'glass_controls.dart' show showMusicGlassSheet;
import 'glass_surfaces.dart';

/// 检查更新入口：清理过期安装包后打开更新弹层。
Future<void> showUpdateSheet(BuildContext context) async {
  AppUpdateService.cleanupExpiredApkCache();
  await showMusicGlassSheet(context, const _UpdateSheet(),
      halfSize: 0.72, fullSize: 0.94);
}

/// 下载线路管理面板。
///
/// [sourceUrl] 是本次要下载的安装包地址，用于按真实链路测速；为空时退回
/// 仓库归档包，保证测的仍是同一条 GitHub 链路。
Future<void> showUpdateMirrorSheet(BuildContext context,
    {String sourceUrl = ''}) async {
  await showMusicGlassSheet(context, _UpdateMirrorSheet(sourceUrl: sourceUrl));
}

/// 更新日记：全部历史版本的分组更新内容（打包离线数据）。
Future<void> showUpdateHistorySheet(BuildContext context) async {
  await showMusicGlassSheet(context, const _UpdateHistorySheet(),
      halfSize: 0.72, fullSize: 0.94);
}

enum _UpdatePhase { checking, upToDate, available, downloading, failed }

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet();

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

/// Published date and package size of the release.
String _releaseMeta(ReleaseInfo release) {
  final parts = <String>[];
  final date = release.publishedAt;
  if (date != null) parts.add('${date.year}年${date.month}月${date.day}日');
  final size = release.apkSize;
  if (size != null && size > 0) {
    parts.add('${(size / (1024 * 1024)).toStringAsFixed(1)} MB');
  }
  return parts.join(' · ');
}

class _UpdateSheetState extends State<_UpdateSheet> {
  _UpdatePhase _phase = _UpdatePhase.checking;
  ReleaseInfo? _release;
  ReleaseNotes _notes = ReleaseNotes.empty;
  bool _notesLoading = false;
  String? _error;
  String? _route;
  double _progress = 0;
  bool _cancelled = false;

  UpdateMirrorStore get _mirrors => UpdateMirrorStore.instance;

  @override
  void initState() {
    super.initState();
    _mirrors.addListener(_onMirrorChanged);
    _mirrors.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _fetch();
  }

  @override
  void dispose() {
    _mirrors.removeListener(_onMirrorChanged);
    super.dispose();
  }

  void _onMirrorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetch() async {
    setState(() {
      _phase = _UpdatePhase.checking;
      _error = null;
      _route = null;
      _release = null;
      _notes = ReleaseNotes.empty;
      _notesLoading = false;
    });
    final info = await AppUpdateService.fetchLatest();
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _phase = _UpdatePhase.failed;
        _error = '无法连接 GitHub，可换一条下载线路后重试';
      });
      return;
    }
    final newer = AppUpdateService.isNewer(info.displayVersion);
    setState(() {
      _release = info;
      _phase = newer ? _UpdatePhase.available : _UpdatePhase.upToDate;
    });
    _loadNotes(info);
  }

  Future<void> _loadNotes(ReleaseInfo release) async {
    setState(() {
      _notesLoading = true;
      _notes = ReleaseNotes.empty;
    });
    final notes = await AppUpdateService.fetchNotes(release);
    if (!mounted || _release?.tagName != release.tagName) return;
    setState(() {
      _notes = notes;
      _notesLoading = false;
    });
  }

  Future<void> _openMirrors() async {
    await showUpdateMirrorSheet(context, sourceUrl: _release?.apkUrl ?? '');
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _download() async {
    final url = _release?.apkUrl;
    if (url == null) return;
    _cancelled = false;
    final mirror = _mirrors.selectedMirror;
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
      _route = mirror.label;
    });
    try {
      final file = await AppUpdateService.downloadApk(
        url,
        mirror: mirror,
        onProgress: (progress, route) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _route = route;
          });
        },
        cancelled: () => _cancelled,
      );
      if (!mounted) return;
      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (result.type != ResultType.done) {
        context.read<UIStore>().notify('无法启动安装器：${result.message}');
      } else {
        context.read<UIStore>().notify('已下载完成，请在系统弹窗中确认安装');
      }
    } on UpdateCancelled {
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.available);
    } on UpdateDownloadException catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.available;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.available;
        _error = '下载失败：$error';
      });
    }
  }

  /// Version header: "发现新版本 x" plus the current version underneath.
  Widget _versionHeader(ColorScheme scheme, {required bool newer}) {
    final release = _release;
    if (release == null) return const SizedBox.shrink();
    final meta = _releaseMeta(release);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                newer ? '发现新版本 ${release.displayVersion}' : '已是最新版本',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (!newer)
              Icon(Icons.check_circle_rounded,
                  color: const Color(0xFF34C759), size: 20),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            '当前版本 ${AppUpdateService.currentVersion}',
            if (meta.isNotEmpty) meta,
          ].join(' · '),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
      ],
    );
  }

  /// "更新内容" panel: heading rows with an accent bar, one row per change.
  Widget _notesSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_motion_rounded, size: 15, color: MX.ember),
            const SizedBox(width: 6),
            Text('更新内容',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            if (_notes.changeCount > 0) ...[
              const SizedBox(width: 6),
              Text('${_notes.changeCount} 项',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
            ],
            const Spacer(),
            if (_notesLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: MX.ember),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
          decoration: BoxDecoration(
            color: MX.fillSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MX.hairline, width: 0.6),
          ),
          child: _notesBody(scheme),
        ),
      ],
    );
  }

  Widget _notesBody(ColorScheme scheme) {
    if (_notes.isEmpty) {
      return Text(
        _notesLoading
            ? '正在获取更新内容…'
            : (_release?.body.trim().isEmpty ?? true)
                ? '该版本未附带更新说明'
                : '更新说明为空',
        style: TextStyle(
            color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.4),
      );
    }
    return ReleaseNoteBlocks(blocks: _notes.blocks);
  }

  Widget _mirrorRow(ColorScheme scheme) {
    final mirror = _mirrors.selectedMirror;
    return InkWell(
      onTap: _openMirrors,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(Icons.route_rounded, size: 17, color: MX.ember),
            const SizedBox(width: 8),
            Text('下载线路',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const Spacer(),
            Text(mirror.label,
                style: TextStyle(
                    color: MX.ember,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(ColorScheme scheme) {
    return InkWell(
      onTap: () => showUpdateHistorySheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 17, color: MX.ember),
            const SizedBox(width: 8),
            Text('更新日记',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Release notes can be long; the whole sheet scrolls so a bigger changelog
    // never clips the download button or overflows the glass panel.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('检查更新',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _mirrorRow(scheme),
          _historyRow(scheme),
          const SizedBox(height: 6),
          switch (_phase) {
            _UpdatePhase.checking => Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text('正在连接 GitHub Releases…',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
            _UpdatePhase.failed => Column(children: [
                Text(_error ?? '检查失败',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, fontSize: 14)),
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: _fetch, child: const Text('重试')),
              ]),
            _UpdatePhase.upToDate => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _versionHeader(scheme, newer: false),
                  if (_release != null) ...[
                    const SizedBox(height: 12),
                    _notesSection(scheme),
                  ],
                ],
              ),
            _UpdatePhase.available => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _versionHeader(scheme, newer: true),
                  const SizedBox(height: 12),
                  _notesSection(scheme),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: TextStyle(color: scheme.error, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                      onPressed: _download,
                      style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          minimumSize: const Size.fromHeight(46)),
                      child: Text('下载并安装',
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            _UpdatePhase.downloading => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: _progress <= 0 ? null : _progress,
                          minHeight: 6,
                          color: scheme.primary),
                    )),
                    const SizedBox(width: 12),
                    Text(
                        _progress > 0
                            ? '${(_progress * 100).floor()}%'
                            : '连接中',
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ]),
                  const SizedBox(height: 8),
                  if (_route != null)
                    Text('线路：$_route（失败自动回退直连）',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 11.5)),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                      onPressed: () => _cancelled = true,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                      child: const Text('取消下载')),
                ],
              ),
          },
        ],
      ),
    );
  }
}

// ===========================================================================
// 更新内容渲染：分组标题 + 圆点条目（检查更新与更新日记共用）
// ===========================================================================

class ReleaseNoteBlocks extends StatelessWidget {
  const ReleaseNoteBlocks({super.key, required this.blocks});

  final List<ReleaseNoteBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (final block in blocks) {
      switch (block.kind) {
        case ReleaseNoteKind.heading:
          if (children.isNotEmpty) children.add(const SizedBox(height: 9));
          children.add(Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                    color: MX.ember, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(block.text,
                    style: TextStyle(
                        color: MX.fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ));
          children.add(const SizedBox(height: 6));
        case ReleaseNoteKind.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6.5, right: 8, left: 3),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        color: MX.ember.withValues(alpha: 0.75),
                        shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(block.text,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.45)),
                ),
              ],
            ),
          ));
        case ReleaseNoteKind.text:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(block.text,
                style: TextStyle(
                    color: MX.dim, fontSize: 12, height: 1.45)),
          ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

// ===========================================================================
// 更新日记面板：全部历史版本的更新内容
// ===========================================================================

class _UpdateHistorySheet extends StatefulWidget {
  const _UpdateHistorySheet();

  @override
  State<_UpdateHistorySheet> createState() => _UpdateHistorySheetState();
}

class _UpdateHistorySheetState extends State<_UpdateHistorySheet> {
  List<UpdateHistoryEntry>? _entries;

  @override
  void initState() {
    super.initState();
    UpdateHistory.load().then((entries) {
      if (mounted) setState(() => _entries = entries);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _entries;
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('更新日记',
          style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700)),
    );

    if (entries == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
        children: [
          header,
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: MX.ember),
            ),
          ),
        ],
      );
    }

    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
        children: [
          header,
          const SizedBox(height: 24),
          Text('暂无更新记录',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ],
      );
    }

    // 文件内是旧 → 新，展示时 newest first。
    final ordered = entries.reversed.toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      itemCount: ordered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final entry = ordered[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: MX.fillSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MX.hairline, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(entry.title,
                        style: TextStyle(
                            color: MX.fg,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
                    if (entry.tag != entry.title) ...[
                      const SizedBox(width: 7),
                      Text(entry.tag,
                          style: TextStyle(
                              color: MX.dim, fontSize: 11)),
                    ],
                    const Spacer(),
                    Text(entry.date,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 8),
                if (entry.notes.isEmpty)
                  Text('本版未记录详细更新说明',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.4))
                else
                  ReleaseNoteBlocks(blocks: entry.notes.blocks),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// 下载线路面板：内置加速源 / 自定义源、测速与选择
// ===========================================================================

class _UpdateMirrorSheet extends StatefulWidget {
  const _UpdateMirrorSheet({required this.sourceUrl});

  final String sourceUrl;

  @override
  State<_UpdateMirrorSheet> createState() => _UpdateMirrorSheetState();
}

class _UpdateMirrorSheetState extends State<_UpdateMirrorSheet> {
  final UpdateMirrorStore _store = UpdateMirrorStore.instance;
  final MirrorSpeedController _speed = MirrorSpeedController();
  final TextEditingController _addController = TextEditingController();

  String? _addError;

  String get _probeUrl => widget.sourceUrl.trim().isEmpty
      ? UpdateSpeedTester.fallbackProbeUrl
      : widget.sourceUrl.trim();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _speed.addListener(_onSpeedChanged);
    _store.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _speed.removeListener(_onSpeedChanged);
    _speed.dispose();
    _addController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onSpeedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _select(UpdateMirror mirror) => _store.select(mirror.id);

  Future<void> _addCustom() async {
    final raw = _addController.text.trim();
    final error = UpdateMirror.validateTemplate(raw);
    if (error != null) {
      setState(() => _addError = error);
      return;
    }
    final normalized = UpdateMirror.normalizeTemplate(raw);
    if (normalized == null) {
      setState(() => _addError = '地址格式不正确');
      return;
    }
    final duplicated = _store.allMirrors.any(
      (mirror) => !mirror.isDirect && mirror.template.trim() == normalized,
    );
    if (duplicated) {
      setState(() => _addError = '该加速源已存在');
      return;
    }
    final added = await _store.addCustom(normalized);
    if (!mounted) return;
    if (added == null) {
      setState(() => _addError = '保存失败，请稍后重试');
      return;
    }
    _addController.clear();
    setState(() => _addError = null);
  }

  Future<void> _confirmDelete(UpdateMirror mirror) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => MusicGlassDialog(
        title: Text('删除加速源', style: TextStyle(color: MX.fg)),
        content: Text('确定删除「${mirror.label}」吗？',
            style: TextStyle(color: MX.dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: MX.dim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await _store.removeCustom(mirror.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mirrors = _store.allMirrors;
    final selectedId = _store.selectedId;
    final hint = _speed.fastestHint(mirrors, selectedId: selectedId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      children: [
        Row(children: [
          Expanded(
            child: Text('更新下载线路',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          _SpeedButton(
            busy: _speed.testingAll,
            onPressed: () => _speed.testAll(mirrors, sourceUrl: _probeUrl),
          ),
        ]),
        const SizedBox(height: 6),
        Text('国内访问 GitHub 较慢时可选加速源。当前线路失败会自动回退直连。',
            style: TextStyle(
                color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4)),
        if (hint != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.trending_up_rounded, size: 15, color: MX.ember),
            const SizedBox(width: 5),
            Expanded(
              child: Text(hint,
                  style: TextStyle(
                      color: MX.ember,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        for (final mirror in mirrors)
          _MirrorTile(
            mirror: mirror,
            selected: mirror.id == selectedId,
            testing: _speed.isTesting(mirror.id),
            result: _speed.resultFor(mirror.id),
            onTap: () => _select(mirror),
            onTest: () => _speed.testOne(mirror, sourceUrl: _probeUrl),
            onDelete:
                mirror.builtin || mirror.isDirect ? null : () => _confirmDelete(mirror),
          ),
        const SizedBox(height: 12),
        _buildAddCard(scheme),
      ],
    );
  }

  Widget _buildAddCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: MX.fillSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MX.hairline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自定义加速源',
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('支持前缀式（https://ghfast.top/）或占位符式（https://x/{url}）。',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: _addController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: MX.fg, fontSize: 14),
            cursorColor: MX.ember,
            onSubmitted: (_) => _addCustom(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'https://your-proxy.example/',
              hintStyle: TextStyle(color: MX.dimSoft, fontSize: 13),
              filled: true,
              fillColor: MX.fillStrong,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MX.hairline)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MX.hairline)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MX.ember)),
            ),
          ),
          if (_addError != null) ...[
            const SizedBox(height: 6),
            Text(_addError!,
                style: TextStyle(color: scheme.error, fontSize: 11.5)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _addCustom,
              style: FilledButton.styleFrom(
                  backgroundColor: MX.ember,
                  minimumSize: const Size.fromHeight(42)),
              child: Text('保存并使用',
                  style: TextStyle(
                      color: MX.onAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: MX.ember.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          SizedBox(
            width: 13,
            height: 13,
            child:
                CircularProgressIndicator(strokeWidth: 1.8, color: MX.ember),
          )
        else
          Icon(Icons.speed_rounded, size: 15, color: MX.ember),
        const SizedBox(width: 5),
        Text(busy ? '测速中' : '测速',
            style: TextStyle(
                color: MX.ember, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MirrorTile extends StatelessWidget {
  const _MirrorTile({
    required this.mirror,
    required this.selected,
    required this.testing,
    required this.result,
    required this.onTap,
    required this.onTest,
    this.onDelete,
  });

  final UpdateMirror mirror;
  final bool selected;
  final bool testing;
  final MirrorSpeedResult? result;
  final VoidCallback onTap;
  final VoidCallback onTest;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? MX.ember : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Row(
          children: [
            Icon(
              mirror.isDirect
                  ? Icons.link_rounded
                  : mirror.builtin
                      ? Icons.bolt_rounded
                      : Icons.tune_rounded,
              size: 19,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mirror.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? MX.ember : MX.fg,
                          fontSize: 14.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                  if (!mirror.isDirect)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(mirror.template,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SpeedBadge(testing: testing, result: result, onTap: onTest),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle_rounded,
                    size: 18, color: MX.ember),
              ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge(
      {required this.testing, required this.result, required this.onTap});

  final bool testing;
  final MirrorSpeedResult? result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (testing) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.8, color: MX.ember),
      );
    }
    final Color foreground;
    final String text;
    if (result == null) {
      foreground = scheme.onSurfaceVariant;
      text = '测速';
    } else if (result!.ok) {
      foreground = MX.ember;
      text = result!.displaySpeed;
    } else {
      foreground = scheme.error;
      text = result!.error ?? '失败';
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                color: foreground, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

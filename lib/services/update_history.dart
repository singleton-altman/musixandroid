import 'package:flutter/services.dart' show rootBundle;

import 'release_notes.dart';

/// 打包进 APK 的更新日记（assets/changelog.md）。
///
/// CI 构建时由 scripts/build_changelog.py 从全部 build 标签生成，因此安装包
/// 自带完整历史，无需联网、也不受 GitHub API 限流影响。内容按**基础版本**
/// 分组（一个 `0.8.12` 一节，聚合去重），节尾的「子版本」清单之后跟着每个
/// build 的明细小节：
///
/// ```
/// # 更新日记
///
/// ## 0.8.12 · 2026-11-16 ~ 2026-11-17
///
/// ### 新功能
/// - …
///
/// ### 子版本
/// - 0.8.12(002) · build-70 · 2026-11-17
/// - 0.8.12(001) · build-69 · 2026-11-16
///
/// ## build-70 · 0.8.12(002) · 2026-11-17
/// ### 新功能
/// - …
/// ```
///
/// 早期格式（一个 build 一节、无基础版本聚合）仍兼容解析。
class UpdateHistoryBuild {
  const UpdateHistoryBuild({
    required this.title,
    required this.tag,
    required this.date,
    required this.notes,
  });

  /// 展示版本号（如 `0.8.12(002)`）；早期版本可能退化为 `build-7`。
  final String title;

  /// 构建标签（如 `build-70`）。
  final String tag;

  /// 发布日期（yyyy-MM-dd）。
  final String date;

  final ReleaseNotes notes;
}

/// 一个基础版本的聚合条目（旧格式 = 单个版本）。
class UpdateHistoryGroup {
  const UpdateHistoryGroup({
    required this.title,
    required this.dateFrom,
    required this.dateTo,
    required this.notes,
    required this.builds,
  });

  /// 基础版本号（如 `0.8.12`）；旧格式为展示版本或标签名。
  final String title;

  /// 组内最早/最晚发布日期（yyyy-MM-dd）。
  final String dateFrom;
  final String dateTo;

  /// 聚合去重后的更新内容（旧格式即该版本自己的说明）。
  final ReleaseNotes notes;

  /// 组内子版本明细；旧格式为空。
  final List<UpdateHistoryBuild> builds;

  String get dateLabel => dateFrom == dateTo ? dateTo : '$dateFrom ~ $dateTo';
}

class UpdateHistory {
  UpdateHistory._();

  /// 大版本节：`## 0.8.12 · 2026-11-16 ~ 2026-11-17`。
  static final RegExp _baseHeaderRe = RegExp(
      r'^##\s*(\d+\.\d+\.\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*~\s*'
      r'(\d{4}-\d{2}-\d{2})\s*$');

  /// 子版本明细节：`## build-70 · 0.8.12(002) · 2026-11-17`。
  static final RegExp _buildHeaderRe = RegExp(
      r'^##\s*(build-\d+)\s*·\s*(.+?)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  /// 旧格式（单版本）：`## 0.8.11(024) · build-66 · 2026-11-15`。
  static final RegExp _legacyFullHeaderRe = RegExp(
      r'^##\s*(.+?)\s*·\s*(build-\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  /// 旧格式（无版本号）：`## build-7 · 2026-09-23`。
  static final RegExp _legacyTagHeaderRe =
      RegExp(r'^##\s*(build-\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  static const String _subVersionsMarker = '### 子版本';

  static final RegExp _subVersionLineRe = RegExp(
      r'^-\s*(.+?)\s*·\s*(build-\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  /// 解析日记全文；顺序保持文件原序（旧 → 新）。
  static List<UpdateHistoryGroup> parse(String raw) {
    final groups = <UpdateHistoryGroup>[];
    final byTag = <String, UpdateHistoryGroup>{};

    String? kind; // base / build / legacy
    String title = '';
    String tag = '';
    String dateFrom = '';
    String dateTo = '';
    final body = StringBuffer();

    void flush() {
      if (kind == null) return;
      final text = body.toString();
      switch (kind) {
        case 'base':
          final marker = text.indexOf(_subVersionsMarker);
          final notesPart = marker < 0 ? text : text.substring(0, marker);
          final group = UpdateHistoryGroup(
            title: title,
            dateFrom: dateFrom,
            dateTo: dateTo,
            notes: ReleaseNotes.parse(notesPart),
            builds: [],
          );
          groups.add(group);
          if (marker >= 0) {
            for (final line in text.substring(marker).split('\n')) {
              final ref = _subVersionLineRe.firstMatch(line.trim());
              if (ref == null) continue;
              final buildTag = ref.group(2)!;
              final build = UpdateHistoryBuild(
                title: ref.group(1)!,
                tag: buildTag,
                date: ref.group(3)!,
                notes: ReleaseNotes.empty,
              );
              group.builds.add(build);
              byTag[buildTag] = group;
            }
          }
        case 'build':
          final build = UpdateHistoryBuild(
            title: title,
            tag: tag,
            date: dateTo,
            notes: ReleaseNotes.parse(text),
          );
          final host = byTag[tag];
          if (host == null) {
            groups.add(UpdateHistoryGroup(
              title: build.title,
              dateFrom: build.date,
              dateTo: build.date,
              notes: build.notes,
              builds: [build],
            ));
          } else {
            final index = host.builds.indexWhere((b) => b.tag == tag);
            if (index >= 0) {
              host.builds[index] = build;
            } else {
              host.builds.add(build);
            }
          }
        case 'legacy':
          groups.add(UpdateHistoryGroup(
            title: title,
            dateFrom: dateTo,
            dateTo: dateTo,
            notes: ReleaseNotes.parse(text),
            builds: const [],
          ));
      }
      kind = null;
      title = '';
      tag = '';
      dateFrom = '';
      dateTo = '';
      body.clear();
    }

    for (final line in raw.split('\n')) {
      final base = _baseHeaderRe.firstMatch(line);
      if (base != null) {
        flush();
        kind = 'base';
        title = base.group(1)!;
        dateFrom = base.group(2)!;
        dateTo = base.group(3)!;
        continue;
      }
      final legacyTag = _legacyTagHeaderRe.firstMatch(line);
      if (legacyTag != null) {
        flush();
        kind = 'legacy';
        title = legacyTag.group(1)!;
        tag = legacyTag.group(1)!;
        dateTo = legacyTag.group(2)!;
        continue;
      }
      final build = _buildHeaderRe.firstMatch(line);
      if (build != null) {
        flush();
        kind = 'build';
        tag = build.group(1)!;
        title = build.group(2)!;
        dateTo = build.group(3)!;
        continue;
      }
      final legacyFull = _legacyFullHeaderRe.firstMatch(line);
      if (legacyFull != null) {
        flush();
        kind = 'legacy';
        title = legacyFull.group(1)!;
        tag = legacyFull.group(2)!;
        dateTo = legacyFull.group(3)!;
        continue;
      }
      if (kind != null) body.writeln(line);
    }
    flush();
    return groups;
  }

  /// 读取打包的日记；缺失或损坏时返回空列表（面板显示空态）。
  static Future<List<UpdateHistoryGroup>> load() async {
    try {
      return parse(await rootBundle.loadString('assets/changelog.md'));
    } catch (_) {
      return const [];
    }
  }
}

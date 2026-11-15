import 'package:flutter/services.dart' show rootBundle;

import 'release_notes.dart';

/// 打包进 APK 的更新日记（assets/changelog.md）。
///
/// CI 构建时由 scripts/build_changelog.py 从全部 build 标签生成，因此安装包
/// 自带完整历史，无需联网、也不受 GitHub API 限流影响。格式：
///
/// ```
/// # 更新日记
///
/// ## 0.8.11(024) · build-66 · 2026-11-15
///
/// ### 新功能
/// - …
/// ```
class UpdateHistoryEntry {
  const UpdateHistoryEntry({
    required this.title,
    required this.tag,
    required this.date,
    required this.notes,
  });

  /// 展示版本号（如 `0.8.11(024)`）；早期版本可能退化为 `build-7`。
  final String title;

  /// 构建标签（如 `build-66`）。
  final String tag;

  /// 发布日期（yyyy-MM-dd）。
  final String date;

  final ReleaseNotes notes;

  bool get isNewer =>
      int.tryParse(tag.substring('build-'.length)) != null;
}

class UpdateHistory {
  UpdateHistory._();

  /// 版本行带展示版本号：`## 0.8.11(024) · build-66 · 2026-11-15`。
  static final RegExp _fullHeaderRe = RegExp(
      r'^##\s*(.+?)\s*·\s*(build-\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  /// 早期版本只有标签：`## build-7 · 2026-09-23`。
  static final RegExp _tagHeaderRe =
      RegExp(r'^##\s*(build-\d+)\s*·\s*(\d{4}-\d{2}-\d{2})\s*$');

  /// 解析日记全文；顺序保持文件原序（旧 → 新）。
  static List<UpdateHistoryEntry> parse(String raw) {
    final entries = <UpdateHistoryEntry>[];
    String? title;
    String? tag;
    String? date;
    final body = StringBuffer();

    void flush() {
      if (tag == null || date == null) return;
      entries.add(UpdateHistoryEntry(
        title: (title == null || title == tag) ? tag! : title!,
        tag: tag!,
        date: date!,
        notes: ReleaseNotes.parse(body.toString()),
      ));
      title = null;
      tag = null;
      date = null;
      body.clear();
    }

    for (final line in raw.split('\n')) {
      final full = _fullHeaderRe.firstMatch(line);
      if (full != null) {
        flush();
        title = full.group(1)!.trim();
        tag = full.group(2)!;
        date = full.group(3)!;
        continue;
      }
      final simple = _tagHeaderRe.firstMatch(line);
      if (simple != null) {
        flush();
        tag = simple.group(1)!;
        date = simple.group(2)!;
        continue;
      }
      if (tag != null) body.writeln(line);
    }
    flush();
    return entries;
  }

  /// 读取打包的日记；缺失或损坏时返回空列表（面板显示空态）。
  static Future<List<UpdateHistoryEntry>> load() async {
    try {
      return parse(await rootBundle.loadString('assets/changelog.md'));
    } catch (_) {
      return const [];
    }
  }
}

import 'package:flutter/services.dart' show rootBundle;

import 'release_notes.dart';

/// 一个基础版本的更新日记条目（如 `0.8.12`）。
///
/// CI 构建时由 scripts/build_changelog.py 生成 `assets/changelog.md`：**一个大
/// 版本一节**，条目是该大版本下所有构建合并去重后的主要内容，不再列子版本。
/// 文件格式：
///
/// ```
/// # 更新日记
///
/// ## 0.8.12 · 2026-11-16
///
/// ### 新功能
/// - …
/// ```
class UpdateHistoryGroup {
  const UpdateHistoryGroup({
    required this.title,
    required this.dateFrom,
    required this.dateTo,
    required this.notes,
  });

  /// 大版本号（如 `0.8.12`）；早期无版本号的条目退化为标签名。
  final String title;

  /// 该大版本最早/最晚发布日期（yyyy-MM-dd）。
  final String dateFrom;
  final String dateTo;

  /// 合并去重后的更新内容。
  final ReleaseNotes notes;

  String get dateLabel => dateFrom == dateTo ? dateTo : '$dateFrom ~ $dateTo';
}

class UpdateHistory {
  UpdateHistory._();

  /// `## 0.8.12 · 2026-11-16` 或 `## 0.8.12 · 2026-11-16 ~ 2026-11-17`。
  static final RegExp _headerRe = RegExp(
      r'^##\s*(.+?)\s*·\s*(\d{4}-\d{2}-\d{2})(?:\s*~\s*(\d{4}-\d{2}-\d{2}))?\s*$');

  /// 解析日记全文；顺序保持文件原序（旧 → 新）。
  static List<UpdateHistoryGroup> parse(String raw) {
    final groups = <UpdateHistoryGroup>[];

    String? title;
    String dateFrom = '';
    String dateTo = '';
    bool skipped = false;
    final body = StringBuffer();

    void flush() {
      if (title == null) return;
      groups.add(UpdateHistoryGroup(
        title: title!,
        dateFrom: dateFrom,
        dateTo: dateTo,
        notes: ReleaseNotes.parse(body.toString()),
      ));
      title = null;
      dateFrom = '';
      dateTo = '';
      body.clear();
    }

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final header = _headerRe.firstMatch(trimmed);
      if (header != null) {
        flush();
        final name = header.group(1)!;
        // 旧格式的每个 build 明细节不再需要，整节跳过。
        if (name.startsWith('build-')) {
          skipped = true;
          continue;
        }
        skipped = false;
        title = name;
        dateFrom = header.group(2)!;
        dateTo = header.group(3) ?? dateFrom;
        continue;
      }
      if (skipped) continue;
      // 旧格式的子版本清单：之后的条目都不属于本节内容。
      if (trimmed == '### 子版本') {
        skipped = true;
        continue;
      }
      if (title != null) body.writeln(line);
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

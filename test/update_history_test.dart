import 'package:flutter_test/flutter_test.dart';

import 'package:musix/services/release_notes.dart';
import 'package:musix/services/update_history.dart';

void main() {
  group('UpdateHistory.parse (grouped diary)', () {
    const diary = '''
# 更新日记

## 0.8.12 · 2026-11-16 ~ 2026-11-17

### 新功能
- 后台下载
- 版本化文件名

### 问题修复
- 装成历史版本

### 子版本
- 0.8.12(002) · build-70 · 2026-11-17
- 0.8.12(001) · build-69 · 2026-11-16

## build-70 · 0.8.12(002) · 2026-11-17

<!-- build-70 -->

### 问题修复
- 装成历史版本

## build-69 · 0.8.12(001) · 2026-11-16

### 新功能
- 后台下载

## 0.8.11(024) · build-66 · 2026-11-15

### 新功能
- 检查更新全新改版

## build-7 · 2026-09-23

本版构建没有可展示的提交说明，可直接安装使用。
''';

    test('groups by base version with merged notes', () {
      final groups = UpdateHistory.parse(diary);
      expect(groups, hasLength(3));

      final grouped = groups[0];
      expect(grouped.title, '0.8.12');
      expect(grouped.dateFrom, '2026-11-16');
      expect(grouped.dateTo, '2026-11-17');
      expect(grouped.dateLabel, '2026-11-16 ~ 2026-11-17');
      // 聚合层去重：「装成历史版本」两版各出现一次只算一条；
      // 新功能两条不同，都保留。
      expect(grouped.notes.blocks
          .where((b) => b.kind == ReleaseNoteKind.bullet), hasLength(3));
      expect(grouped.builds, hasLength(2));
    });

    test('子版本 order is newest first and detail notes attach by tag', () {
      final groups = UpdateHistory.parse(diary);
      final builds = groups[0].builds;
      expect(builds.map((b) => b.tag).toList(), ['build-70', 'build-69']);
      expect(builds[0].title, '0.8.12(002)');
      expect(builds[0].date, '2026-11-17');
      expect(builds[0].notes.blocks
          .where((b) => b.kind == ReleaseNoteKind.bullet), hasLength(1));
      expect(builds[1].notes.changeCount, 1);
    });

    test('legacy single-version headers still parse', () {
      final groups = UpdateHistory.parse(diary);
      final legacy = groups[1];
      expect(legacy.title, '0.8.11(024)');
      expect(legacy.tagDate, isNull);
      expect(legacy.dateLabel, '2026-11-15');
      expect(legacy.builds, isEmpty);
      expect(legacy.notes.changeCount, 1);

      final tagOnly = groups[2];
      expect(tagOnly.title, 'build-7');
      expect(tagOnly.notes.isEmpty, isFalse);
    });

    test('returns empty for content without diary headers', () {
      expect(UpdateHistory.parse('随便一段文字'), isEmpty);
      expect(UpdateHistory.parse(''), isEmpty);
    });

    test('keeps the file order (old to new)', () {
      const two = '''
## 0.7.8 · 2026-09-01 ~ 2026-09-02

### 新功能
- a

### 子版本
- 0.7.8(002) · build-2 · 2026-09-02
- 0.7.8(001) · build-1 · 2026-09-01

## build-2 · 0.7.8(002) · 2026-09-02

### 新功能
- a

## 0.8.0(001) · build-3 · 2026-09-03

### 新功能
- b
''';
      final groups = UpdateHistory.parse(two);
      expect(groups.map((g) => g.title).toList(), ['0.7.8', '0.8.0(001)']);
      expect(groups[0].builds.map((b) => b.tag), ['build-2', 'build-1']);
    });
  });
}

extension on UpdateHistoryGroup {
  /// 占位：旧格式没有 tag 字段（tag 存在于 builds 或标题内）。
  String? get tagDate => null;
}

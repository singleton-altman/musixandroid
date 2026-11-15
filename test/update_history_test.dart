import 'package:flutter_test/flutter_test.dart';

import 'package:musix/services/release_notes.dart';
import 'package:musix/services/update_history.dart';

void main() {
  group('UpdateHistory.parse', () {
    test('parses version headers and grouped notes', () {
      const diary = '''
# 更新日记

## 0.8.11(024) · build-66 · 2026-11-15

<!-- build-66 -->

### 新功能
- 检查更新全新改版

### 问题修复
- 修复后台解析卡住

## 0.8.11(023) · build-65 · 2026-11-15

### 新功能
- 全站玻璃化统一

## build-7 · 2026-09-23

本版构建没有可展示的提交说明，可直接安装使用。
''';
      final entries = UpdateHistory.parse(diary);
      expect(entries, hasLength(3));

      expect(entries[0].title, '0.8.11(024)');
      expect(entries[0].tag, 'build-66');
      expect(entries[0].date, '2026-11-15');
      expect(entries[0].notes.changeCount, 2);
      expect(entries[0].notes.blocks.first.kind, ReleaseNoteKind.heading);
      expect(entries[0].notes.blocks.first.text, '新功能');

      expect(entries[1].title, '0.8.11(023)');
      expect(entries[1].notes.changeCount, 1);

      expect(entries[2].title, 'build-7');
      expect(entries[2].tag, 'build-7');
      expect(entries[2].date, '2026-09-23');
      expect(entries[2].notes.isEmpty, isFalse);
      expect(entries[2].notes.blocks.single.text,
          contains('没有可展示的提交说明'));
    });

    test('returns empty for content without diary headers', () {
      expect(UpdateHistory.parse('随便一段文字'), isEmpty);
      expect(UpdateHistory.parse(''), isEmpty);
    });

    test('keeps the file order (old to new)', () {
      const diary = '''
## 0.8.11(002) · build-44 · 2026-10-01

### 新功能
- a

## 0.8.11(023) · build-65 · 2026-11-15

### 新功能
- b
''';
      final entries = UpdateHistory.parse(diary);
      expect(entries.map((e) => e.tag).toList(), ['build-44', 'build-65']);
    });
  });
}

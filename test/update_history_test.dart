import 'package:flutter_test/flutter_test.dart';

import 'package:musix/services/release_notes.dart';
import 'package:musix/services/update_history.dart';

void main() {
  group('UpdateHistory.parse (one section per base version)', () {
    const diary = '''
# 更新日记

## 0.7.8 · 2026-09-23 ~ 2026-11-01

### 新功能
- 液态玻璃界面

## 0.8.11 · 2026-11-01 ~ 2026-11-16

### 问题修复
- 后台解析卡住

## 0.8.12 · 2026-11-16

### 新功能
- 后台下载
- 版本化文件名

### 问题修复
- 装成历史版本
''';

    test('parses one entry per base version', () {
      final groups = UpdateHistory.parse(diary);
      expect(groups.map((g) => g.title).toList(), ['0.7.8', '0.8.11', '0.8.12']);
    });

    test('single-date header keeps dateFrom == dateTo', () {
      final groups = UpdateHistory.parse(diary);
      final latest = groups.last;
      expect(latest.dateFrom, '2026-11-16');
      expect(latest.dateTo, '2026-11-16');
      expect(latest.dateLabel, '2026-11-16');
      expect(latest.notes.changeCount, 3);
      expect(latest.notes.blocks.where((b) => b.kind == ReleaseNoteKind.bullet),
          hasLength(3));
    });

    test('date range header keeps both ends', () {
      final groups = UpdateHistory.parse(diary);
      expect(groups.first.dateFrom, '2026-09-23');
      expect(groups.first.dateTo, '2026-11-01');
      expect(groups.first.dateLabel, '2026-09-23 ~ 2026-11-01');
      expect(groups.first.notes.changeCount, 1);
    });

    test('keeps the file order (old to new)', () {
      final groups = UpdateHistory.parse(diary);
      expect(groups.first.title, '0.7.8');
      expect(groups.last.title, '0.8.12');
    });

    test('sub-version lists from older diaries are ignored', () {
      const legacy = '''
## 0.8.12 · 2026-11-16 ~ 2026-11-17

### 新功能
- 后台下载

### 子版本
- 0.8.12(002) · build-70 · 2026-11-17

## build-70 · 0.8.12(002) · 2026-11-17

### 新功能
- 后台下载
''';
      final groups = UpdateHistory.parse(legacy);
      expect(groups, hasLength(1));
      expect(groups.first.notes.changeCount, 1);
    });

    test('returns empty for content without diary headers', () {
      expect(UpdateHistory.parse('随便一段文字'), isEmpty);
      expect(UpdateHistory.parse(''), isEmpty);
    });
  });
}

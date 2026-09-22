import 'package:flutter_test/flutter_test.dart';
import 'package:musix/services/release_notes.dart';

void main() {
  group('ReleaseNotes.parse', () {
    test('splits headings, bullets and paragraphs', () {
      final notes = ReleaseNotes.parse('''
## 新功能
- 支持锁屏收藏
- 新增歌词页

## 问题修复
- 修复后台解析卡死

修复若干小问题。
''');

      expect(notes.changeCount, 3);
      expect(notes.blocks.map((b) => b.kind), [
        ReleaseNoteKind.heading,
        ReleaseNoteKind.bullet,
        ReleaseNoteKind.bullet,
        ReleaseNoteKind.heading,
        ReleaseNoteKind.bullet,
        ReleaseNoteKind.text,
      ]);
      expect(notes.blocks[0].text, '新功能');
      expect(notes.blocks.last.text, '修复若干小问题。');
    });

    test('strips markdown emphasis, links and html while keeping text', () {
      final notes = ReleaseNotes.parse(
          '- **收藏**按钮改用 [心形图标](https://example.com) <br> 完成');
      expect(notes.blocks.single.text, '收藏按钮改用心形图标完成');
    });

    test('keeps latin spacing intact', () {
      final notes =
          ReleaseNotes.parse('- 支持 iOS 与 Android 的 **Material You** 配色');
      expect(notes.blocks.single.text, '支持 iOS 与 Android 的 Material You 配色');
    });

    test('ignores dividers, comments and generated changelog footers', () {
      final notes = ReleaseNotes.parse('''
- 修复崩溃

---
<!-- internal note -->
**Full Changelog**: https://github.com/x/msix/compare/a...b
''');
      expect(notes.blocks.single.kind, ReleaseNoteKind.bullet);
      expect(notes.blocks.single.text, '修复崩溃');
    });

    test('empty body yields empty notes', () {
      expect(ReleaseNotes.parse('').isEmpty, isTrue);
      expect(ReleaseNotes.parse('\n\n  \n').isEmpty, isTrue);
    });
  });

  group('ReleaseNotes.fromCommits', () {
    test('groups conventional commits in display order', () {
      final notes = ReleaseNotes.fromCommits([
        'fix(player): 修复后台解析卡死',
        'feat: 支持锁屏收藏',
        'perf: 首屏更快',
        'Merge branch main',
      ]);
      expect(notes.blocks.map((b) => b.text), [
        '新功能',
        '支持锁屏收藏',
        '问题修复',
        '修复后台解析卡死',
        '性能优化',
        '首屏更快',
      ]);
    });

    test('unknown types fall back to a shared section', () {
      final notes = ReleaseNotes.fromCommits(['chore: 升级依赖', '随手改一下']);
      expect(notes.blocks.first.text, '其它改动');
      expect(notes.changeCount, 2);
    });
  });
}

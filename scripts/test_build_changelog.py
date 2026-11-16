import unittest
from pathlib import Path
import tempfile

from build_changelog import (
    EMPTY_NOTES,
    base_of_title,
    group_body,
    group_entries,
    merge_notes,
    parse_note_blocks,
    render_diary,
)


def entry(tag, title, date, notes=''):
    return {'tag': tag, 'title': title, 'date': date, 'notes': notes}


def render(entries, bodies=None):
    groups = group_entries(entries)
    if bodies is None:
        bodies = [merge_notes([e['notes'] for e in g['entries']]) for g in groups]
    return render_diary(groups, bodies)


class ParseNoteBlocksTest(unittest.TestCase):
    def test_groups_bullets_under_headings(self):
        blocks = parse_note_blocks(
            '### 新功能\n- 加了 A\n- 加了 B\n### 问题修复\n- 修了 C\n')
        self.assertEqual(blocks, [
            ('新功能', ['加了 A', '加了 B']),
            ('问题修复', ['修了 C']),
        ])

    def test_skips_comments_dividers_and_blanks(self):
        blocks = parse_note_blocks(
            '<!-- build-70 -->\n\n### 新功能\n- X\n---\n### 问题修复\n- Y\n')
        self.assertEqual(blocks, [('新功能', ['X']), ('问题修复', ['Y'])])

    def test_stray_paragraph_becomes_item(self):
        blocks = parse_note_blocks('本版构建没有可展示的提交说明。')
        self.assertEqual(blocks, [('', ['本版构建没有可展示的提交说明。'])])


class MergeNotesTest(unittest.TestCase):
    def test_merges_and_dedupes(self):
        merged = merge_notes([
            '### 新功能\n- 后台下载\n### 问题修复\n- 修复安装\n',
            '### 新功能\n- 后台下载\n- 版本化文件名\n',
        ])
        self.assertEqual(merged, '### 新功能\n- 后台下载\n- 版本化文件名\n'
                                 '\n### 问题修复\n- 修复安装')

    def test_canonical_heading_order(self):
        merged = merge_notes([
            '### 问题修复\n- 修\n### 新功能\n- 加\n### 自定义\n- 其它\n'])
        order = [line[4:] for line in merged.splitlines()
                 if line.startswith('### ')]
        self.assertEqual(order, ['新功能', '问题修复', '自定义'])

    def test_overflow_is_capped_with_hint(self):
        items = '\n'.join(f'- 条目 {i}' for i in range(25))
        merged = merge_notes([f'### 新功能\n{items}\n'])
        bullets = [l for l in merged.splitlines() if l.startswith('- ')]
        self.assertEqual(len(bullets), 21)  # 20 + 1 hint line
        self.assertIn('另有 5 项', bullets[-1])

    def test_empty_bodies_render_nothing(self):
        self.assertEqual(merge_notes(['', EMPTY_NOTES]), '')


class BaseOfTitleTest(unittest.TestCase):
    def test_display_version_yields_base(self):
        self.assertEqual(base_of_title('0.8.12(003)'), '0.8.12')

    def test_pre_scheme_tag_yields_none(self):
        self.assertIsNone(base_of_title('build-7'))
        self.assertIsNone(base_of_title(''))


class GroupEntriesTest(unittest.TestCase):
    def test_same_base_collapses_into_one_group(self):
        groups = group_entries([
            entry('build-69', '0.8.12(001)', '2026-11-16'),
            entry('build-70', '0.8.12(002)', '2026-11-16'),
            entry('build-71', '0.8.12(003)', '2026-11-17'),
        ])
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]['base'], '0.8.12')
        self.assertEqual(len(groups[0]['entries']), 3)

    def test_new_base_starts_a_new_group(self):
        groups = group_entries([
            entry('build-40', '0.7.8(001)', '2026-10-07'),
            entry('build-56', '0.8.11(014)', '2026-11-01'),
            entry('build-69', '0.8.12(001)', '2026-11-16'),
        ])
        self.assertEqual([g['base'] for g in groups], ['0.7.8', '0.8.11', '0.8.12'])

    def test_legacy_tags_fold_into_earliest_group(self):
        groups = group_entries([
            entry('build-7', 'build-7', '2026-09-23'),
            entry('build-8', 'build-8', '2026-09-23'),
            entry('build-43', '0.7.8(001)', '2026-10-07'),
        ])
        self.assertEqual([g['base'] for g in groups], ['0.7.8'])
        self.assertEqual(len(groups[0]['entries']), 3)

    def test_legacy_tags_after_a_group_join_it(self):
        groups = group_entries([
            entry('build-43', '0.7.8(001)', '2026-10-07'),
            entry('build-44', 'build-44', '2026-10-08'),
        ])
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0]['entries']), 2)


class RenderDiaryTest(unittest.TestCase):
    def test_one_section_per_base_with_merged_items(self):
        diary = render([
            entry('build-69', '0.8.12(001)', '2026-11-16',
                  '### 新功能\n- 后台下载\n'),
            entry('build-70', '0.8.12(002)', '2026-11-17',
                  '### 问题修复\n- 版本化文件名\n'),
        ])
        self.assertIn('## 0.8.12 · 2026-11-16 ~ 2026-11-17', diary)
        self.assertIn('- 后台下载', diary)
        self.assertIn('- 版本化文件名', diary)
        # 不再有子版本清单与每个 build 的明细节
        self.assertNotIn('### 子版本', diary)
        self.assertNotIn('build-69', diary)
        self.assertNotIn('build-70', diary)
        self.assertEqual(diary.count('\n## '), 1)

    def test_single_date_header_when_group_spans_one_day(self):
        diary = render([
            entry('build-72', '0.8.12(004)', '2026-11-16', '### 新功能\n- 甲\n'),
        ])
        self.assertIn('## 0.8.12 · 2026-11-16\n', diary)

    def test_groups_keep_old_to_new_order(self):
        diary = render([
            entry('build-40', '0.7.8(001)', '2026-10-07', '### 新功能\n- 甲\n'),
            entry('build-56', '0.8.11(014)', '2026-11-01', '### 新功能\n- 乙\n'),
            entry('build-69', '0.8.12(001)', '2026-11-16', '### 新功能\n- 丙\n'),
        ])
        self.assertLess(diary.index('## 0.7.8 ·'), diary.index('## 0.8.11 ·'))
        self.assertLess(diary.index('## 0.8.11 ·'), diary.index('## 0.8.12 ·'))

    def test_empty_notes_use_placeholder(self):
        diary = render([entry('build-7', 'build-7', '2026-09-23', EMPTY_NOTES)])
        self.assertIn(EMPTY_NOTES, diary)


class GroupBodyTest(unittest.TestCase):
    def test_hand_written_summary_wins(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'release_notes').mkdir()
            (root / 'release_notes' / '0.8.12.md').write_text(
                '## 界面\n- 手写条目\n', encoding='utf-8')
            group = {'base': '0.8.12', 'entries': [
                entry('build-70', '0.8.12(002)', '2026-11-17',
                      '### 新功能\n- 自动条目\n'),
            ]}
            body = group_body(root, group)
            self.assertIn('### 界面', body)
            self.assertIn('- 手写条目', body)
            self.assertNotIn('自动条目', body)

    def test_falls_back_to_merged_notes(self):
        with tempfile.TemporaryDirectory() as tmp:
            group = {'base': '0.9.0', 'entries': [
                entry('build-80', '0.9.0(001)', '2026-12-01',
                      '### 新功能\n- 自动条目\n'),
            ]}
            self.assertIn('- 自动条目', group_body(Path(tmp), group))


if __name__ == '__main__':
    unittest.main()

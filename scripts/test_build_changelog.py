import unittest

from build_changelog import (
    EMPTY_NOTES,
    merge_notes,
    parse_note_blocks,
    render_diary,
)


def section(tag, title, date, body):
    return (tag, title, date, body)


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


class RenderDiaryTest(unittest.TestCase):
    def test_multi_build_base_collapses_into_group(self):
        diary = render_diary([
            section('build-69', '0.8.12(001)', '2026-11-16',
                    '### 新功能\n- 后台下载\n'),
            section('build-70', '0.8.12(002)', '2026-11-16',
                    '### 问题修复\n- 版本化文件名\n'),
        ])
        self.assertIn('## 0.8.12 · 2026-11-16 ~ 2026-11-16', diary)
        self.assertIn('- 后台下载', diary)
        self.assertIn('- 版本化文件名', diary)
        self.assertIn('### 子版本', diary)
        # 子版本 newest first
        sub = diary.split('### 子版本')[1].split('## ')[0]
        self.assertLess(sub.index('build-70'), sub.index('build-69'))
        # detail sections follow the group, newest first
        self.assertIn('## build-70 · 0.8.12(002) · 2026-11-16', diary)
        self.assertIn('## build-69 · 0.8.12(001) · 2026-11-16', diary)

    def test_single_build_base_keeps_legacy_format(self):
        diary = render_diary([
            section('build-69', '0.8.12(001)', '2026-11-16',
                    '### 新功能\n- 只此一版\n'),
        ])
        self.assertIn('## 0.8.12(001) · build-69 · 2026-11-16', diary)
        self.assertNotIn('### 子版本', diary)
        self.assertNotIn('## 0.8.12 ·', diary)

    def test_unknown_base_falls_back_to_tag(self):
        diary = render_diary([
            section('build-7', 'build-7', '2026-09-23', EMPTY_NOTES),
        ])
        self.assertIn('## build-7 · 2026-09-23', diary)
        self.assertIn(EMPTY_NOTES, diary)

    def test_groups_keep_file_order_old_to_new(self):
        diary = render_diary([
            section('build-1', '0.7.8(001)', '2026-09-01',
                    '### 新功能\n- 甲\n'),
            section('build-2', '0.7.8(002)', '2026-09-02',
                    '### 新功能\n- 乙\n'),
            section('build-3', '0.8.0(001)', '2026-09-03',
                    '### 新功能\n- 丙\n'),
        ])
        self.assertLess(diary.index('## 0.7.8 ·'), diary.index('## build-1 ·'))
        self.assertLess(diary.index('## build-1 ·'), diary.index('0.8.0(001)'))

    def test_in_flight_build_joins_its_base_group(self):
        diary = render_diary([
            section('build-69', '0.8.12(001)', '2026-11-16',
                    '### 新功能\n- 后台下载\n'),
            section('build-70', '0.8.12(002)', '2026-11-16',
                    '### 问题修复\n- 版本化文件名\n'),
            section('build-71', '0.8.12(003)', '2026-11-17',
                    '### 问题修复\n- 日记聚合\n'),
        ])
        self.assertIn('## 0.8.12 · 2026-11-16 ~ 2026-11-17', diary)
        self.assertIn('- 0.8.12(003) · build-71 · 2026-11-17', diary)


if __name__ == '__main__':
    unittest.main()

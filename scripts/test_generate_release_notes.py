import unittest

from generate_release_notes import (
    build_sections,
    classify,
    commit_subjects,
    previous_tag,
    render_notes,
)


class ClassifyTests(unittest.TestCase):
    def test_conventional_commit_types(self):
        self.assertEqual(classify('feat(player): 支持锁屏收藏'),
                         ('feat', '支持锁屏收藏（player）'))
        self.assertEqual(classify('fix: 修复后台解析卡死'),
                         ('fix', '修复后台解析卡死'))

    def test_plain_subject_is_kept_as_other(self):
        self.assertEqual(classify('更新图标'), ('other', '更新图标'))

    def test_merges_and_release_plumbing_are_skipped(self):
        for subject in ['Merge branch main', 'Merge pull request #1 from x',
                        'chore(release): bump']:
            with self.subTest(subject=subject):
                self.assertIsNone(classify(subject))


class SectionTests(unittest.TestCase):
    def test_groups_follow_display_order(self):
        sections = build_sections([
            'fix: 修复崩溃',
            'feat: 新增歌词页',
            'perf: 首屏更快',
            'docs: 更新说明',
        ])
        self.assertEqual([title for title, _ in sections],
                         ['新功能', '问题修复', '性能优化', '文档'])

    def test_unknown_type_lands_in_other_and_keeps_scope(self):
        sections = build_sections(['chore(deps): 升级依赖', '随便一句'])
        self.assertEqual(sections, [('其它改动', ['升级依赖（deps）', '随便一句'])])

    def test_render_skips_empty_and_writes_footer(self):
        self.assertEqual(render_notes(['Merge branch x']), '')
        notes = render_notes(['feat: 新增歌词页'], build_tag='build-65',
                             commit='abc1234', date='2026-11-15')
        self.assertIn('## 新功能', notes)
        self.assertIn('- 新增歌词页', notes)
        self.assertIn('build-65 · abc1234 · 2026-11-15', notes)


class GitIntegrationTests(unittest.TestCase):
    def test_repository_history_is_readable(self):
        root = __import__('pathlib').Path(__file__).resolve().parents[1]
        if not (root / '.git').exists():
            self.skipTest('not a git checkout')
        # The checkout always has commits; a tag may or may not exist yet.
        previous_tag(root)
        self.assertIsInstance(commit_subjects(root, '', limit=3), list)


if __name__ == '__main__':
    unittest.main()

"""Generate Markdown release notes from commits between build tags.

The release workflow used to publish releases with an empty body, so the app's
update sheet could only show the version number. This script turns the commits
since the previous `build-N` tag into a short, grouped changelog that is passed
to `action-gh-release` via `body_path`, and that the app renders as structured
update content.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

# Conventional commit type -> section title. Order is the display order.
GROUP_TITLES = [
    ('feat', '新功能'),
    ('fix', '问题修复'),
    ('perf', '性能优化'),
    ('style', '界面与体验'),
    ('refactor', '重构'),
    ('docs', '文档'),
    ('test', '测试'),
    ('build', '构建'),
    ('ci', '持续集成'),
]
OTHER_TITLE = '其它改动'

GROUP_INDEX = dict(GROUP_TITLES)

SUBJECT_RE = re.compile(
    r'^(?P<type>\w+)(?:\((?P<scope>[^)]*)\))?!?:\s*(?P<desc>.+)$')
SKIP_RE = re.compile(r'^(merge\b|revert\b|chore\(release\))', re.IGNORECASE)

MAX_ITEMS_PER_GROUP = 12

EMPTY_NOTES = '本版构建没有可展示的提交说明，可直接安装使用。'


def classify(subject):
    """Split a commit subject into (group, display text).

    Returns None for commits that should not be shown to end users (merges,
    reverts and release-plumbing commits). Unknown types are kept so nothing is
    silently dropped from the changelog.
    """
    subject = subject.strip()
    if not subject or SKIP_RE.match(subject):
        return None
    match = SUBJECT_RE.match(subject)
    if match is None:
        return ('other', subject)
    kind = match.group('type').lower()
    description = match.group('desc').strip()
    scope = (match.group('scope') or '').strip()
    text = f'{description}（{scope}）' if scope else description
    return (kind, text)


def build_sections(subjects):
    """Group commit subjects into ordered (title, items) sections."""
    grouped = {}
    other = []
    for subject in subjects:
        entry = classify(subject)
        if entry is None:
            continue
        kind, text = entry
        if kind in GROUP_INDEX:
            grouped.setdefault(kind, []).append(text)
        else:
            other.append(text)

    sections = []
    for kind, title in GROUP_TITLES:
        items = grouped.get(kind, [])
        if items:
            sections.append((title, items[:MAX_ITEMS_PER_GROUP]))
    if other:
        sections.append((OTHER_TITLE, other[:MAX_ITEMS_PER_GROUP]))
    return sections


def render_notes(subjects, build_tag='', commit='', date=''):
    """Render grouped Markdown notes; empty string when nothing is reportable."""
    sections = build_sections(subjects)
    if not sections:
        return ''

    lines = []
    for title, items in sections:
        lines.append(f'## {title}')
        lines.extend(f'- {item}' for item in items)
        lines.append('')

    footer = [part for part in (build_tag, commit, date) if part]
    if footer:
        lines.append('---')
        lines.append(' · '.join(footer))
    return '\n'.join(lines).strip() + '\n'


def _git(root, *args):
    result = subprocess.run(
        ['git', *args],
        cwd=str(root),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return ''
    return result.stdout


def previous_tag(root):
    """Nearest `build-*` tag reachable from HEAD (the last published build)."""
    git_dir = root / '.git'
    if not git_dir.exists():
        return ''
    return _git(root, 'describe', '--tags', '--abbrev=0',
                '--match', 'build-*').strip()


def commit_subjects(root, since_tag, limit=60):
    args = ['log', '--no-merges', '--pretty=%s', f'-n{limit}']
    if since_tag:
        args.append(f'{since_tag}..HEAD')
    output = _git(root, *args)
    return [line for line in output.splitlines() if line.strip()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='write notes here (default: stdout)')
    parser.add_argument('--repo-root', default='.', help='git checkout root')
    parser.add_argument('--build-tag', default='', help='tag of this build')
    parser.add_argument('--commit', default='', help='short commit hash')
    parser.add_argument('--date', default='', help='build date')
    parser.add_argument('--from-tag', default=None,
                        help='override the detected previous tag')
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    since = args.from_tag if args.from_tag is not None else previous_tag(root)
    subjects = commit_subjects(root, since)
    notes = render_notes(subjects, build_tag=args.build_tag,
                         commit=args.commit, date=args.date)
    if not notes:
        notes = EMPTY_NOTES + '\n'

    if args.output:
        Path(args.output).write_text(notes, encoding='utf-8')
        print(f'Release notes: {len(subjects)} commit subject(s), '
              f'since {since or "the beginning"}.', file=sys.stderr)
    else:
        print(notes, end='')


if __name__ == '__main__':
    main()

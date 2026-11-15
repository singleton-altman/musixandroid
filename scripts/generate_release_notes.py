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
BULLET_RE = re.compile(r'^[-*]\s+')

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


def build_sections(entries):
    """Group commit entries into ordered (title, items) sections.

    Entries are commit subjects plus bullet lines from commit bodies, so a
    single squashed commit with a detailed body still yields a rich changelog.
    Duplicate entries are kept once per section.
    """
    grouped = {}
    other = []
    seen_grouped = set()
    seen_other = set()
    for entry in entries:
        result = classify(entry)
        if result is None:
            continue
        kind, text = result
        if kind in GROUP_INDEX:
            if text in seen_grouped:
                continue
            seen_grouped.add(text)
            grouped.setdefault(kind, []).append(text)
        else:
            if text in seen_other:
                continue
            seen_other.add(text)
            other.append(text)

    sections = []
    for kind, title in GROUP_TITLES:
        items = grouped.get(kind, [])
        if items:
            sections.append((title, items[:MAX_ITEMS_PER_GROUP]))
    if other:
        sections.append((OTHER_TITLE, other[:MAX_ITEMS_PER_GROUP]))
    return sections


def render_notes(entries, build_tag='', commit='', date=''):
    """Render grouped Markdown notes; empty string when nothing is reportable."""
    sections = build_sections(entries)
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


def commit_entries(root, since_tag, limit=60, until='HEAD'):
    """Collect commit subjects plus bullet lines from their bodies.

    Squashed commits (one summary + a bulleted detail body) are common on this
    repo, and the bullets carry the user-facing details the changelog needs.
    """
    args = ['log', '--no-merges', '--pretty=format:%x1e%s%n%b', f'-n{limit}']
    if since_tag:
        args.append(f'{since_tag}..{until}')
    output = _git(root, *args)
    entries = []
    for block in output.split('\x1e'):
        lines = block.strip().splitlines()
        if not lines:
            continue
        subject = lines[0].strip()
        if subject:
            entries.append(subject)
        for line in lines[1:]:
            text = line.strip()
            while BULLET_RE.match(text):
                text = BULLET_RE.sub('', text, count=1).strip()
            if text:
                entries.append(text)
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='write notes here (default: stdout)')
    parser.add_argument('--repo-root', default='.', help='git checkout root')
    parser.add_argument('--build-tag', default='', help='tag of this build')
    parser.add_argument('--commit', default='', help='short commit hash')
    parser.add_argument('--date', default='', help='build date')
    parser.add_argument('--from-tag', default=None,
                        help='override the detected previous tag')
    parser.add_argument('--override', default='',
                        help='path to hand-written notes; used only when the '
                             'file contains the current build tag, so stale '
                             'override files never leak into newer builds')
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    footer = ' · '.join(part for part in
                        (args.build_tag, args.commit, args.date) if part)

    if args.override and args.build_tag:
        override_path = Path(args.override)
        if override_path.exists():
            content = override_path.read_text(encoding='utf-8').strip()
            if content and args.build_tag in content:
                notes = content + '\n\n---\n' + footer + '\n' if footer \
                    else content + '\n'
                if args.output:
                    Path(args.output).write_text(notes, encoding='utf-8')
                    print(f'Release notes: hand-written override '
                          f'({override_path}).', file=sys.stderr)
                else:
                    print(notes, end='')
                return

    since = args.from_tag if args.from_tag is not None else previous_tag(root)
    entries = commit_entries(root, since)
    notes = render_notes(entries, build_tag=args.build_tag,
                         commit=args.commit, date=args.date)
    if not notes:
        notes = EMPTY_NOTES + '\n'

    if args.output:
        Path(args.output).write_text(notes, encoding='utf-8')
        print(f'Release notes: {len(entries)} entry/entries, '
              f'since {since or "the beginning"}.', file=sys.stderr)
    else:
        print(notes, end='')


if __name__ == '__main__':
    main()

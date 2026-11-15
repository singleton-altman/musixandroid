"""Build the bundled update diary (assets/changelog.md) from build tags.

Every `build-N` tag becomes one diary section: the display version derived the
same way CI does (pubspec base + run_number offset), the tag date, and the
grouped notes for the commits between the previous build tag and this one.
`RELEASE_NOTES.md` wins for the tag it names (hand-written notes), so the
bundled diary matches the published release body exactly.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

from generate_release_notes import (
    EMPTY_NOTES,
    build_sections,
    commit_entries,
)

TAG_RE = re.compile(r'^build-(\d+)$')
VERSION_RE = re.compile(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', re.MULTILINE)
OFFSET_RE = re.compile(r'^versionCodeOffset=(\d+)\s*$', re.MULTILINE)


def _git(root, *args):
    result = subprocess.run(
        ['git', *args],
        cwd=str(root),
        capture_output=True,
        text=True,
    )
    return result.stdout if result.returncode == 0 else ''


def build_tags(root):
    tags = []
    for tag in _git(root, 'tag', '--list', 'build-*').splitlines():
        tag = tag.strip()
        match = TAG_RE.match(tag)
        if match:
            tags.append((int(match.group(1)), tag))
    return sorted(set(tags))


def tag_title(root, number, tag):
    """Display version for a tag, mirroring prepare_app_version.py."""
    pubspec = _git(root, 'show', f'{tag}:pubspec.yaml')
    properties = _git(root, 'show', f'{tag}:android/version.properties')
    version = VERSION_RE.search(pubspec)
    offset = OFFSET_RE.search(properties)
    if version is None or offset is None:
        return ''
    sequence = number - int(offset.group(1))
    if sequence < 1:
        return ''
    return f'{version.group(1)}({sequence:03d})'


def head_title(root, run_number):
    """Display version for the build in flight (tag not created yet)."""
    try:
        pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
        properties = (root / 'android/version.properties').read_text(
            encoding='utf-8')
    except OSError:
        return ''
    version = VERSION_RE.search(pubspec)
    offset = OFFSET_RE.search(properties)
    if version is None or offset is None or run_number <= 0:
        return ''
    sequence = run_number - int(offset.group(1))
    if sequence < 1:
        return ''
    return f'{version.group(1)}({sequence:03d})'


def tag_date(root, tag):
    return _git(root, 'log', '-1', '--format=%cs', tag).strip()


def _demote_headings(body):
    """Hand-written notes use `##` group headings; the diary reserves `##`
    for the version line, so demote everything below the section header."""
    lines = []
    for line in body.splitlines():
        if line.startswith('#') and not line.startswith('###'):
            stripped = line.lstrip('#').strip()
            line = f'### {stripped}' if stripped else ''
        lines.append(line)
    return '\n'.join(lines).strip()


def hand_written_notes(root, tag):
    """RELEASE_NOTES.md content when it names [tag], else empty."""
    path = root / 'RELEASE_NOTES.md'
    if not path.exists():
        return ''
    content = path.read_text(encoding='utf-8').strip()
    if not content:
        return ''
    # Word-boundary match: `build-6` must not match inside `build-66`.
    if re.search(rf'(?<![\w-]){re.escape(tag)}(?!\d)', content):
        return _demote_headings(content)
    return ''


def tag_notes(root, number, tag):
    """Notes body for one tag: hand-written override, else commit-derived."""
    handwritten = hand_written_notes(root, tag)
    if handwritten:
        return handwritten
    previous = f'build-{number - 1}'
    for step in range(1, 5):
        candidate = f'build-{number - step}'
        if candidate in _known_tags(root):
            previous = candidate
            break
    entries = commit_entries(root, previous, limit=60, until=tag)
    sections = build_sections(entries)
    if not sections:
        return EMPTY_NOTES
    lines = []
    for title, items in sections:
        lines.append(f'### {title}')
        lines.extend(f'- {item}' for item in items[:12])
        lines.append('')
    return '\n'.join(lines).strip()


_KNOWN_CACHE = {}


def _known_tags(root):
    key = str(root)
    if key not in _KNOWN_CACHE:
        _KNOWN_CACHE[key] = {tag for _, tag in build_tags(root)}
    return _KNOWN_CACHE[key]


def render_changelog(root, current_tag='', current_date='',
                     current_run_number=0):
    """Render the diary; tags ascending, optionally plus the in-flight build."""
    sections = []
    for number, tag in build_tags(root):
        title = tag_title(root, number, tag) or tag
        sections.append((number, tag, tag_date(root, tag), title,
                         tag_notes(root, number, tag)))

    # CI runs before the tag exists: append the in-flight build from HEAD.
    match = TAG_RE.match(current_tag)
    if match and not any(section[1] == current_tag for section in sections):
        body = hand_written_notes(root, current_tag)
        if not body:
            previous = _git(root, 'describe', '--tags', '--abbrev=0',
                            '--match', 'build-*').strip()
            entries = commit_entries(root, previous, limit=60)
            body_lines = []
            for title, items in build_sections(entries):
                body_lines.append(f'### {title}')
                body_lines.extend(f'- {item}' for item in items[:12])
                body_lines.append('')
            body = '\n'.join(body_lines).strip()
        if body:
            title = head_title(root, current_run_number) or current_tag
            sections.append((match.group(1), current_tag,
                             current_date, title, body))

    lines = ['# 更新日记', '']
    for _number, tag, date, title, body in sections:
        # Old tags predate the version scheme; avoid a duplicated "build-N".
        header = f'## {title} · {tag} · {date}' if title != tag \
            else f'## {tag} · {date}'
        lines.extend([header, '', body or EMPTY_NOTES, ''])
    return '\n'.join(lines).strip() + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='write diary here (default: stdout)')
    parser.add_argument('--repo-root', default='.', help='git checkout root')
    parser.add_argument('--current-tag', default='',
                        help='tag of the build in flight (CI only)')
    parser.add_argument('--current-date', default='',
                        help='date of the build in flight')
    parser.add_argument('--current-run-number', type=int, default=0,
                        help='workflow run number of the build in flight')
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    if not (root / '.git').exists():
        print('not a git checkout; keeping existing changelog', file=sys.stderr)
        return
    diary = render_changelog(root, current_tag=args.current_tag,
                             current_date=args.current_date,
                             current_run_number=args.current_run_number)
    if args.output:
        Path(args.output).write_text(diary, encoding='utf-8')
        count = diary.count('\n## ')
        print(f'Update diary: {count} version(s).', file=sys.stderr)
    else:
        print(diary, end='')


if __name__ == '__main__':
    main()

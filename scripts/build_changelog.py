"""Build the bundled update diary (assets/changelog.md) from build tags.

The diary is grouped by base version (`0.8.12`), not per build: one section per
base with merged, de-duplicated items, a `### 子版本` list, then one detail
section per build tag. Single-build bases and tags without a known version fall
back to the legacy one-section-per-build format. Hand-written notes archived as
`release_notes/<tag>.md` win, so the bundled diary matches the published
release body exactly.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

from generate_release_notes import (
    EMPTY_NOTES,
    GROUP_TITLES,
    archived_notes,
    build_sections,
    commit_entries,
)
from version_scheme import display_sequence, parse_base, parse_offset

TAG_RE = re.compile(r'^build-(\d+)$')


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


def tag_bases(root, tags):
    """(build_number, base_version) for each tag — needed by the sequence rule."""
    pairs = []
    for number, tag in tags:
        base = parse_base(_git(root, 'show', f'{tag}:pubspec.yaml'))
        if base:
            pairs.append((number, base))
    return pairs


def _title(base, sequence):
    if not base or sequence is None or sequence < 1:
        return ''
    return f'{base}({sequence:03d})'


def tag_title(root, number, tag, bases=None):
    """Display version for a tag, mirroring scripts/version_scheme.py."""
    base = parse_base(_git(root, 'show', f'{tag}:pubspec.yaml'))
    offset = parse_offset(_git(root, 'show', f'{tag}:android/version.properties'))
    if not base:
        return ''
    pairs = bases if bases is not None else tag_bases(root, build_tags(root))
    return _title(base, display_sequence(number, base, pairs, offset))


def head_title(root, run_number, bases=None):
    """Display version for the build in flight (tag not created yet)."""
    try:
        pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
        properties = (root / 'android/version.properties').read_text(
            encoding='utf-8')
    except OSError:
        return ''
    base = parse_base(pubspec)
    offset = parse_offset(properties)
    if not base or run_number <= 0:
        return ''
    pairs = bases if bases is not None else tag_bases(root, build_tags(root))
    return _title(base, display_sequence(run_number, base, pairs, offset))


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
    """Archived hand-written notes for [tag], demoted to `###` headings."""
    content = archived_notes(root, tag)
    if not content:
        return ''
    return _demote_headings(content)


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


# ===========================================================================
# Diary rendering: base-version groups + per-build detail sections
# ===========================================================================

MAX_MERGED_PER_GROUP = 20

_NOTE_HEADING_RE = re.compile(r'^###\s+(.+?)\s*$')
_NOTE_BULLET_RE = re.compile(r'^[-*]\s+(.+?)\s*$')
_BASE_OF_RE = re.compile(r'^(\d+\.\d+\.\d+)\(')


def _base_of(title, tag):
    """Base version behind a display title; unknown versions fall back to tag."""
    match = _BASE_OF_RE.match(title or '')
    return match.group(1) if match else tag


def _item_key(text):
    """Normalization for de-duplication: letters/digits/CJK only."""
    return re.sub(r'[\W_]+', '', text, flags=re.UNICODE).lower()


def parse_note_blocks(body):
    """Markdown notes -> ordered [(heading, [items])]; comments/dividers dropped."""
    groups = []
    current = None
    for raw in (body or '').splitlines():
        line = raw.strip()
        if not line or line.startswith('<!--') or line == '---':
            continue
        heading = _NOTE_HEADING_RE.match(line)
        if heading:
            current = [heading.group(1), []]
            groups.append(current)
            continue
        bullet = _NOTE_BULLET_RE.match(line)
        if bullet:
            if current is None:
                current = ['', []]
                groups.append(current)
            current[1].append(bullet.group(1))
            continue
        # Stray paragraph (e.g. EMPTY_NOTES): keep it as an item.
        if current is None:
            current = ['', []]
            groups.append(current)
        current[1].append(line)
    return [(heading, items) for heading, items in groups]


def merge_notes(bodies):
    """Merge several notes bodies into one de-duplicated markdown body."""
    per_heading = {}
    for body in bodies:
        if not body or body == EMPTY_NOTES:
            continue
        for heading, items in parse_note_blocks(body):
            bucket = per_heading.setdefault(heading, {'items': [], 'seen': set()})
            for item in items:
                key = _item_key(item)
                if not key or key in bucket['seen']:
                    continue
                bucket['seen'].add(key)
                bucket['items'].append(item)
    if not per_heading:
        return ''

    group_order = [title for _, title in GROUP_TITLES]

    def rank(heading):
        return group_order.index(heading) if heading in group_order \
            else len(group_order)

    lines = []
    for heading in sorted(per_heading, key=rank):
        items = per_heading[heading]['items']
        shown = items[:MAX_MERGED_PER_GROUP]
        if heading:
            lines.append(f'### {heading}')
        lines.extend(f'- {item}' for item in shown)
        dropped = len(items) - len(shown)
        if dropped > 0:
            lines.append(f'- … 另有 {dropped} 项同组改动已合并，见子版本明细')
        lines.append('')
    return '\n'.join(lines).strip()


def render_diary(sections):
    """Render grouped diary markdown from ascending sections.

    [sections] is a list of (tag, title, date, notes_markdown), oldest first.
    Consecutive sections sharing one base version collapse into a single
    `## <base> · <from> ~ <to>` group with merged notes and per-build detail
    sections; single-build groups keep the legacy one-section format.
    """
    lines = ['# 更新日记', '']
    index = 0
    total = len(sections)
    while index < total:
        tag, title, date, body = sections[index]
        base = _base_of(title, tag)
        group = [sections[index]]
        probe = index + 1
        while probe < total and _base_of(sections[probe][1],
                                         sections[probe][0]) == base:
            group.append(sections[probe])
            probe += 1
        index = probe

        if len(group) == 1 or base == tag:
            single = group[0]
            header = f'## {single[1]} · {single[0]} · {single[2]}' \
                if single[1] != single[0] else f'## {single[0]} · {single[2]}'
            lines.extend([header, '', single[3] or EMPTY_NOTES, ''])
            continue

        lines.append(f'## {base} · {group[0][2]} ~ {group[-1][2]}')
        lines.append('')
        merged = merge_notes([s[3] for s in group
                              if s[3] and s[3] != EMPTY_NOTES])
        lines.append(merged or EMPTY_NOTES)
        lines.append('')
        lines.append('### 子版本')
        for entry in reversed(group):
            lines.append(f'- {entry[1]} · {entry[0]} · {entry[2]}')
        lines.append('')
        for entry in reversed(group):
            header = f'## {entry[0]} · {entry[1]} · {entry[2]}' \
                if entry[1] != entry[0] else f'## {entry[0]} · {entry[2]}'
            lines.extend([header, '', entry[3] or EMPTY_NOTES, ''])
    return '\n'.join(lines).strip() + '\n'


def render_changelog(root, current_tag='', current_date='',
                     current_run_number=0):
    """Collect sections from git and render the grouped diary."""
    tags = build_tags(root)
    bases = tag_bases(root, tags)
    sections = []
    for number, tag in tags:
        title = tag_title(root, number, tag, bases) or tag
        sections.append((tag, title, tag_date(root, tag),
                         tag_notes(root, number, tag)))

    # CI runs before the tag exists: append the in-flight build from HEAD.
    match = TAG_RE.match(current_tag)
    if match and not any(section[0] == current_tag for section in sections):
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
            title = head_title(root, current_run_number, bases) or current_tag
            sections.append((current_tag, title, current_date, body))

    return render_diary(sections)


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
        groups = len(re.findall(r'\n## \d+\.\d+\.\d+ · ', diary))
        builds = len(re.findall(r'\n## (?:.+\n)?', diary))
        print(f'Update diary: {groups} base version(s), '
              f'{builds} section(s).', file=sys.stderr)
    else:
        print(diary, end='')


if __name__ == '__main__':
    main()

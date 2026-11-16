"""Build the bundled update diary (assets/changelog.md) from build tags.

The diary is grouped by **base version** only: one section per base (`0.7.8`,
`0.8.11`, `0.8.12`) carrying the merged, de-duplicated items of every build in
that base, with no per-build detail. A base stays open until `pubspec.yaml`
moves to the next one, so the newest group keeps growing on every release.

A hand-written summary wins for the group body: `release_notes/<base>.md`
(e.g. `release_notes/0.7.8.md`). Without one the diary merges the commit-derived
notes of that base's builds.
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
# Diary rendering: one section per base version, no sub-version detail
# ===========================================================================

MAX_MERGED_PER_GROUP = 20

_NOTE_HEADING_RE = re.compile(r'^###\s+(.+?)\s*$')
_NOTE_BULLET_RE = re.compile(r'^[-*]\s+(.+?)\s*$')
_BASE_OF_RE = re.compile(r'^(\d+\.\d+\.\d+)\(')


def base_of_title(title):
    """Base version behind a display title, or None for pre-scheme tags."""
    match = _BASE_OF_RE.match(title or '')
    return match.group(1) if match else None


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
            lines.append(f'- … 另有 {dropped} 项同组改动已合并')
        lines.append('')
    return '\n'.join(lines).strip()


def group_entries(entries):
    """Fold ascending entries into base-version groups.

    [entries] is `[{'tag', 'title', 'date', 'notes'}]`, oldest first. Tags from
    before the version scheme have no base: they join the preceding group, or
    (when they come first) the earliest known group.
    """
    groups = []
    legacy = []
    for entry in entries:
        base = base_of_title(entry['title'])
        if base is None:
            if groups:
                groups[-1]['entries'].append(entry)
            else:
                legacy.append(entry)
            continue
        if groups and groups[-1]['base'] == base:
            groups[-1]['entries'].append(entry)
        else:
            groups.append({'base': base, 'entries': [entry]})
    if legacy:
        if groups:
            groups[0]['entries'] = legacy + groups[0]['entries']
        else:
            groups.append({'base': '', 'entries': legacy})
    return groups


def group_body(root, group):
    """Hand-written base summary if archived, else merged build notes."""
    base = group['base']
    if base:
        written = _demote_headings(archived_notes(root, base))
        if written:
            return written
    return merge_notes([entry['notes'] for entry in group['entries']
                        if entry['notes'] and entry['notes'] != EMPTY_NOTES])


def render_diary(groups, bodies):
    """Render the diary markdown; [bodies] parallels [groups]."""
    lines = ['# 更新日记', '']
    for group, body in zip(groups, bodies):
        entries = group['entries']
        first = entries[0]['date']
        last = entries[-1]['date']
        title = group['base'] or entries[-1]['tag']
        header = f'## {title} · {first}' if first == last \
            else f'## {title} · {first} ~ {last}'
        lines.extend([header, '', body or EMPTY_NOTES, ''])
    return '\n'.join(lines).strip() + '\n'


def render_changelog(root, current_tag='', current_date='',
                     current_run_number=0):
    """Collect entries from git and render the base-version diary."""
    tags = build_tags(root)
    bases = tag_bases(root, tags)
    entries = []
    for number, tag in tags:
        entries.append({
            'tag': tag,
            'title': tag_title(root, number, tag, bases) or tag,
            'date': tag_date(root, tag),
            'notes': tag_notes(root, number, tag),
        })

    # CI runs before the tag exists: append the in-flight build from HEAD.
    match = TAG_RE.match(current_tag)
    if match and not any(entry['tag'] == current_tag for entry in entries):
        body = hand_written_notes(root, current_tag)
        if not body:
            previous = _git(root, 'describe', '--tags', '--abbrev=0',
                            '--match', 'build-*').strip()
            body_lines = []
            for title, items in build_sections(
                    commit_entries(root, previous, limit=60)):
                body_lines.append(f'### {title}')
                body_lines.extend(f'- {item}' for item in items[:12])
                body_lines.append('')
            body = '\n'.join(body_lines).strip()
        if body:
            entries.append({
                'tag': current_tag,
                'title': head_title(root, current_run_number, bases)
                or current_tag,
                'date': current_date,
                'notes': body,
            })

    groups = group_entries(entries)
    bodies = [group_body(root, group) for group in groups]
    return render_diary(groups, bodies)


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
        groups = len(re.findall(r'\n## ', diary))
        print(f'Update diary: {groups} base version(s).', file=sys.stderr)
    else:
        print(diary, end='')


if __name__ == '__main__':
    main()

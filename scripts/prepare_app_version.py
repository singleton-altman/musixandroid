"""Derive the APK/UI version from the stable GitHub workflow run number.

`GITHUB_RUN_NUMBER` restarts at 1 in the new repository, so it is first shifted
by `RUN_NUMBER_EPOCH` into the global build number (see
scripts/version_scheme.py). The display sequence restarts at 001 whenever the
base version in `pubspec.yaml` changes; the Android versionCode always stays the
build number so every build is an acceptable upgrade.
"""

import argparse
import os
from pathlib import Path
import subprocess

from version_scheme import (
    SEQUENCE_RESET_TAG,
    display_sequence,
    effective_build_number,
    parse_base,
    parse_offset,
)


def _git_tags(root):
    """(build_number, base_version) for every tag that has a pubspec."""
    result = subprocess.run(
        ['git', 'tag', '--list', 'build-*'],
        cwd=str(root),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    tags = []
    for line in result.stdout.splitlines():
        tag = line.strip()
        if not tag.startswith('build-'):
            continue
        try:
            number = int(tag[len('build-'):])
        except ValueError:
            continue
        pubspec = subprocess.run(
            ['git', 'show', f'{tag}:pubspec.yaml'],
            cwd=str(root), capture_output=True, text=True,
        )
        base = parse_base(pubspec.stdout) if pubspec.returncode == 0 else None
        if base:
            tags.append((number, base))
    return tags


def build_version(pubspec, properties, run_number, tag_bases=None):
    base = parse_base(pubspec)
    offset = parse_offset(properties)
    if base is None:
        raise ValueError('Missing or invalid app version configuration.')
    if offset is None and run_number < SEQUENCE_RESET_TAG:
        raise ValueError('Missing or invalid app version configuration.')

    sequence = display_sequence(run_number, base, tag_bases or [], offset)
    if sequence is None or sequence < 1 or run_number > 2100000000:
        raise ValueError('Build number is outside the Android version range '
                         'or predates the version baseline.')
    return {
        'APP_BUILD_NAME': base,
        # versionCode must never go backwards, so it stays the run number.
        'APP_BUILD_NUMBER': str(run_number),
        'APP_DISPLAY_VERSION': f'{base}({sequence:03d})',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-number', required=True, type=int)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    build_number = effective_build_number(args.run_number)
    values = build_version(
        (root / 'pubspec.yaml').read_text(encoding='utf-8'),
        (root / 'android/version.properties').read_text(encoding='utf-8'),
        build_number,
        tag_bases=_git_tags(root),
    )
    # Tags and release names must use the shifted number, never the raw run
    # number, or they would overwrite the old builds named build-1…build-73.
    values['APP_BUILD_TAG'] = f'build-{build_number}'
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
            output.write(''.join(f'{key}={value}\n' for key, value in values.items()))
    print(f'App version: {values["APP_DISPLAY_VERSION"]}; '
          f'Android versionCode: {build_number} '
          f'(workflow run {args.run_number})')


if __name__ == '__main__':
    main()

"""Shared version scheme for CI and the changelog builder.

Two numbers are involved and they must never be confused:

- **Android versionCode** — strictly monotonic across the whole app history, so
  Android always accepts the next build as an upgrade. It is the workflow run
  number (see `.github/workflows/android-apk.yml`).
- **Display sequence** — the `(NNN)` in `0.8.12(001)`. It restarts at 001 every
  time the base version in `pubspec.yaml` changes, because humans read it as
  "the Nth build of this release".

Builds up to `SEQUENCE_RESET_TAG` used `run_number - versionCodeOffset` as the
display sequence; afterwards the sequence is counted per base version.
"""

import re

# First build that uses per-base-version sequencing.
SEQUENCE_RESET_TAG = 69

VERSION_RE = re.compile(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', re.MULTILINE)
OFFSET_RE = re.compile(r'^versionCodeOffset=(\d+)\s*$', re.MULTILINE)


def parse_base(pubspec):
    match = VERSION_RE.search(pubspec)
    return match.group(1) if match else None


def parse_offset(properties):
    match = OFFSET_RE.search(properties)
    return int(match.group(1)) if match else None


def display_sequence(number, base, tag_bases, offset):
    """Sequence shown in the version string for build [number].

    [tag_bases] is a list of `(build_number, base_version)` pairs for builds
    that already carry a tag; it is how a build knows it is the 3rd build of
    0.8.12 even though CI runs are numbered globally.
    """
    if number < SEQUENCE_RESET_TAG:
        if offset is None:
            return None
        sequence = number - offset
        return sequence if sequence >= 1 else None
    earlier = [
        tag_number for tag_number, tag_base in tag_bases
        if tag_base == base and tag_number < number
    ]
    return len(earlier) + 1

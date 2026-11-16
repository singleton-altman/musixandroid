import unittest

from prepare_app_version import build_version
from version_scheme import RUN_NUMBER_EPOCH, effective_build_number

PUBSPEC = 'version: 0.8.11+1\n'
PROPERTIES = 'versionCodeOffset=42\n'

# Tags that already exist when the next build runs.
HISTORY = [
    (63, '0.8.11'), (64, '0.8.11'), (65, '0.8.11'), (66, '0.8.11'),
    (67, '0.8.11'), (68, '0.8.11'),
]


class LegacySequenceTests(unittest.TestCase):
    """Builds before the reset tag keep the run-number offset scheme."""

    def version(self, run):
        return build_version('version: 0.7.8+1\n', PROPERTIES, run)

    def test_first_new_release_starts_at_one(self):
        version = self.version(43)
        self.assertEqual(version['APP_DISPLAY_VERSION'], '0.7.8(001)')
        self.assertEqual(version['APP_BUILD_NUMBER'], '43')

    def test_next_build_and_retry(self):
        self.assertEqual(self.version(44)['APP_DISPLAY_VERSION'], '0.7.8(002)')
        self.assertEqual(self.version(44), self.version(44))

    def test_padding_and_large_sequences(self):
        self.assertEqual(self.version(52)['APP_DISPLAY_VERSION'], '0.7.8(010)')

    def test_sequence_pads_beyond_three_digits(self):
        history = [(n, '0.8.12') for n in range(69, 69 + 1000)]
        self.assertEqual(
            build_version('version: 0.8.12+1\n', PROPERTIES, 1069,
                          tag_bases=history)['APP_DISPLAY_VERSION'],
            '0.8.12(1001)')

    def test_rejects_stale_or_invalid_android_build_numbers(self):
        for run in [0, 42, 2100000001]:
            with self.subTest(run=run), self.assertRaises(ValueError):
                self.version(run)

    def test_reads_major_version_from_pubspec(self):
        self.assertEqual(build_version('version: 0.7.9+1', PROPERTIES, 45)
                         ['APP_DISPLAY_VERSION'], '0.7.9(003)')


class PerBaseVersionTests(unittest.TestCase):
    """From the reset tag on, the sequence counts builds of the same base."""

    def test_new_base_version_restarts_at_one(self):
        version = build_version('version: 0.8.12+1\n', PROPERTIES, 69,
                                tag_bases=HISTORY)
        self.assertEqual(version['APP_DISPLAY_VERSION'], '0.8.12(001)')
        # versionCode is the run number even though the sequence restarted.
        self.assertEqual(version['APP_BUILD_NUMBER'], '69')

    def test_sequence_counts_only_the_same_base(self):
        history = HISTORY + [(69, '0.8.12'), (70, '0.8.12')]
        self.assertEqual(
            build_version('version: 0.8.12+1\n', PROPERTIES, 71,
                          tag_bases=history)['APP_DISPLAY_VERSION'],
            '0.8.12(003)')

    def test_next_patch_version_starts_over(self):
        history = HISTORY + [(69, '0.8.12'), (70, '0.8.12')]
        self.assertEqual(
            build_version('version: 0.8.13+1\n', PROPERTIES, 71,
                          tag_bases=history)['APP_DISPLAY_VERSION'],
            '0.8.13(001)')

    def test_version_code_never_goes_backwards(self):
        codes = []
        history = list(HISTORY)
        for run, base in [(69, '0.8.12'), (70, '0.8.12'), (71, '0.8.13')]:
            version = build_version(f'version: {base}+1\n', PROPERTIES, run,
                                    tag_bases=history)
            codes.append(int(version['APP_BUILD_NUMBER']))
            history.append((run, base))
        self.assertEqual(codes, sorted(codes))
        self.assertEqual(len(set(codes)), len(codes))


class RepositoryMoveTests(unittest.TestCase):
    """The move to a new repository restarts GITHUB_RUN_NUMBER at 1."""

    def test_first_run_of_new_home_continues_the_old_counter(self):
        self.assertEqual(effective_build_number(1), RUN_NUMBER_EPOCH + 1)

    def test_build_number_stays_monotonic_across_the_move(self):
        last_old_build = 73
        self.assertGreater(effective_build_number(1), last_old_build)

    def test_moved_build_keeps_counting_the_same_base_sequence(self):
        history = [(n, '0.8.12') for n in range(69, 74)]
        version = build_version(
            'version: 0.8.12+1\n', PROPERTIES, effective_build_number(1),
            tag_bases=history)
        self.assertEqual(version['APP_DISPLAY_VERSION'], '0.8.12(006)')
        self.assertEqual(version['APP_BUILD_NUMBER'], '74')


if __name__ == '__main__':
    unittest.main()
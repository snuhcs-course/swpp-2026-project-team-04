import unittest

import numpy as np

from pushup_span_mlp import align_order, vector
from score_pushup_nine import evaluate
from score_pushup_span import binary_counts, from_stream_score


class BinaryEvaluationTest(unittest.TestCase):
    def test_missed_invalid_does_not_count_as_an_explicit_rejection(self):
        labels = ['normal', 'normal', 'kneesDown', 'armsStraight', 'bellyDown']
        guesses = ['normal', 'no_event', 'normal', 'no_event', 'insufficientDepth']
        result = binary_counts(labels, guesses)
        self.assertEqual(result['normal_recall'], .5)
        self.assertEqual(result['invalid_recall'], 1 / 3)
        self.assertAlmostEqual(result['invalid_no_point'], 2 / 3)
        self.assertAlmostEqual(result['balanced_accuracy'], (.5 + 1 / 3) / 2)

    def test_timed_and_per_cut_binary_tables_agree_and_charge_extras(self):
        labels = ['normal', 'kneesDown', 'incompleteExtension']
        units = [dict(unit_id=str(i), start=i*10, end=i*10+5, label=v)
                 for i, v in enumerate(labels)]
        cases = {'x': dict(units=units, fps=10, split='holdout')}
        events = {'x': {'events': {'a': [[3, 'normal'], [13, 'armsStraight'], [40, 'normal']]}}}
        stream = from_stream_score(evaluate(cases, events, 'a', {'holdout'}))
        manual = binary_counts(labels, ['normal', 'armsStraight', 'no_event'])
        self.assertEqual(stream['counts'], manual['counts'])
        self.assertEqual(stream['extra_normal'], 1)

    def test_empty_pose_keeps_feature_width_and_native_alignment_marks_misses(self):
        xy = np.full((2, 13, 2), np.nan)
        features = vector(np.array([0, 60]), xy)
        self.assertTrue(np.isfinite(features).all())
        self.assertGreater(len(features), 100)
        self.assertEqual(list(align_order(['kneesDown','normal'], ['normal'])),
                         [(0,'no_event'), (1,'normal')])


if __name__ == '__main__':
    unittest.main()

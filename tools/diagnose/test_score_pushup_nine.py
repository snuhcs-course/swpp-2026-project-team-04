import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace

from score_pushup_nine import evaluate, fixture_gates, match, read_inputs


def unit(unit_id, start, end, label="normal", **kwargs):
    return dict(unit_id=unit_id, start=start, end=end, label=label, **kwargs)


class EventScoringTest(unittest.TestCase):
    def test_overlap_uses_distinct_events_before_minimizing_latency(self):
        units = [unit("a", 0, 12), unit("b", 9, 18)]
        events = [[3, "kneesDown"], [10, "normal"]]
        self.assertEqual(match(units, events, 10), ({0: 0, 1: 1}, {0, 1}))
        units[0]["label"], units[1]["label"] = None, "kneesDown"
        self.assertEqual(match(units, events, 10)[0], {0: 0, 1: 1})

    def test_grace_is_bounded_and_match_prefers_nearest_return(self):
        units = [unit("a", 1, 10)]
        self.assertEqual(match(units, [[1, "normal"], [11, "armsStraight"]], 10)[0], {0: 1})
        self.assertEqual(match(units, [[12, "normal"]], 10)[0], {})

    def test_unknown_duplicates_misses_extras_and_unsupported_classes(self):
        units = [unit("a", 0, 10), unit("dup", 0, 10, confirmed_duplicate_of="a"),
                 unit("b", 20, 30, "kneesDown"), unit("c", 40, 50, None)]
        refs = {"s": dict(split="holdout", fps=10, units=units)}
        outputs = {"s": {"events": {"a": [[9, "normal"], [48, "normal"], [60, "normal"]]}}}
        s = evaluate(refs, outputs, "a", {"holdout"})
        self.assertEqual((s["labelled"], s["correct"], s["misses"], s["extras"]), (2, 1, 1, 1))
        self.assertEqual((s["duplicates_excluded"], s["events_paired_to_unlabelled"]), (1, 1))
        self.assertAlmostEqual(s["macro_f1"], 1/3)
        self.assertAlmostEqual(s["micro_f1"], 1/2)
        self.assertIsNone(s["classes"]["phoneMoved"]["f1"])
        self.assertEqual(s["classes"]["kneesDown"]["f1"], 0)

    def test_shared_group_and_missing_replay_cannot_enter_selection(self):
        with TemporaryDirectory() as temp:
            units, events = Path(temp) / "units", Path(temp) / "events"
            units.write_text("\n".join(json.dumps({"source_id": sid, "group_id": "same",
                "split": split}) for sid, split in [("d", "development"), ("h", "holdout")]))
            args = SimpleNamespace(units=units, events=events, stage="select")
            events.write_text(json.dumps({"source_id": "d", "events": {"baseline": []}}))
            with self.assertRaisesRegex(ValueError, "Source IDs differ"):
                read_inputs(args)
            with events.open("a") as f:
                f.write("\n" + json.dumps({"source_id": "h", "events": {"baseline": []}}))
            with self.assertRaisesRegex(ValueError, "shared across splits"):
                read_inputs(args)

    def test_higher_video_score_cannot_hide_a_new_native_false_count(self):
        with TemporaryDirectory() as temp:
            p = Path(temp) / "native.jsonl"
            r = dict(source_id="x", labelled=["kneesDown"], expected=None,
                     events={"baseline": [[10, "kneesDown"]], "other": [[10, "normal"]]},
                     safety={"baseline": {}, "other": {"new_critical_false_accept_indices": [0]}},
                     tally={"baseline": {"incorrectNotCounted": 1}, "other": {"incorrectNotCounted": 0}})
            p.write_text("\n".join(json.dumps(dict(suite=s, **r))
                for s in ("test/ai_eval/cases", "test/fixtures/pushup_cases")))
            result = fixture_gates(p, ["baseline", "other"])
            self.assertFalse(result["baseline"]["regressions"])
            problems = result["other"]["regressions"]
            self.assertIn("additional_counted_incorrect_rep", problems[0]["reasons"])
            self.assertIn("historical_changed_without_better_agreement", problems[1]["reasons"])


if __name__ == "__main__":
    unittest.main()

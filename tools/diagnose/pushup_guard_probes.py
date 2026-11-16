"""Synthetic camera streams isolating the evidence needed by elevated-view calibration."""

import json
import math

NEGATIVES = ("unobserved_descent", "unobserved_top", "extended_only", "one_arm_raised")


def pose(depth, angle=178, *, hips=False, shoulders=True, arms=True, drop=None, raised=False):
    points = [None] * 33
    points[0] = [500, 300 + depth * 200, .95]
    for side, direction in enumerate((-1, 1)):
        x = 500 + direction * 100
        y = 400 + (drop if drop is not None else .6 * depth) * 200
        if hips:
            points[23 + side] = [500 + direction * 90, 470, .95]
        if not shoulders:
            continue
        points[11 + side] = [x, y, .95]
        if arms:
            scale = -.6 if raised and side == 0 else 1
            radians = math.radians(angle)
            points[13 + side] = [x, y + scale * 100, .95]
            points[15 + side] = [
                x - direction * math.sin(radians) * 100,
                y + scale * 100 * (1 - math.cos(radians)), .95,
            ]
    return points


def write_inputs(path):
    rows = []
    for case in (*NEGATIVES, "valid_elevated", "ordinary_full", "ordinary_hidden_return"):
        ordinary = case.startswith("ordinary")
        top = pose(0, hips=True, raised=case == "one_arm_raised")
        bottom = pose(
            1.5 if ordinary else .85, 178 if case == "extended_only" else 135,
            drop=.9 if ordinary else .52, shoulders=case != "unobserved_descent",
        )
        back = pose(0, arms=case not in {"unobserved_top", "ordinary_hidden_return"})
        rows.append(json.dumps({
            "source_id": case, "width": 1000, "height": 1000,
            "frames": [[i, i * 70, pts] for i, pts in enumerate([top] * 7 + [bottom] * 6 + [back] * 6)],
        }))
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def write_report(events_file, out):
    with events_file.open(encoding="utf-8") as stream:
        rows = {r["source_id"]: r["events"] for line in stream if (r := json.loads(line))}
    report = {}
    for preset in rows["ordinary_full"]:
        events = {source: values[preset] for source, values in rows.items()}
        counts = {s: sum(label == "normal" for _, label in reps) for s, reps in events.items()}
        report[preset] = {
            "unsafe": [case for case in NEGATIVES if counts[case]],
            "ordinary_control_ok": counts["ordinary_full"] == counts["ordinary_hidden_return"] == 1,
            "visible_elevated_count": counts["valid_elevated"],
            "events": events,
        }
    with out.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, ensure_ascii=False, indent=2)
        stream.write("\n")

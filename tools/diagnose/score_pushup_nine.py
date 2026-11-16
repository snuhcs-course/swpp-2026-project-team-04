"""Select on development groups, then score a locked candidate on the held-out groups.

Inputs are the recut interval manifest and time-stamped outputs from the Dart
streaming judge. Only the scorer sees the reference intervals and labels.
"""
import argparse
import csv
import hashlib
import json
import random
from collections import Counter
from pathlib import Path

LABELS = (
    "normal", "insufficientDepth", "incompleteExtension", "shouldersNotLevel",
    "kneesDown", "armsStraight", "bellyDown", "notFloorPushUp", "phoneMoved",
)
MISS = "no_event"
EXTRA = "unmatched_event"
UNKNOWN = "unlabelled"


def read_sources(path):
    result = {}
    with path.open(encoding="utf-8-sig") as stream:
        for line in stream:
            row = json.loads(line)
            key = row["source_id"]
            if key in result:
                raise ValueError(f"Repeated original {key}")
            result[key] = row
    return result


def match(units, events, fps):
    """Match in temporal order, maximizing pairs, then minimizing return-time error.

    Each source event and reference can be used once. Allow 200 ms after a clip
    for filter lag. Neither a class nor its labelled/unlabelled status is used.
    """
    if any(b[0] < a[0] for a, b in zip(events, events[1:])):
        raise ValueError("Judge events out of order")
    grace = round(0.2 * fps)
    n, m = len(units), len(events)
    scores = [[(0, 0)] * (m + 1) for _ in range(n + 1)]
    choices = [[0] * (m + 1) for _ in range(n + 1)]
    for i, unit in enumerate(units, 1):
        start, end = unit["start"], unit["end"]
        if start >= end:
            raise ValueError(f"Empty interval: {unit['unit_id']}")
        target = unit.get("return_frame")
        if target is None or not start <= target < end:
            target = end - 1
        for j, event in enumerate(events, 1):
            best, step = scores[i - 1][j], 1
            if scores[i][j - 1] > best:
                best, step = scores[i][j - 1], 2
            frame = event[0]
            if start <= frame < end + grace:
                count, neg_error = scores[i - 1][j - 1]
                paired = (count + 1, neg_error - abs(frame - target))
                if paired > best:
                    best, step = paired, 3
            scores[i][j], choices[i][j] = best, step
    pairs, used = {}, set()
    i, j = n, m
    while i and j:
        step = choices[i][j]
        if step == 3:
            pairs[i - 1] = j - 1
            used.add(j - 1)
        if step in (1, 3):
            i -= 1
        if step in (2, 3):
            j -= 1
    return pairs, used


def evaluate(manifest, outputs, candidate, splits, *, raw=False, writer=None):
    matrix = Counter()
    duplicate_count = unknown_count = unknown_matched = silent_sources = 0
    for key, source in manifest.items():
        if source["split"] not in splits:
            continue
        units = []
        for u in source["units"]:
            if not raw and u.get("confirmed_duplicate_of"):
                duplicate_count += 1
            else:
                units.append(u)
        units.sort(key=lambda u: (u["end"], u["start"], u["unit_id"]))
        events = outputs[key]["events"][candidate]
        silent_sources += int(not events)
        if any(label not in LABELS for _, label in events):
            raise ValueError(f"Unknown judge output for {key}")
        pairs, used = match(units, events, source["fps"])
        for i, unit in enumerate(units):
            event = events[pairs[i]] if i in pairs else (None, MISS)
            actual = unit["label"] or UNKNOWN
            if actual == UNKNOWN:
                unknown_count += 1
                unknown_matched += int(i in pairs)
            elif actual in LABELS:
                matrix[actual, event[1]] += 1
            else:
                raise ValueError(f"Unknown label: {actual}")
            if writer:
                writer.writerow((key, source["split"], unit["unit_id"],
                                 unit["start"], unit["end"], actual, *event,
                                 unit.get("confirmed_duplicate_of") or ""))
        for j, (frame, prediction) in enumerate(events):
            if j not in used:
                matrix[EXTRA, prediction] += 1
                if writer:
                    writer.writerow((key, source["split"], "", "", "", EXTRA, frame, prediction, ""))
    per_class = {}
    for label in LABELS:
        support = sum(value for (truth, _), value in matrix.items() if truth == label)
        predicted = sum(value for (_, pred), value in matrix.items() if pred == label)
        true = matrix[label, label]
        per_class[label] = dict(
            support=support, predicted=predicted, correct=true,
            precision=true / predicted if predicted else None,
            recall=true / support if support else None,
            f1=2 * true / (support + predicted) if support else None,
        )
    f1s = [v["f1"] for v in per_class.values() if v["support"]]
    total = sum(v["support"] for v in per_class.values())
    correct = sum(v["correct"] for v in per_class.values())
    misses = sum(matrix[label, MISS] for label in LABELS)
    extras = sum(matrix[EXTRA, label] for label in LABELS)
    invalids = total - per_class["normal"]["support"]
    invalid_counted = sum(matrix[label, "normal"] for label in LABELS if label != "normal")
    return dict(
        labelled=total, correct=correct, misses=misses, extras=extras,
        matched=total - misses, event_coverage=(total - misses) / total if total else None,
        agreement_on_matched=correct / (total - misses) if total > misses else None,
        sources_without_any_event=silent_sources,
        valid_reps_counted=per_class["normal"]["correct"],
        invalid_reps_counted=invalid_counted,
        invalid_count_rate=invalid_counted / invalids if invalids else None,
        unlabelled=unknown_count, events_paired_to_unlabelled=unknown_matched,
        duplicates_excluded=duplicate_count, accuracy=correct / total if total else None,
        macro_f1=sum(f1s) / len(f1s) if f1s else None,
        micro_f1=2 * correct / (2 * total - misses + extras) if total else None,
        classes=per_class, confusion={label: {pred: matrix[label, pred]
            for pred in (*LABELS, MISS)} for label in (*LABELS, EXTRA)},
    )


def read_inputs(args):
    manifest = read_sources(args.units)
    outputs = read_sources(args.events)
    if not manifest or manifest.keys() != outputs.keys():
        raise ValueError("Source IDs differ or data are empty")
    seen = {split: {s["group_id"] for s in manifest.values() if s["split"] == split}
            for split in ("development", "holdout")}
    if any(s["split"] not in seen for s in manifest.values()):
        raise ValueError("Unexpected split")
    if seen["development"] & seen["holdout"] or (
        args.stage != "external" and not all(seen.values())
    ):
        raise ValueError("Groups missing or shared across splits")
    pools = [set(r["events"]) for r in outputs.values()]
    if not pools[0] or any(s != pools[0] for s in pools):
        raise ValueError("Different candidates for different sources")
    return manifest, outputs, pools[0]


def save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False, allow_nan=False) + "\n",
                    encoding="utf-8")


def file_digest(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def paired_group_interval(manifest, outputs, selected, samples=1000):
    """Paired uncertainty in the change in macro F1, resampling holdout groups."""
    groups = {}
    for key, row in manifest.items():
        if row["split"] == "holdout":
            groups.setdefault(row["group_id"], {})[key] = row
    tables = []
    for group in sorted(groups):
        columns = []
        for candidate in ("baseline", selected):
            classes = evaluate(groups[group], outputs, candidate, {"holdout"})["classes"]
            columns.append([(c["support"], c["predicted"], c["correct"])
                            for c in classes.values()])
        tables.append(columns)
    represented = [i for i in range(len(LABELS)) if any(t[0][i][0] for t in tables)]
    rng = random.Random(20261116)
    deltas = []
    for _ in range(samples):
        drawn = rng.choices(tables, k=len(tables))
        pair = []
        for c in (0, 1):
            scores = []
            for i in represented:
                n, predicted, correct = map(sum, zip(*(g[c][i] for g in drawn)))
                if n:
                    scores.append(2 * correct / (n + predicted))
            if len(scores) == len(represented):
                pair.append(sum(scores) / len(scores))
        if len(pair) == 2:
            deltas.append(pair[1] - pair[0])
    deltas.sort()
    return dict(group_count=len(groups), draws=samples, full_support_draws=len(deltas),
                lower=deltas[round(0.025 * (len(deltas) - 1))] if deltas else None,
                upper=deltas[round(0.975 * (len(deltas) - 1))] if deltas else None)


def edit_distance(a, b):
    row = list(range(len(b) + 1))
    for i, left in enumerate(a, 1):
        next_row = [i]
        for j, right in enumerate(b, 1):
            next_row.append(min(row[j] + 1, next_row[-1] + 1,
                                row[j - 1] + (left != right)))
        row = next_row
    return row[-1]


def historical_distance(row, predicted):
    if row["labelled"] is not None:
        truth = ["normal" if label == "valid" else label for label in row["labelled"]]
        return edit_distance(truth, predicted)
    if row["expected"] is None:
        return None
    expected = Counter(row["expected"]["rejected"])
    expected["normal"] = row["expected"]["valid"]
    actual = Counter(predicted)
    return sum(abs(expected[k] - actual[k]) for k in expected.keys() | actual.keys())


def fixture_gates(path, candidates):
    with path.open(encoding="utf-8-sig") as f:
        rows = [json.loads(line) for line in f]
    suites = Counter(r["suite"] for r in rows)
    if not suites["test/ai_eval/cases"] or not suites["test/fixtures/pushup_cases"]:
        raise ValueError("Both native regression suites are required")
    details = {}
    for c in candidates:
        problems, total = [], Counter()
        for row in rows:
            safety = row["safety"][c]
            reasons = [k for k, v in safety.items()
                       if (bool(v) if isinstance(v, list) else v > 0)]
            if row["suite"] == "test/fixtures/pushup_cases":
                old = [l for _, l in row["events"]["baseline"]]
                new = [l for _, l in row["events"][c]]
                if old != new:
                    before = historical_distance(row, old)
                    after = historical_distance(row, new)
                    if before is not None and after >= before:
                        reasons.append("historical_changed_without_better_agreement")
            else:
                tally = row["tally"][c]
                total.update(tally)
                if tally["incorrectNotCounted"] < row["tally"]["baseline"]["incorrectNotCounted"]:
                    reasons.append("additional_counted_incorrect_rep")
            if reasons:
                problems.append({"source": row["source_id"], "reasons": reasons})
        details[c] = {"regressions": problems, "frozen_total": dict(total)}
    return details


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["select", "report", "external"])
    for name in ("units", "events", "lock"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, help="Native regression output from the Dart runner")
    parser.add_argument("--probes", type=Path, help="Named visibility and straight-arm safety cases")
    parser.add_argument("--wrist-base", default="small30_elev60_knees_tilt15_guarded")
    parser.add_argument("--refit-events", type=Path, help="All-development fit for learned candidates")
    parser.add_argument("--shipping", type=Path, help="Events from the actual shipping defaults")
    parser.add_argument("--out-dir", type=Path)
    args = parser.parse_args()
    manifest, outputs, available = read_inputs(args)
    if args.stage == "select":
        if not args.fixtures or not args.probes or "baseline" not in available:
            parser.error("The native fixture results, visibility probes and baseline are required")
        candidates = sorted(available - {"app_default"})
        gates = fixture_gates(args.fixtures, candidates)
        probes = json.loads(args.probes.read_text(encoding="utf8"))
        for c in candidates:
            base = args.wrist_base if c.startswith("tree_wrist_") else c
            if c.startswith(("tree3_", "tree5_")):
                base = c.split("_", 1)[1]
            control = probes[base]
            gates[c]["visibility_probe_failures"] = control["unsafe"]
            if control["unsafe"] or not control["ordinary_control_ok"]:
                gates[c]["regressions"].append(dict(source="visibility probes",
                    reasons=control["unsafe"] + ([] if control["ordinary_control_ok"] else ["ordinary_rep_missed"])))
        scores = {c: evaluate(manifest, outputs, c, {"development"}) for c in candidates}
        # Prespecified Occam tie-break: a compound reach variant additionally
        # runs two projection rules; neither is needed for its simpler twin.
        def tie_break(c):
            if c == "baseline":
                return 0
            if c.startswith("tree") or "reach" in c or "projected" in c:
                return 2
            return 1

        # No test labels appear in this selection.
        def order(c):
            return (-scores[c]["macro_f1"], -scores[c]["micro_f1"], tie_break(c), c)
        ranked = sorted((c for c in candidates if not gates[c]["regressions"]), key=order)
        if "baseline" not in ranked:
            raise ValueError("Baseline fixture comparison failed")
        selected = ranked[0]
        save(args.lock, dict(winner=selected, eligible=ranked, rank_metric="macro_f1",
                             development=scores, fixture_gates=gates,
                             units_sha256=file_digest(args.units),
                             events_sha256=file_digest(args.events),
                             fixtures_sha256=file_digest(args.fixtures), probes_sha256=file_digest(args.probes)))
        for c in sorted(candidates, key=order):
            s = scores[c]
            print(f"{c:28s} {s['macro_f1']:.5f} micro {s['micro_f1']:.5f} "
                  f"correct {s['correct']}/{s['labelled']} missed {s['misses']} "
                  f"extras {s['extras']} eligible={c in ranked}")
        print("Selected:", selected)
        return
    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    winner = lock["winner"]
    if not args.out_dir or winner not in lock["eligible"]:
        parser.error("Missing locked selection or output directory")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    if args.stage == "external":
        if any(s["split"] != "holdout" for s in manifest.values()):
            parser.error("External replay must use held-out originals only")
        results = {c: evaluate(manifest, outputs, c, {"holdout"})
                   for c in dict.fromkeys(("baseline", winner))}
        save(args.out_dir / "native-scores.json", dict(winner=winner, holdout=results))
        for c, s in results.items():
            print(f"{c}: native macro F1 {s['macro_f1']:.5f}, correct {s['correct']}/{s['labelled']}")
        return
    if (file_digest(args.units) != lock["units_sha256"] or
            file_digest(args.events) != lock["events_sha256"]):
        raise ValueError("The report inputs differ from those used to lock the winner")
    fitted = outputs
    if winner.startswith("tree"):
        if args.refit_events is None:
            parser.error("Supply full-data fitted-model events for shipping checks")
        fitted = read_sources(args.refit_events)
        if fitted.keys() != outputs.keys():
            raise ValueError("Refit source mismatch")
        if any(fitted[k]["events"][winner] != outputs[k]["events"][winner]
               for k in manifest if manifest[k]["split"] == "holdout"):
            raise ValueError("Held-out predictions differ between the refit and assessment")
    if args.shipping:
        real = read_sources(args.shipping)
        if real.keys() != outputs.keys() or any(
            real[k]["events"]["app_default"] != fitted[k]["events"][winner] for k in manifest
        ):
            raise ValueError("Shipping judge differs from selected full-data fit")
    report = {}
    for which, splits in (("holdout", {"holdout"}), ("all", {"development", "holdout"})):
        report[which] = {}
        for c in dict.fromkeys(("baseline", winner)):
            report[which][c] = evaluate(manifest, fitted, c, splits)
    report["shipping_event_parity_verified"] = args.shipping is not None
    report["holdout_macro_f1_delta_95_interval"] = paired_group_interval(manifest, fitted, winner)
    domains = {}
    for key, row in manifest.items():
        if row["split"] == "holdout":
            domains.setdefault(row["domain"], {})[key] = row
    report["holdout_by_source_domain"] = {}
    for domain, subset in sorted(domains.items()):
        score = evaluate(subset, fitted, winner, {"holdout"})
        report["holdout_by_source_domain"][domain] = {
            "sources": len(subset), "classes_with_support": sum(
                c["support"] > 0 for c in score["classes"].values()),
            **{k: score[k] for k in ("labelled", "correct", "misses", "extras", "macro_f1")},
        }
    for filename, raw in (("selected-events.csv", False), ("all-recut-rows.csv", True)):
        with (args.out_dir / filename).open("w", encoding="utf-8-sig", newline="") as f:
            w = csv.writer(f)
            w.writerow(("source_id", "split", "unit_id", "start", "end", "reference",
                        "event_frame", "prediction", "confirmed_duplicate_of"))
            rows = evaluate(manifest, fitted, winner, {"development", "holdout"}, raw=raw, writer=w)
            if raw:
                report["raw_all_including_duplicate_units"] = rows
    save(args.out_dir / "scores.json", dict(winner=winner, **report))
    print("Selected:", winner)
    for c, s in report["holdout"].items():
        print(f"{c}: held-out macro F1 {s['macro_f1']:.5f}, micro F1 {s['micro_f1']:.5f}, "
              f"accuracy {s['correct']}/{s['labelled']}, missed {s['misses']}, extras {s['extras']}")


if __name__ == "__main__":
    main()


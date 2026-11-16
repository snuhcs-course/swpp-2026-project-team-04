"""Prepare and evaluate paired, presegmented pose-extractor/ML Kit experiments.

The reference labels are existing automatic proposals. This measures agreement
with those labels on fixed clips, with every detection failure in the denominator.
It does not measure automatic repetition detection or physical floor contact.

Predictions are JSONL records with ``key`` and ``points`` (33 entries containing
pixel x/y, optional ignored scores, or null). No source videos are modified.
"""

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import warnings

import numpy as np


SEED = 217
SELECTION_SEED = "gymrats-sapiens2-mlkit-paired-v1"
PHASES = (0.1, 0.3, 0.5, 0.7, 0.9)
LABELS = ("normal", "kneesDown")
JOINTS = (11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)
FRAME_FEATURE_COUNT = len(JOINTS) * 2 + 2 * (3 + 8 + 1)
LIMITATIONS = [
    "Existing automatic visual-review labels have no independent human verification.",
    "The source-group holdout was inspected in previous experiments and is reused.",
    "Intervals and five phase times are supplied to both pipelines; this is clip discrimination.",
    "Provider-group separation does not prove separation of every real participant.",
    "Every selected frame must have a prediction record; unprocessed frames block evaluation.",
    "Attempted detections with insufficient observed joints count as unknown, not correct.",
    "Model confidence scores are ignored because the estimators define them differently.",
]


def load_rows(path):
    with Path(path).open(encoding="utf-8-sig") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2,
                                    allow_nan=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def file_hash(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def rank(identifier):
    return hashlib.sha256(f"{SELECTION_SEED}|{identifier}".encode()).hexdigest()


def manifest_summary(units):
    summary = {}
    for split in ("development", "holdout"):
        selected = [unit for unit in units if unit["split"] == split]
        summary[split] = {
            "units": len(selected),
            "groups": len({unit["group_id"] for unit in selected}),
            "labels": dict(Counter(unit["label"] for unit in selected)),
            "full_cycle_labels": dict(Counter(unit["label"] for unit in selected
                                               if unit["full_cycle_eligible"])),
        }
    return summary


def check_manifest(manifest):
    frame_keys = [frame["key"] for frame in manifest["frames"]]
    if len(frame_keys) != len(set(frame_keys)):
        raise ValueError("Duplicate frame keys")
    identifiers = [unit["id"] for unit in manifest["units"]]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("Duplicate unit IDs")
    keys = set(frame_keys)
    groups = defaultdict(set)
    for unit in manifest["units"]:
        if unit["split"] not in ("development", "holdout") or unit["label"] not in LABELS:
            raise ValueError("Unexpected split or label")
        if len(unit["frame_keys"]) != len(PHASES):
            raise ValueError(f"Expected five phase frames for {unit['id']}")
        if not set(unit["frame_keys"]) <= keys:
            raise ValueError(f"Missing frame metadata for {unit['id']}")
        groups[unit["split"]].add(unit["group_id"])
    if groups["development"] & groups["holdout"]:
        raise ValueError("Development/holdout group leakage")


def pilot_units(units, development_groups, holdout_groups, maximum_per_group):
    selected = []
    for split, count in (("development", development_groups), ("holdout", holdout_groups)):
        by_group = defaultdict(list)
        for unit in units:
            if unit["split"] == split:
                by_group[unit["group_id"]].append(unit)
        chosen = []
        for position in range(min(count, len(by_group))):
            label = LABELS[position % len(LABELS)]
            candidates = [group for group, members in by_group.items()
                          if group not in chosen and any(u["label"] == label for u in members)]
            if not candidates:
                candidates = [group for group in by_group if group not in chosen]
            chosen.append(min(candidates, key=rank))
        for group in chosen:
            members = sorted(by_group[group], key=lambda unit: rank(unit["id"]))
            picked = []
            # Represent both classes within a mixed group whenever the cap permits.
            for label in LABELS:
                matching = [unit for unit in members if unit["label"] == label]
                if matching and len(picked) < maximum_per_group:
                    picked.append(matching[0])
            for unit in members:
                if len(picked) >= maximum_per_group:
                    break
                if unit not in picked:
                    picked.append(unit)
            selected.extend(picked)
    return sorted(selected, key=lambda unit: unit["id"])


def prepare(args):
    source = args.corpus / "replay.jsonl"
    frames, units = {}, []
    missing_intervals = []
    for row in load_rows(source):
        available = row["frames"]
        for unit in row["units"]:
            if unit.get("confirmed_duplicate_of") or unit["label"] not in LABELS:
                continue
            choices = [frame for frame in available if unit["start"] <= frame[0] < unit["end"]]
            if not choices:
                missing_intervals.append(unit["unit_id"])
                continue
            phase_keys = []
            for phase in PHASES:
                target = unit["start"] + phase * (unit["end"] - unit["start"] - 1)
                index, milliseconds, points = min(choices, key=lambda frame: (abs(frame[0] - target), frame[0]))
                key = f"{row['source_id']}__f{index:06d}"
                frames.setdefault(key, {
                    "key": key, "source_id": row["source_id"],
                    "source_path": row["source_path"], "source_sha256": row["source_sha256"],
                    "width": row["width"], "height": row["height"],
                    "index": index, "milliseconds": milliseconds, "mlkit": points,
                })
                phase_keys.append(key)
            units.append({
                "id": unit["unit_id"], "source_id": row["source_id"],
                "split": row["split"], "group_id": row["group_id"],
                "label": unit["label"], "frame_keys": phase_keys,
                "full_cycle_eligible": unit["full_cycle_eligible"],
                "label_confidence": unit["label_confidence"],
                "human_verified": unit["human_verified"],
                "start": unit["start"], "end": unit["end"],
            })
    if missing_intervals:
        raise ValueError(f"Intervals without any paired frame: {missing_intervals}")
    units.sort(key=lambda unit: unit["id"])
    manifest = {
        "schema": "gymrats-sapiens2-mlkit-paired-v1", "scope": "all canonical normal/knee intervals",
        "selection_seed": SELECTION_SEED, "phases": PHASES,
        "corpus": str(args.corpus), "replay_sha256": file_hash(source),
        "units_sha256": file_hash(args.corpus / "units.jsonl"),
        "limitations": LIMITATIONS, "summary": manifest_summary(units),
        "frames": [frames[key] for key in sorted(frames)], "units": units,
    }
    check_manifest(manifest)
    save_json(args.out / "manifest.json", manifest)
    selected = pilot_units(units, args.pilot_development_groups,
                           args.pilot_holdout_groups, args.pilot_max_units_per_group)
    keys = {key for unit in selected for key in unit["frame_keys"]}
    pilot = dict(manifest)
    pilot.update(scope="frozen group-sampled feasibility pilot", units=selected,
                 frames=[frame for frame in manifest["frames"] if frame["key"] in keys],
                 summary=manifest_summary(selected),
                 pilot_selection={"development_groups": args.pilot_development_groups,
                                  "holdout_groups": args.pilot_holdout_groups,
                                  "maximum_units_per_group": args.pilot_max_units_per_group,
                                  "method": "alternate class coverage, SHA256 group rank, both labels within mixed groups"})
    check_manifest(pilot)
    save_json(args.out / "pilot-manifest.json", pilot)
    print(json.dumps({"full": manifest["summary"], "full_frames": len(frames),
                      "pilot": pilot["summary"], "pilot_frames": len(pilot["frames"])}, indent=2))


def read_predictions(path):
    text = Path(path).read_text(encoding="utf-8-sig")
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = [json.loads(line) for line in text.splitlines() if line.strip()]
    if isinstance(data, dict):
        data = data.get("predictions", [dict(key=key, points=value) for key, value in data.items()])
    result = {}
    for row in data:
        key = row["key"]
        if key in result:
            raise ValueError(f"Duplicate prediction {key}")
        points = row.get("points", row.get("landmarks"))
        if points is not None and len(points) != 33:
            raise ValueError(f"Expected 33 mapped landmarks at {key}")
        result[key] = points
    return result


def check_prediction_coverage(frames, predictions):
    expected, supplied = set(frames), set(predictions)
    missing, unexpected = sorted(expected - supplied), sorted(supplied - expected)
    if missing or unexpected:
        raise ValueError(
            f"Prediction frame coverage mismatch: {len(missing)} unprocessed, "
            f"{len(unexpected)} unexpected. Missing examples={missing[:5]}; "
            f"unexpected examples={unexpected[:5]}. "
            "Use an explicit points:null record for an attempted detection failure.")


def model_key(name):
    key = re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")
    if not key:
        raise ValueError("Choose a nonempty model name containing letters or digits")
    return key


def angle(a, b, c):
    first, second = a - b, c - b
    denominator = np.linalg.norm(first) * np.linalg.norm(second)
    if denominator < 1e-8:
        return 0.0
    return math.acos(float(np.clip(np.dot(first, second) / denominator, -1, 1))) / math.pi


def frame_features(points, width, height):
    if points is None or len(points) != 33:
        return None
    if any(points[index] is None or len(points[index]) < 2 for index in JOINTS):
        return None
    coordinates = np.asarray([points[index][:2] for index in JOINTS], dtype=float)
    if not np.isfinite(coordinates).all():
        return None
    joint = dict(zip(JOINTS, coordinates))
    torso = (np.linalg.norm(joint[11] - joint[23]) + np.linalg.norm(joint[12] - joint[24])) / 2
    scale = max(torso, np.linalg.norm(joint[11] - joint[12]), math.hypot(width, height) * .04)
    origin = (joint[23] + joint[24]) / 2
    normalized = np.clip((coordinates - origin) / scale, -8, 8)
    relative = dict(zip(JOINTS, normalized))
    values = normalized.ravel().tolist()
    for shoulder, elbow, wrist, hip, knee, ankle in ((11, 13, 15, 23, 25, 27), (12, 14, 16, 24, 26, 28)):
        values.extend((angle(joint[shoulder], joint[elbow], joint[wrist]),
                       angle(joint[shoulder], joint[hip], joint[knee]),
                       angle(joint[hip], joint[knee], joint[ankle])))
        for first, second in ((hip, wrist), (knee, wrist), (ankle, wrist), (knee, ankle)):
            values.extend((relative[first] - relative[second]).tolist())
        support = relative[ankle] - relative[wrist]
        offset = relative[knee] - relative[wrist]
        length = max(np.linalg.norm(support), .05)
        values.append(float((support[0] * offset[1] - support[1] * offset[0]) / length))
    return np.asarray(values, dtype=float)


def unit_features(unit, frames, predictions=None):
    samples = []
    for key in unit["frame_keys"]:
        frame = frames[key]
        points = frame["mlkit"] if predictions is None else predictions.get(key)
        samples.append(frame_features(points, frame["width"], frame["height"]))
    observed = [sample for sample in samples if sample is not None]
    if len(observed) < math.ceil(len(samples) * .6):
        return None
    median = np.median(observed, axis=0)
    matrix = np.stack([sample if sample is not None else median for sample in samples])
    return np.concatenate((matrix.ravel(), matrix.mean(axis=0), matrix.std(axis=0),
                           matrix.min(axis=0), matrix.max(axis=0)))


def metrics(truth, prediction):
    truth, prediction = np.asarray(truth), np.asarray(prediction)
    confusion = {}
    recalls = []
    for value, label in enumerate(LABELS):
        selected = prediction[truth == value]
        confusion[label] = {"normal": int(np.sum(selected == 0)),
                            "kneesDown": int(np.sum(selected == 1)),
                            "unknown": int(np.sum(selected == -1)), "total": len(selected)}
        recalls.append(float(np.mean(selected == value)) if len(selected) else None)
    return {"normal_recall": recalls[0], "knee_rejection_recall": recalls[1],
            "balanced_accuracy": float(np.mean(recalls)) if None not in recalls else None,
            "confusion": confusion, "units": len(truth),
            "known_prediction_fraction": float(np.mean(prediction != -1)) if len(truth) else None}


def candidate_models():
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.neural_network import MLPClassifier
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    models = {}
    for strength in (.1, 1.0, 10.0):
        models[f"logistic_C{strength}"] = make_pipeline(
            StandardScaler(), LogisticRegression(C=strength, max_iter=1200, random_state=SEED))
    for depth in (4, 8):
        models[f"forest_depth{depth}"] = make_pipeline(
            StandardScaler(), RandomForestClassifier(n_estimators=150, max_depth=depth,
                                                      min_samples_leaf=3, n_jobs=1, random_state=SEED))
    for sizes in ((32,), (64, 32)):
        models["mlp_" + "_".join(map(str, sizes))] = make_pipeline(
            StandardScaler(), MLPClassifier(hidden_layer_sizes=sizes, alpha=.01,
                                           max_iter=400, random_state=SEED, early_stopping=False))
    return models


def fit_and_predict(template, features, truth, available, train, validation):
    from sklearn.base import clone
    from sklearn.utils.class_weight import compute_sample_weight
    train = train[available[train]]
    targets = validation[available[validation]]
    prediction = np.full(len(validation), -1, dtype=int)
    probabilities = [None] * len(validation)
    if len(np.unique(truth[train])) != 2 or not len(targets):
        return prediction, probabilities, 0
    model = clone(template)
    final_name = model.steps[-1][0]
    with warnings.catch_warnings(record=True) as notices:
        warnings.simplefilter("always")
        model.fit(features[train], truth[train],
                  **{final_name + "__sample_weight": compute_sample_weight("balanced", truth[train])})
    positions = np.flatnonzero(available[validation])
    prediction[positions] = model.predict(features[targets])
    scores = model.predict_proba(features[targets])[:, list(model.classes_).index(1)]
    for position, score in zip(positions, scores):
        probabilities[position] = float(score)
    return prediction, probabilities, len(notices)


def evaluate_extractor(units, frames, predictions, folds):
    raw = [unit_features(unit, frames, predictions) for unit in units]
    available = np.array([row is not None for row in raw])
    valid = next((row for row in raw if row is not None), None)
    if valid is None:
        valid = np.zeros(FRAME_FEATURE_COUNT * (len(PHASES) + 4))
    features = np.stack([row if row is not None else np.zeros_like(valid) for row in raw])
    truth = np.array([LABELS.index(unit["label"]) for unit in units])
    development = np.array([i for i, unit in enumerate(units) if unit["split"] == "development"])
    holdout = np.array([i for i, unit in enumerate(units) if unit["split"] == "holdout"])
    models = candidate_models()
    ranking = []
    for name, template in models.items():
        out_of_fold = np.full(len(units), -1, dtype=int)
        warning_count = 0
        for training, validation in folds:
            prediction, _, notices = fit_and_predict(template, features, truth, available, training, validation)
            out_of_fold[validation] = prediction
            warning_count += notices
        score = metrics(truth[development], out_of_fold[development])
        ranking.append(dict(name=name, validation=score, fit_warning_count=warning_count))
    ranking.sort(key=lambda row: (-row["validation"]["balanced_accuracy"], row["name"]))
    chosen = ranking[0]["name"]
    prediction, probabilities, notices = fit_and_predict(models[chosen], features, truth, available,
                                                        development, holdout)
    complete = np.array([units[index]["full_cycle_eligible"] for index in holdout])
    report = {"selected": chosen, "selection": "same frozen grouped development folds; maximum balanced accuracy",
              "ranking": ranking, "final_fit_warning_count": notices,
              "final_training_labels": dict(Counter(LABELS[truth[i]] for i in development if available[i])),
              "final_model_fitted": bool(len(np.unique(truth[development[available[development]]])) == 2
                                         and available[holdout].any()),
              "holdout": metrics(truth[holdout], prediction),
              "holdout_complete_cycles": metrics(truth[holdout][complete], prediction[complete]),
              "usable_units": {split: int(sum(available[i] for i, unit in enumerate(units) if unit["split"] == split))
                               for split in ("development", "holdout")}}
    return report, prediction, probabilities


def paired_intervals(units, first, second):
    truth = np.array([LABELS.index(unit["label"]) for unit in units])
    groups = sorted({unit["group_id"] for unit in units})
    members = {group: np.array([i for i, unit in enumerate(units) if unit["group_id"] == group]) for group in groups}
    random = np.random.default_rng(SEED)
    values = defaultdict(list)
    for _ in range(2000):
        selected = np.concatenate([members[group] for group in random.choice(groups, len(groups), replace=True)])
        left, right = metrics(truth[selected], first[selected]), metrics(truth[selected], second[selected])
        for key in ("normal_recall", "knee_rejection_recall", "balanced_accuracy"):
            if left[key] is not None and right[key] is not None:
                values[key].append(right[key] - left[key])
    return {key: {"lower": float(np.quantile(value, .025)), "upper": float(np.quantile(value, .975)),
                  "resamples": len(value)} for key, value in values.items()}


def evaluate(args):
    import sklearn
    from sklearn.model_selection import StratifiedGroupKFold
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    check_manifest(manifest)
    predictions = read_predictions(args.predictions)
    units = manifest["units"]
    frames = {frame["key"]: frame for frame in manifest["frames"]}
    check_prediction_coverage(frames, predictions)
    model_name = getattr(args, "extractor_name", "Sapiens2").strip()
    comparison_key = model_key(model_name)
    baseline_name = getattr(args, "baseline_name", "MLKit").strip()
    baseline_key = model_key(baseline_name)
    if baseline_key == comparison_key:
        raise ValueError("Baseline and comparison model names must differ")
    baseline_path = getattr(args, "baseline_predictions", None)
    baseline_predictions = read_predictions(baseline_path) if baseline_path else None
    if baseline_predictions is not None:
        check_prediction_coverage(frames, baseline_predictions)
    baseline_history = getattr(args, "baseline_frame_history", "unknown") if baseline_path else "full-source-stream"
    development = np.array([i for i, unit in enumerate(units) if unit["split"] == "development"])
    group_count = len({units[index]["group_id"] for index in development})
    if group_count < 4:
        raise ValueError("At least four development groups are required")
    truth = np.array([LABELS.index(units[index]["label"]) for index in development])
    groups = np.array([units[index]["group_id"] for index in development])
    fold_count = min(5, group_count, int(np.bincount(truth, minlength=2).min()))
    if fold_count < 2:
        raise ValueError("At least two development units from each class are required")
    splitter = StratifiedGroupKFold(n_splits=fold_count, shuffle=True, random_state=SEED)
    folds = [(development[training], development[validation])
             for training, validation in splitter.split(development, truth, groups)]
    baseline, baseline_labels, baseline_probabilities = evaluate_extractor(units, frames, baseline_predictions, folds)
    comparison, comparison_labels, comparison_probabilities = evaluate_extractor(units, frames, predictions, folds)
    holdout = [unit for unit in units if unit["split"] == "holdout"]
    if not holdout:
        raise ValueError("A paired holdout is required")
    delta = {key: comparison["holdout"][key] - baseline["holdout"][key]
             for key in ("normal_recall", "knee_rejection_recall", "balanced_accuracy")}
    report = {
        "schema": "gymrats-paired-pose-comparison-v1", "scope": manifest["scope"],
        "extractor_name": model_name, "extractor_key": comparison_key,
        "baseline_name": baseline_name, "baseline_key": baseline_key,
        "manifest_sha256": file_hash(args.manifest), "predictions_sha256": file_hash(args.predictions),
        "baseline_input": {"source": "supplied predictions" if baseline_path else "embedded cached MLKit",
                           "predictions_sha256": file_hash(baseline_path) if baseline_path else None,
                           "frame_history": baseline_history},
        "comparison_frame_history": getattr(args, "extractor_frame_history", "unknown"),
        "limitations": LIMITATIONS, "numpy_version": np.__version__, "sklearn_version": sklearn.__version__,
        "seed": SEED, "summary": manifest["summary"],
        "required_frames": len(frames), "provided_frames": len(predictions),
        "missing_prediction_frames": 0,
        "explicit_detection_failures": sum(points is None for points in predictions.values()),
        "feature_description": "12 common joints, hip-centered 2D positions, torso/shoulder scale, six angles, wrist/hip/knee/ankle gaps and support-line offsets; five phases plus mean/std/min/max; no confidence feature",
        "minimum_frame_coverage": "three of five phases with all twelve common joints; missing phases imputed with within-unit medians",
        "folds": [{"training_groups": sorted({units[i]["group_id"] for i in training}),
                   "validation_groups": sorted({units[i]["group_id"] for i in validation})}
                  for training, validation in folds],
        "models": {baseline_key: baseline, comparison_key: comparison},
        "holdout_delta_vs_baseline": delta,
        "paired_group_bootstrap_95_percent": paired_intervals(holdout, baseline_labels, comparison_labels),
    }
    # Preserve the initial Sapiens comparison's top-level result keys.
    if baseline_key == "mlkit":
        report["holdout_delta_vs_mlkit"] = delta
        if comparison_key == "sapiens2":
            report.update(mlkit=baseline, sapiens2=comparison, holdout_delta_sapiens_minus_mlkit=delta)
    save_json(args.out / "comparison.json", report)
    with (args.out / "holdout-predictions.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(("unit_id", "group_id", "reference", "full_cycle_eligible", baseline_key, comparison_key,
                         baseline_key + "_knee_probability", comparison_key + "_knee_probability"))
        for unit, first, second, first_probability, second_probability in zip(
                holdout, baseline_labels, comparison_labels, baseline_probabilities, comparison_probabilities):
            writer.writerow((unit["id"], unit["group_id"], unit["label"], unit["full_cycle_eligible"],
                             LABELS[first] if first >= 0 else "unknown", LABELS[second] if second >= 0 else "unknown",
                             first_probability, second_probability))
    print(json.dumps({"scope": manifest["scope"], "extractor_name": model_name,
                      "baseline_name": baseline_name,
                      "models": {baseline_key: baseline["holdout"], comparison_key: comparison["holdout"]},
                      "delta": delta}, indent=2))


def self_test():
    import unittest

    class Checks(unittest.TestCase):
        def test_unprocessed_frames_block_evaluation(self):
            with self.assertRaisesRegex(ValueError, "1 unprocessed"):
                check_prediction_coverage({"a": {}, "b": {}}, {"a": None})

        def test_unexpected_frames_block_evaluation(self):
            with self.assertRaisesRegex(ValueError, "1 unexpected"):
                check_prediction_coverage({"a": {}}, {"a": None, "wrong": None})

        def test_explicit_failed_detections_are_complete(self):
            check_prediction_coverage({"a": {}, "b": {}}, {"a": None, "b": None})

        def test_extractor_labels(self):
            self.assertEqual(model_key("Sapiens2"), "sapiens2")
            self.assertEqual(model_key("RTMPose-s Android"), "rtmpose_s_android")
            self.assertEqual(model_key("MLKit Accurate"), "mlkit_accurate")
            with self.assertRaises(ValueError):
                model_key(" ")

        def test_supplied_failed_baseline_overrides_cached_points(self):
            points = [[index * 3., (index % 7) * 11.] for index in range(33)]
            frames = {str(i): {"mlkit": points, "width": 100, "height": 200} for i in range(5)}
            unit = {"frame_keys": list(frames)}
            self.assertIsNotNone(unit_features(unit, frames))
            self.assertIsNone(unit_features(unit, frames, {key: None for key in frames}))

        def test_custom_baseline_report_and_csv_names(self):
            import contextlib
            import io
            import tempfile
            from types import SimpleNamespace
            from unittest.mock import patch

            units = [{"id": str(i), "split": "development" if i < 4 else "holdout",
                      "group_id": str(i), "label": LABELS[i % 2],
                      "frame_keys": [str(i)] * 5, "full_cycle_eligible": True} for i in range(6)]
            frames = [{"key": str(i), "mlkit": None, "width": 100, "height": 200} for i in range(6)]
            manifest = {"scope": "synthetic self-test", "frames": frames, "units": units,
                        "summary": manifest_summary(units)}
            observed = []

            def fake_extractor(units, frames, predictions, folds):
                observed.append(predictions["0"][0][0])
                return {"holdout": metrics([0, 1], [0, 1])}, np.array([0, 1]), [.1, .9]

            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                save_json(root / "manifest.json", manifest)
                for name, value in (("baseline", 1.), ("candidate", 2.)):
                    save_json(root / f"{name}.json", [{"key": str(i), "points": [[value, value]] * 33} for i in range(6)])
                args = SimpleNamespace(manifest=root / "manifest.json", predictions=root / "candidate.json",
                                       baseline_predictions=root / "baseline.json", out=root / "results",
                                       baseline_name="MLKit Accurate Android", extractor_name="RTMPose-s Android",
                                       baseline_frame_history="selected-frames", extractor_frame_history="independent-frames")
                with patch(f"{__name__}.evaluate_extractor", side_effect=fake_extractor), \
                        patch(f"{__name__}.paired_intervals", return_value={}), contextlib.redirect_stdout(io.StringIO()):
                    evaluate(args)
                report = json.loads((args.out / "comparison.json").read_text())
                self.assertEqual(observed, [1., 2.])
                self.assertEqual(set(report["models"]), {"mlkit_accurate_android", "rtmpose_s_android"})
                self.assertEqual(report["baseline_input"]["frame_history"], "selected-frames")
                self.assertIn("rtmpose_s_android_knee_probability", (args.out / "holdout-predictions.csv").read_text())

        def test_scores_include_unknown(self):
            result = metrics([0, 0, 1, 1], [0, -1, 1, 0])
            self.assertEqual(result["normal_recall"], .5)
            self.assertEqual(result["knee_rejection_recall"], .5)
            self.assertEqual(result["confusion"]["normal"]["unknown"], 1)

        def test_scale_translation_and_score_invariance(self):
            points = [[index * 3., (index % 7) * 11., .1] for index in range(33)]
            moved = [[point[0] * 2 + 7, point[1] * 2 - 9, .9] for point in points]
            np.testing.assert_allclose(frame_features(points, 100, 200),
                                       frame_features(moved, 200, 400), atol=1e-7)

        def test_missing_core_joint_invalidates_frame(self):
            points = [[0., 0.] for _ in range(33)]
            points[25] = None
            self.assertIsNone(frame_features(points, 100, 200))

        def test_missing_three_frames_invalidates_unit(self):
            points = [[index * 3., (index % 7) * 11.] for index in range(33)]
            frames = {str(i): {"mlkit": points if i < 2 else None, "width": 100, "height": 200} for i in range(5)}
            self.assertIsNone(unit_features({"frame_keys": list(frames)}, frames))

        def test_pilot_deterministic_and_disjoint(self):
            units = [{"id": f"{split}-{group}-{label}", "split": split,
                      "group_id": f"{split}-{group}", "label": label}
                     for split in ("development", "holdout") for group in range(8) for label in LABELS]
            first = pilot_units(units, 4, 3, 2)
            self.assertEqual(first, pilot_units(list(reversed(units)), 4, 3, 2))
            self.assertEqual(len(first), 14)
            self.assertEqual(Counter(unit["label"] for unit in first), {"normal": 7, "kneesDown": 7})

        def test_all_missing_extractor_keeps_denominators(self):
            units = [{"id": str(i), "split": "development" if i < 4 else "holdout",
                      "group_id": str(i), "label": LABELS[i % 2],
                      "frame_keys": ["missing"] * 5, "full_cycle_eligible": True} for i in range(6)]
            frames = {"missing": {"mlkit": None, "width": 100, "height": 200}}
            folds = [(np.array([0, 1]), np.array([2, 3])), (np.array([2, 3]), np.array([0, 1]))]
            report, labels, _ = evaluate_extractor(units, frames, {}, folds)
            self.assertEqual(labels.tolist(), [-1, -1])
            self.assertEqual(report["holdout"]["balanced_accuracy"], 0.)
            self.assertEqual(report["holdout"]["units"], 2)
            self.assertFalse(report["final_model_fitted"])

        def test_estimator_fit_is_deterministic(self):
            template = candidate_models()["logistic_C1.0"]
            features = np.array([[float(i % 2), float(i) / 100] for i in range(20)])
            truth = np.array([i % 2 for i in range(20)])
            available = np.ones(20, dtype=bool)
            first = fit_and_predict(template, features, truth, available, np.arange(12), np.arange(12, 20))
            second = fit_and_predict(template, features, truth, available, np.arange(12), np.arange(12, 20))
            np.testing.assert_equal(first[0], second[0])
            np.testing.assert_allclose(first[1], second[1])
            np.testing.assert_equal(first[0], truth[12:])

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks))
    if not result.wasSuccessful():
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--corpus", type=Path, required=True)
    prepare_parser.add_argument("--out", type=Path, required=True)
    prepare_parser.add_argument("--pilot-development-groups", type=int, default=32)
    prepare_parser.add_argument("--pilot-holdout-groups", type=int, default=12)
    prepare_parser.add_argument("--pilot-max-units-per-group", type=int, default=2)
    evaluate_parser = commands.add_parser("evaluate")
    evaluate_parser.add_argument("--manifest", type=Path, required=True)
    evaluate_parser.add_argument("--predictions", type=Path, required=True)
    evaluate_parser.add_argument("--out", type=Path, required=True)
    evaluate_parser.add_argument("--extractor-name", default="Sapiens2",
                                 help="Name of the comparison extractor, for example RTMPose-s Android")
    evaluate_parser.add_argument("--baseline-predictions", type=Path,
                                 help="Optional fresh baseline JSONL, requiring all selected frame keys")
    evaluate_parser.add_argument("--baseline-name", default="MLKit")
    histories = ("independent-frames", "selected-frames", "full-source-stream", "unknown")
    evaluate_parser.add_argument("--baseline-frame-history", choices=histories, default="unknown",
                                 help="Declared temporal input history for supplied baseline predictions")
    evaluate_parser.add_argument("--extractor-frame-history", choices=histories, default="unknown")
    commands.add_parser("self-test")
    args = parser.parse_args()
    if args.command == "prepare":
        if min(args.pilot_development_groups, args.pilot_holdout_groups, args.pilot_max_units_per_group) < 1:
            parser.error("Pilot sizes must be positive")
        prepare(args)
    elif args.command == "evaluate":
        evaluate(args)
    else:
        self_test()


if __name__ == "__main__":
    main()

"""Train the historical v1 single-frame forest from the paired-pose corpus.

This helper retains v1 binary selection/observability for model reproduction.
The current unified Dart policy additionally checks all 12 feature joints,
frontal arm-view reliability and gray-score bilateral corroboration. Old
binary training scores are not measurements of that newer runtime policy.

Each row contains one actual ML Kit Accurate frame and 48 geometric features.
Clip labels are inherited weak labels. Grouped development predictions select
the model and threshold before the reused source-group holdout is evaluated.
Generated model, report, and Dart parity fixtures stay in the output directory.
"""

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from sklearn.base import clone
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier
from sklearn.utils.class_weight import compute_sample_weight
from threadpoolctl import threadpool_limits

from compare_sapiens_mlkit import JOINTS, frame_features


SEED = 217
LABELS = ("kneesUp", "kneesDown")


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def visible(record, joints):
    points = record["points"]
    if points is None or len(points) != 33:
        return False
    for joint in joints:
        point = points[joint]
        if (point is None or len(point) < 3 or not all(math.isfinite(v) for v in point[:3])
                or point[2] < .65 or not 0 <= point[0] <= record["width"]
                or not 0 <= point[1] <= record["height"]):
            return False
    return True


def app_observable(record):
    """Historical v1 eight-joint/torso gate, not the current unified API."""
    if not visible(record, (15, 16, 23, 24, 25, 26, 27, 28)):
        return False
    points = record["points"]
    for joint in (11, 12):
        point = points[joint]
        if (point is None or len(point) < 2 or not all(math.isfinite(v) for v in point[:2])
                or not 0 <= point[0] <= record["width"] or not 0 <= point[1] <= record["height"]):
            return False
    torso = [points[joint] for joint in (11, 12, 24, 23)]
    for knee in (25, 26):
        positive, negative, area = False, False, 0.
        point = points[knee]
        for index, first in enumerate(torso):
            second = torso[(index + 1) % len(torso)]
            area += first[0] * second[1] - second[0] * first[1]
            cross = ((second[0] - first[0]) * (point[1] - first[1])
                     - (second[1] - first[1]) * (point[0] - first[0]))
            positive = positive or cross > 0
            negative = negative or cross < 0
        if abs(area) > 1e-8 and not (positive and negative):
            return False
    return True


def prepare(root):
    manifest_path = root / "full/evaluation-manifest.json"
    predictions_path = root / "phone-results/full-mlkit-accurate.jsonl"
    status = load(root / "phone-results/full-mlkit-accurate.status.json")
    if status["state"] != "complete" or status["completed"] != status["total"]:
        raise ValueError("ML Kit Accurate prediction job must be complete")
    manifest = load(manifest_path)
    predictions = {}
    with predictions_path.open(encoding="utf-8") as stream:
        for line in stream:
            record = json.loads(line)
            if record["key"] in predictions or record.get("warmup"):
                raise ValueError("Duplicate or warmup frame in prediction data")
            if record["model"] != "mlkit-accurate":
                raise ValueError("Expected ML Kit Accurate predictions")
            predictions[record["key"]] = record
    frames = {frame["key"]: frame for frame in manifest["frames"]}
    if predictions.keys() != frames.keys():
        raise ValueError("Prediction coverage differs from the frozen manifest")
    assignments = defaultdict(list)
    for unit in manifest["units"]:
        for key in unit["frame_keys"]:
            assignments[key].append(unit)
    rows, values, available, excluded = [], [], [], []
    for key in sorted(assignments):
        units = assignments[key]
        if len({unit["label"] for unit in units}) != 1:
            excluded.append({"key": key, "reason": "conflicting inherited clip labels"})
            continue
        if len({(unit["split"], unit["group_id"]) for unit in units}) != 1:
            raise ValueError(f"Frame has conflicting split or source group: {key}")
        frame, record, unit = frames[key], predictions[key], units[0]
        for field in ("source_id", "index", "width", "height"):
            if frame[field] != record[field]:
                raise ValueError(f"Prediction metadata differs for {key}: {field}")
        feature = frame_features(record["points"], frame["width"], frame["height"])
        usable = feature is not None and len(feature) == 48 and np.isfinite(feature).all()
        available.append(usable)
        values.append(feature if usable else np.zeros(48))
        rows.append({
            "key": key, "source_id": frame["source_id"], "group_id": unit["group_id"],
            "split": unit["split"], "label": "kneesDown" if unit["label"] == "kneesDown" else "kneesUp",
            "unit_ids": sorted({item["id"] for item in units}),
            "width": frame["width"], "height": frame["height"], "index": frame["index"],
            "full_cycle_eligible": all(item["full_cycle_eligible"] for item in units),
            "human_verified": all(item["human_verified"] for item in units),
            "lower_body_visible_065": visible(record, (23, 24, 25, 26, 27, 28)),
            "all_required_visible_065": visible(record, JOINTS),
            "app_support8_torso_gate": app_observable(record),
        })
    groups = {split: {row["group_id"] for row in rows if row["split"] == split}
              for split in ("development", "holdout")}
    if groups["development"] & groups["holdout"]:
        raise ValueError("Development and holdout source groups overlap")
    provenance = {"manifest_sha256": sha256(manifest_path),
                  "predictions_sha256": sha256(predictions_path), "excluded_frames": excluded}
    return rows, np.stack(values), np.asarray(available), predictions, provenance


def metrics(truth, probabilities, threshold, observable):
    predicted = np.full(len(truth), -1, dtype=int)
    valid = observable & np.isfinite(probabilities)
    predicted[valid] = (probabilities[valid] > threshold).astype(int)
    confusion = {}
    recalls = []
    for value, label in enumerate(LABELS):
        outputs = predicted[truth == value]
        total = len(outputs)
        confusion[label] = {"kneesUp": int(np.sum(outputs == 0)),
                            "kneesDown": int(np.sum(outputs == 1)),
                            "unobservable": int(np.sum(outputs == -1)), "total": total}
        recalls.append(float(np.mean(outputs == value)) if total else 0.)
    return {"confusion": confusion, "normal_recall": recalls[0], "knee_recall": recalls[1],
            "balanced_recall": sum(recalls) / 2,
            "observable_fraction": float(np.mean(valid))}


def select_threshold(truth, probabilities, available):
    # A fixed development-only grid keeps selection reproducible and bounded.
    candidates = []
    for threshold in np.linspace(0., 1., 101):
        score = metrics(truth, probabilities, float(threshold), available)
        candidates.append({"threshold": float(threshold), "score": score})
    qualified = [item for item in candidates if item["score"]["normal_recall"] >= .95]
    if qualified:
        return max(qualified, key=lambda item: (item["score"]["balanced_recall"],
                                               item["score"]["normal_recall"]))
    return max(candidates, key=lambda item: (item["score"]["normal_recall"],
                                            item["score"]["balanced_recall"]))


def candidates():
    return {
        "tree_depth4": make_pipeline(StandardScaler(), DecisionTreeClassifier(
            max_depth=4, min_samples_leaf=10, random_state=SEED)),
        "tree_depth6": make_pipeline(StandardScaler(), DecisionTreeClassifier(
            max_depth=6, min_samples_leaf=10, random_state=SEED)),
        "logistic_C1": make_pipeline(StandardScaler(), LogisticRegression(
            C=1., max_iter=1200, random_state=SEED)),
        "forest32_depth4": make_pipeline(StandardScaler(), RandomForestClassifier(
            n_estimators=32, max_depth=4, min_samples_leaf=10, n_jobs=1, random_state=SEED)),
    }


def fit(template, features, truth, indices):
    model = clone(template)
    model.fit(features[indices], truth[indices], **{
        model.steps[-1][0] + "__sample_weight": compute_sample_weight("balanced", truth[indices])})
    return model


def export_model(model, name, threshold):
    scaler, estimator = model.steps[0][1], model.steps[-1][1]
    output = {"schema": "gymrats-single-frame-knee-v1", "name": name, "feature_count": 48,
              "labels": list(LABELS), "rejection_threshold": threshold,
              "comparison": "kneesDown when probability strictly exceeds threshold",
              "mean": scaler.mean_.tolist(), "scale": scaler.scale_.tolist()}
    if isinstance(estimator, LogisticRegression):
        output.update(kind="logistic", coefficients=estimator.coef_[0].tolist(),
                      intercept=float(estimator.intercept_[0]))
        return output
    trees = estimator.estimators_ if isinstance(estimator, RandomForestClassifier) else [estimator]
    roots, left, right, feature, split, probability = [], [], [], [], [], []
    for tree_model in trees:
        tree = tree_model.tree_
        offset = len(feature)
        roots.append(offset)
        left.extend(int(value + offset) if value >= 0 else -1 for value in tree.children_left)
        right.extend(int(value + offset) if value >= 0 else -1 for value in tree.children_right)
        feature.extend(int(value) for value in tree.feature)
        split.extend(float(value) for value in tree.threshold)
        probability.extend(float(row[0][1] / row[0].sum()) for row in tree.value)
    output.update(kind="forest", roots=roots, left=left, right=right, feature=feature,
                  split=split, probability=probability)
    return output


def exported_probabilities(model, features):
    scaled = (features - np.asarray(model["mean"])) / np.asarray(model["scale"])
    if model["kind"] == "logistic":
        scores = scaled @ np.asarray(model["coefficients"]) + model["intercept"]
        return 1. / (1. + np.exp(-scores))
    scaled = scaled.astype(np.float32)
    outputs = []
    for row in scaled:
        value = 0.
        for root in model["roots"]:
            node = root
            while model["feature"][node] >= 0:
                branch = "left" if row[model["feature"][node]] <= model["split"][node] else "right"
                node = model[branch][node]
            value += model["probability"][node]
        outputs.append(value / len(model["roots"]))
    return np.asarray(outputs)


def dart_source(model):
    lines = ["// Generated by tools/diagnose/train_frame_knee.py.",
             "/// Knee-support probability from one current pose frame.",
             "class SingleFrameKneeModel {",
             f"  static const double rejectionThreshold = {model['rejection_threshold']!r};",
             "  static double? probability(PoseFrame frame) {",
             "    final features = KneeForestClassifier._frameFeatures(frame);",
             "    return features == null ? null : probabilityFromFeatures(features);",
             "  }", "", "  static double probabilityFromFeatures(List<double> features) {",
             "    if (features.length != 48 || features.any((value) => !value.isFinite)) {",
             "      throw ArgumentError('Expected 48 finite single-frame features');", "    }"]
    if model["kind"] == "logistic":
        lines += [f"    var score = {model['intercept']!r};", "    for (var i = 0; i < 48; i++) {",
                  "      score += ((features[i] - _mean[i]) / _scale[i]) * _coefficients[i];", "    }",
                  "    return 1 / (1 + math.exp(-score));", "  }"]
    else:
        lines += ["    final scaled = Float32List(48);", "    for (var i = 0; i < 48; i++) {",
                  "      scaled[i] = (features[i] - _mean[i]) / _scale[i];", "    }",
                  "    var probability = 0.0;", "    for (final root in _roots) {", "      var node = root;",
                  "      while (_feature[node] >= 0) {", "        node = scaled[_feature[node]] <= _split[node]",
                  "            ? _left[node] : _right[node];", "      }",
                  "      probability += _probability[node];", "    }", "    return probability / _roots.length;", "  }"]
    integer_arrays = {"roots", "left", "right", "feature"}
    arrays = ["mean", "scale", "coefficients"] if model["kind"] == "logistic" else [
        "mean", "scale", "roots", "left", "right", "feature", "split", "probability"]
    for key in arrays:
        kind = "int" if key in integer_arrays else "double"
        lines += ["", f"  static const List<{kind}> _{key} = <{kind}>["]
        lines += [f"    {value!r}," for value in model[key]]
        lines += ["  ];"]
    return "\n".join(lines + ["}", ""])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("C:/SWPP/iter4/mobile-pose-benchmark"))
    parser.add_argument("--output", type=Path, default=Path("C:/SWPP/iter4/frame-knee"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows, features, available, predictions, provenance = prepare(args.root)
    truth = np.asarray([LABELS.index(row["label"]) for row in rows])
    groups = np.asarray([row["group_id"] for row in rows])
    development = np.asarray([i for i, row in enumerate(rows) if row["split"] == "development"])
    holdout = np.asarray([i for i, row in enumerate(rows) if row["split"] == "holdout"])
    splitter = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=SEED)
    folds = [(development[a], development[b]) for a, b in splitter.split(
        features[development], truth[development], groups[development])]
    ranking, templates, oof_by_model = [], candidates(), {}
    for name, template in templates.items():
        oof = np.full(len(rows), np.nan)
        for train, validation in folds:
            if set(groups[train]) & set(groups[validation]):
                raise ValueError("Development fold group leakage")
            usable_train, usable_validation = train[available[train]], validation[available[validation]]
            fitted = fit(template, features, truth, usable_train)
            oof[usable_validation] = fitted.predict_proba(features[usable_validation])[:, 1]
        choice = select_threshold(truth[development], oof[development], available[development])
        ranking.append({"name": name, **choice})
        oof_by_model[name] = oof
        print(name, json.dumps(choice), flush=True)
    eligible = [item for item in ranking if item["score"]["normal_recall"] >= .95]
    selection = max(eligible or ranking, key=lambda item: (
        item["score"]["balanced_recall"] if eligible else item["score"]["normal_recall"],
        item["score"]["normal_recall"] if eligible else item["score"]["balanced_recall"]))
    name, threshold = selection["name"], selection["threshold"]
    fitted = fit(templates[name], features, truth, development[available[development]])
    probabilities = np.full(len(rows), np.nan)
    probabilities[available] = fitted.predict_proba(features[available])[:, 1]
    exported = export_model(fitted, name, threshold)
    portable = exported_probabilities(exported, features[available])
    error = float(np.max(np.abs(portable - probabilities[available])))
    if error > 1e-10:
        raise ValueError(f"Export parity failed: {error}")
    report = {
        "schema": "gymrats-single-frame-knee-study-v1", "seed": SEED, **provenance,
        "feature_count": 48, "selected": name, "threshold": threshold,
        "selection_rule": "Five grouped development folds. Prefer normal recall >=95%, then maximum balanced recall. Threshold grid 0.00..1.00 in 0.01 increments.",
        "labels": "Single-frame weak labels inherited from existing normal/kneesDown clip labels.",
        "limitations": ["Frame-level knee contact has no independent human verification.",
                        "Normal/knee clip labels can disagree with a transition frame's actual support state.",
                        "The existing source-group holdout was inspected in earlier studies and is reused.",
                        "Missing/low-confidence gates indicate unavailable evidence, without verifying physical occlusion.",
                        "This experiment measures frame classification, with no repetition-boundary or live app accuracy claim."],
        "ranking": ranking, "export_max_probability_error": error,
        "development_oof": metrics(truth[development], oof_by_model[name][development], threshold, available[development]),
        "splits": {split: {"frames": len(indices), "groups": len(set(groups[indices])),
                           "labels": dict(Counter(rows[i]["label"] for i in indices)),
                           "feature_unavailable": int(np.sum(~available[indices]))}
                   for split, indices in [("development", development), ("holdout", holdout)]},
        "holdout": metrics(truth[holdout], probabilities[holdout], threshold, available[holdout]),
        "holdout_confidence_scenarios": {},
    }
    for gate in ("lower_body_visible_065", "all_required_visible_065", "app_support8_torso_gate"):
        observable = available & np.asarray([row[gate] for row in rows])
        report["holdout_confidence_scenarios"][gate] = metrics(
            truth[holdout], probabilities[holdout], threshold, observable[holdout])
    save(args.output / "comparison.json", report)
    save(args.output / "model.json", exported)
    (args.output / "single_frame_knee.dart").write_text(dart_source(exported), encoding="utf-8")
    save(args.output / "frame-manifest.json", {"provenance": provenance, "frames": rows})
    # Include actual frames of both classes and decision-boundary cases.
    chosen = set()
    for label in (0, 1):
        pool = [int(i) for i in holdout if available[i] and truth[i] == label]
        chosen.update(pool[:12])
        chosen.update(sorted(pool, key=lambda i: abs(probabilities[i] - threshold))[:8])
    golden = []
    for i in sorted(chosen):
        row = rows[i]
        golden.append({**row, "points": predictions[row["key"]]["points"],
                       "features": features[i].tolist(), "probability": float(probabilities[i]),
                       "expected_state": LABELS[int(probabilities[i] > threshold)]})
    save(args.output / "golden-frames.json", {"model_sha256": sha256(args.output / "model.json"), "frames": golden})
    with (args.output / "predictions.jsonl").open("w", encoding="utf-8") as stream:
        for i, row in enumerate(rows):
            probability = probabilities[i] if row["split"] == "holdout" else oof_by_model[name][i]
            stream.write(json.dumps({"key": row["key"], "split": row["split"], "label": row["label"],
                                     "probability": float(probability) if np.isfinite(probability) else None}) + "\n")
    print(json.dumps({"selected": name, "threshold": threshold, "holdout": report["holdout"],
                      "output": str(args.output)}, indent=2), flush=True)


if __name__ == "__main__":
    with threadpool_limits(limits=1):
        main()

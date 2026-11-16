"""Fit shallow on-device feedback trees on labelled development groups only.

Each tree can refine an already rejected partial rep. Event time, valid count,
and severe existing faults are fixed by the streaming Dart judge. Fold models
produce the development predictions; the final development model is used on
the held-out groups without access to their intervals or labels.
"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

import numpy as np
import sklearn
from sklearn.tree import DecisionTreeClassifier

from score_pushup_nine import match, read_sources, save

BASES = ("tilt15_shallow18", "small30_knees_tilt15", "small30_elev60_knees_tilt15_guarded")
KEEP = "keep"
REPLAY_REASONS = {"insufficientDepth", "shouldersNotLevel"}
FEATURES = ["maxDepth", "minElbow", "maxTilt", "bottomHipHandGap", "bottomTorsoDrop",
            "minTorsoDrop", "maxTorsoDrop", "returnElbow", "topHipHandGap",
            "kneeEvidence", "consecutiveKneeFloorEvidence"]


def supports(label, v):
    if label == "kneesDown":
        return v[9] == 1
    if label == "shouldersNotLevel":
        return v[2] is not None and v[2] >= 8 and v[1] is not None and v[1] <= 155
    if label == "armsStraight":
        return v[1] is not None and v[1] >= 155 and v[0] is not None and v[0] >= 0.5
    return False


def sample_vector(values):
    if len(values) != len(FEATURES):
        raise ValueError("Wrong evidence schema")
    return [-999 if v is None else v for v in values]


def samples(manifest, features, base):
    records = []
    for key, r in manifest.items():
        if r["split"] != "development":
            continue
        units = sorted((u for u in r["units"] if not u.get("confirmed_duplicate_of")),
                       key=lambda u: (u["end"], u["start"], u["unit_id"]))
        ev, vec = streams(features[key], base)
        pairs, _ = match(units, ev, r["fps"])
        for u, j in pairs.items():
            label, old, v = units[u]["label"], ev[j][1], vec[j]
            if label and old in REPLAY_REASONS:
                target = label if label != old and supports(label, v) else KEEP
                records.append((r["group_id"], sample_vector(v), target))
    return records


def streams(row, base):
    events = row["events"][base]
    vec = row["features"][base]
    if len(events) != len(vec):
        raise ValueError(f"Events and evidence have different lengths for {row['source_id']}")
    return events, vec


def leaf_for(nodes, vs):
    vec = sample_vector(vs)
    i = 0
    while "feature" in nodes[i]:
        n = nodes[i]
        i = n["left"] if vec[n["feature"]] <= n["threshold"] else n["right"]
    return i


def predict(events, vec, nodes):
    result = []
    for (frame, old), values in zip(events, vec):
        reason = old
        if old in REPLAY_REASONS:
            new = nodes[leaf_for(nodes, values)]["label"]
            if supports(new, values):
                reason = new
        result.append([frame, reason])
    return result


def train(records, fixtures, depth, min_leaf, base):
    counts = Counter(t for _, _, t in records)
    if not counts:
        raise ValueError("Empty training fold")
    tree = DecisionTreeClassifier(max_depth=depth, min_samples_leaf=min_leaf,
                                  class_weight={k: (len(records)/v)**0.7 for k, v in counts.items()},
                                  random_state=8)
    tree.fit(np.array([v for _, v, _ in records]), [t for _, _, t in records])
    raw = tree.tree_
    nodes = []
    for i, feature in enumerate(raw.feature):
        if feature < 0:
            nodes.append({"label": str(tree.classes_[np.argmax(raw.value[i])])})
        else:
            nodes.append(dict(feature=int(feature), threshold=round(float(raw.threshold[i]), 5),
                              left=int(raw.children_left[i]), right=int(raw.children_right[i])))
    # A learned leaf that would rewrite a pinned native recording abstains.
    # The independent internet holdout is never used for this restriction.
    for r in fixtures:
        ev, vec = streams(r, base)
        for (_, old), v in zip(ev, vec):
            if old in REPLAY_REASONS:
                leaf = leaf_for(nodes, v)
                new = nodes[leaf]["label"]
                if new != old and supports(new, v):
                    nodes[leaf]["label"] = KEEP
    return nodes


def write_rows(path, rows):
    with path.open("w", encoding="utf8") as f:
        for row in rows:
            f.write(json.dumps(row, separators=(",", ":"), allow_nan=False) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("units", "features", "fixture-features", "events", "fixtures", "out"):
        p.add_argument("--" + name, required=True, type=Path)
    args = p.parse_args()
    manifest, features, outputs = map(read_sources, (args.units, args.features, args.events))
    if manifest.keys() != features.keys() or manifest.keys() != outputs.keys():
        raise ValueError("Expected the same source inventory")
    with args.fixture_features.open(encoding="utf8") as f:
        fixture_features = [json.loads(l) for l in f]
    with args.fixtures.open(encoding="utf8") as f:
        fixtures = [json.loads(l) for l in f]
    if [(r['suite'], r['source_id']) for r in fixtures] != [
        (r['suite'], r['source_id']) for r in fixture_features
    ]:
        raise ValueError("Native fixtures differ")
    groups = sorted({r["group_id"] for r in manifest.values() if r["split"] == "development"},
                    key=lambda g: hashlib.sha256(("gymrats-fold-5/" + g).encode()).digest())
    folds = {g: i % 5 for i, g in enumerate(groups)}
    args.out.mkdir(parents=True, exist_ok=True)
    model = dict(features=FEATURES, development_groups=len(groups), folds=5,
                 sklearn_version=sklearn.__version__, numpy_version=np.__version__,
                 trees={}, training={})
    fitted_events = {key: {"source_id": key, "events": {"baseline": row["events"]["baseline"]}}
                     for key, row in outputs.items()}
    for base in BASES:
        data = samples(manifest, features, base)
        model["training"][base] = dict(examples=len(data), targets=dict(Counter(t for _, _, t in data)))
        for depth, min_leaf in ((3, 16), (5, 10)):
            cname = f"tree{depth}_{base}"
            full = train(data, fixture_features, depth, min_leaf, base)
            cv = [train([r for r in data if folds[r[0]] != k], fixture_features, depth, min_leaf, base)
                  for k in range(5)]
            model["trees"][cname] = full
            for key, row in manifest.items():
                tree = cv[folds[row["group_id"]]] if row["split"] == "development" else full
                ev, vec = streams(features[key], base)
                if ev != outputs[key]["events"][base]:
                    raise ValueError("Base engine changed")
                outputs[key]["events"][cname] = predict(ev, vec, tree)
                fitted_events[key]["events"][cname] = predict(ev, vec, full)
            for r, feat in zip(fixtures, fixture_features):
                ev, vec = streams(feat, base)
                if ev != r["events"][base] or predict(ev, vec, full) != ev:
                    raise ValueError("A frozen native verdict changed")
                for k in ("events", "tally", "safety"):
                    if base in r.get(k, {}):
                        r[k][cname] = r[k][base]
    save(args.out / "feedback-trees.json", model)
    write_rows(args.out / "events-with-trees.jsonl", outputs.values())
    write_rows(args.out / "refit-events.jsonl", fitted_events.values())
    write_rows(args.out / "fixtures-with-trees.jsonl", fixtures)


if __name__ == "__main__":
    main()

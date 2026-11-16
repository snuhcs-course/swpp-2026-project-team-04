"""Export original-time pose streams and independently keyed 9-class recut annotations.

Usage: python prepare_pushup_nine_replay.py COLLECTION_DIR OUTPUT_DIR
Requires NumPy. Writes replay.jsonl, units.jsonl and replay-audit.json in OUTPUT_DIR.
"""

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np


SCHEMA = "gymrats-nine-replay-v1"


def load(path):
    return json.loads(path.read_bytes())


def file_hash(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check(condition, message):
    if not condition:
        raise ValueError(message)


def by_id(rows, key):
    indexed = {row[key]: row for row in rows}
    check(len(indexed) == len(rows), f"Duplicate {key} in input")
    return indexed


def unit_annotation(annotation, recut, inventory, links, categories):
    uid = recut["unit_id"]
    visual = annotation["recut_visual_review"]
    for field in ("source_id", "source_sha256"):
        check(annotation[field] == recut[field] == inventory[field], f"{uid}: mismatched {field}")
    # classification.json keeps the older core interval in its top-level geometry.
    # The visual subrecord explicitly names the film, range and digest to which its labels apply.
    for field in ("start_frame", "end_frame_exclusive"):
        check(visual[field] == recut[field] == inventory[field], f"{uid}: mismatched revised {field}")
    lo, hi = recut["start_frame"], recut["end_frame_exclusive"]
    check(0 <= lo < hi <= inventory["source_frame_count"], f"{uid}: bad revised interval")
    check(visual["reviewed_output_sha256"] == inventory["sha256"] == recut["sha256"], f"{uid}: clip hash mismatch")
    clip = Path(recut["output_path"])
    check(Path(visual["reviewed_output_path"]) == clip == Path(inventory["output_path"]), f"{uid}: clip path mismatch")
    check(file_hash(clip) == recut["sha256"], f"{uid}: media does not match label")
    for key in ("primary_category", "secondary_categories"):
        check(annotation[key] == recut[key] == visual[key], f"{uid}: conflicting {key}")
    label = visual["primary_category"]
    secondary = visual["secondary_categories"]
    check((label is None or label in categories) and all(s in categories for s in secondary), f"{uid}: unknown category")
    check(not secondary or label is not None, f"{uid}: secondary without primary")
    seconds = annotation.get("bottom_source_seconds")
    bottom = round(seconds * recut["source_fps"]) if seconds is not None else None
    duplicate = links.get(uid)
    return {
        "unit_id": uid, "start": lo, "end": hi,
        "bottom": bottom if bottom is not None and lo <= bottom < hi else None,
        "label": label, "secondary": secondary, "full_cycle_eligible": recut["full_cycle_eligible"],
        "boundary_code": recut["boundary"]["code"], "legacy_canonical_id": annotation.get("canonical_unit_id"),
        "canonical_id": duplicate or uid, "confirmed_duplicate_of": duplicate,
        "label_confidence": visual["confidence"], "human_verified": visual["human_verified"],
        "clip_path": str(clip), "clip_sha256": recut["sha256"],
    }


def source_frames(cache_path, source, timing):
    with np.load(cache_path, allow_pickle=False) as data:
        check(str(data["sha256"]) == source["source_sha256"], f"{cache_path}: wrong source")
        indices = data["frame_indices"]
        times = data["times"]
        pts = data["points"].astype(np.float64)
        sample_fps = float(data["sample_fps"])
    check(pts.shape == (len(indices), 33, 5) and times.shape == indices.shape, f"{cache_path}: bad pose shape")
    check(0 < len(indices) and int(indices[0]) >= 0 and int(indices[-1]) < source["source_frame_count"]
          and np.all(np.diff(indices) > 0), f"{cache_path}: invalid source frame index")
    basis = "pose_cache_nominal_seconds"
    if timing and timing.get("pts_seconds") is not None:
        check(timing["source_sha256"] == source["source_sha256"], f"{cache_path}: mismatched PTS source")
        exact = timing["pts_seconds"]
        times = np.asarray([exact[int(i)] for i in indices])
        basis = "verified_original_pts"
    check(np.all(np.isfinite(times)) and np.all(np.diff(times) > 0), f"{cache_path}: invalid clock")
    # Quantize coordinates to a thousandth of a pixel. Off-screen landmarks stay off-screen.
    xy_score = np.stack([pts[:, :, 0] * source["source_width"], pts[:, :, 1] * source["source_height"],
                         np.minimum(pts[:, :, 3], pts[:, :, 4])], axis=2)
    valid = np.isfinite(xy_score).all(axis=2)
    check(np.all((xy_score[:, :, 2][valid] >= 0) & (xy_score[:, :, 2][valid] <= 1)), f"{cache_path}: bad score")
    xy_score[:, :, :2] = np.round(xy_score[:, :, :2], 3)
    xy_score[:, :, 2] = np.round(xy_score[:, :, 2], 6)
    frames = []
    for index, seconds, joints, mask in zip(indices, times, xy_score.tolist(), valid.tolist()):
        frames.append([int(index), round(float(seconds) * 1000),
                       [joint if visible else None for joint, visible in zip(joints, mask)]])
    return frames, sample_fps, basis, int((~valid.any(axis=1)).sum())


def prepare(root, dest):
    paths = {
        "labels": root / "rep-classification/classification.json",
        "categories": root / "rep-classification/taxonomy.json",
        "recuts": root / "rep-units/cycle-recut/manifest.json",
        "inventory": root / "taxonomy-redesign/inventory.jsonl",
        "split": root / "taxonomy-redesign/sampling.json",
        "duplicates": root / "taxonomy-redesign/records/duplicate-links.json",
        "timestamps": root / "taxonomy-redesign/source-time-verification.json",
    }
    labels = by_id(load(paths["labels"]), "unit_id")
    recuts = by_id(load(paths["recuts"]), "unit_id")
    inventory = by_id([json.loads(line) for line in paths["inventory"].read_bytes().splitlines()], "unit_id")
    check(labels.keys() == recuts.keys() == inventory.keys(), "Recut, label and split populations differ")
    categories = [r["id"] for r in load(paths["categories"])]
    check(len(set(categories)) == len(categories) == 9, "Original nine categories required")
    split = load(paths["split"])
    holdout_groups, holdout_sources = set(split["holdout_group_ids"]), set(split["holdout_source_ids"])
    links = load(paths["duplicates"])["links"]
    timings = load(paths["timestamps"])
    for uid, other in links.items():
        check(uid != other and other not in links and inventory[uid]["source_sha256"] == inventory[other]["source_sha256"],
              f"{uid}: invalid canonical link")
    groups = defaultdict(list)
    for row in inventory.values():
        groups[row["source_id"]].append(row)
    audit = {
        "schema": SCHEMA, "inputs_sha256": {k: file_hash(p) for k, p in paths.items()},
        "landmark_detector": "MediaPipe Pose Landmarker full; pre-existing original-camera pose caches",
        "detector_score": "min(visibility,presence), not a calibrated ML Kit likelihood",
        "frame_layout": "[original_frame_index, rounded_ms, 33*[x_px, y_px, score] or per-joint null]",
        "unit_range": "start inclusive, end exclusive; bottom is only a historical reference, null if outside recut",
        "labels": categories, "source_count": len(groups), "unit_count": len(labels),
        "source_media_hashes_verified": 0, "recut_media_hashes_verified": 0,
        "frames": 0, "missing_pose_frames": 0, "units_without_sample": 0, "missing_in_range_bottom": 0,
        "complete_cycle_units": 0, "confirmed_duplicate_units": len(links),
        "clock_source_counts": Counter(), "labels_by_split": defaultdict(Counter),
        "split_group_counts": {}, "split_source_counts": Counter(),
    }
    source_hashes = {}
    group_splits = {}
    dest.mkdir(parents=True, exist_ok=True)
    # Write to siblings and only replace a complete replay. Existing videos/labels are read only.
    replay = dest / "replay.jsonl"
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf8", newline="\n", dir=dest, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            for sid, units in sorted(groups.items()):
                units.sort(key=lambda r: (r["start_frame"], r["end_frame_exclusive"], r["unit_id"]))
                head = units[0]
                stable = ("source_sha256", "source_path", "source_width", "source_height", "source_fps", "source_frame_count", "group_id", "split")
                check(all(all(row[k] == head[k] for k in stable) for row in units), f"{sid}: inconsistent original metadata")
                group, part, digest = head["group_id"], head["split"], head["source_sha256"]
                check(part in ("development", "holdout") and (part == "holdout") == (group in holdout_groups) == (sid in holdout_sources),
                      f"{sid}: inconsistent holdout")
                check(group_splits.setdefault(group, part) == part and source_hashes.setdefault(digest, part) == part,
                      f"{sid}: source or group leakage")
                check(file_hash(Path(head["source_path"])) == digest, f"{sid}: original film changed")
                audit["source_media_hashes_verified"] += 1
                frames, sample_fps, basis, missing = source_frames(root / "rep-markings/pose-cache" / (sid + ".npz"),
                                                                   head, timings.get(sid))
                check(all(a[1] < b[1] for a, b in zip(frames, frames[1:])), f"{sid}: invalid milliseconds")
                annotations = []
                for row in units:
                    uid = row["unit_id"]
                    unit = unit_annotation(labels[uid], recuts[uid], row, links, categories)
                    annotations.append(unit)
                    audit["labels_by_split"][part][unit["label"] or "unassigned"] += 1
                    audit["complete_cycle_units"] += int(unit["full_cycle_eligible"])
                    audit["missing_in_range_bottom"] += int(unit["bottom"] is None)
                    audit["units_without_sample"] += int(not any(unit["start"] <= fr[0] < unit["end"] for fr in frames))
                    audit["recut_media_hashes_verified"] += 1
                replay_row = {
                    "schema": SCHEMA, "source_id": sid, "source_path": head["source_path"], "source_sha256": digest,
                    "group_id": group, "split": part, "domain": head["domain"], "width": head["source_width"],
                    "height": head["source_height"], "fps": head["source_fps"], "sample_fps": sample_fps,
                    "time_basis": basis, "frame_count": head["source_frame_count"], "units": annotations, "frames": frames,
                }
                stream.write(json.dumps(replay_row, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n")
                audit["split_source_counts"][part] += 1
                audit["frames"] += len(frames)
                audit["missing_pose_frames"] += missing
                audit["clock_source_counts"][basis] += 1
        except BaseException:
            stream.close()
            temporary.unlink(missing_ok=True)
            raise
    temporary.replace(replay)
    metadata = dest / "units.jsonl"
    with replay.open(encoding="utf8") as saved, tempfile.NamedTemporaryFile(
        mode="w", encoding="utf8", newline="\n", dir=dest, delete=False
    ) as stream:
        for line in saved:
            row = json.loads(line)
            del row["frames"]
            stream.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
        small_file = Path(stream.name)
    small_file.replace(metadata)
    audit["split_group_counts"] = Counter(group_splits.values())
    audit["replay_sha256"] = file_hash(replay)
    audit["units_sha256"] = file_hash(metadata)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf8", dir=dest, delete=False) as stream:
        json.dump(audit, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
        report = Path(stream.name)
    report.replace(dest / "replay-audit.json")
    return audit


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("collection", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.collection, args.output), ensure_ascii=True))

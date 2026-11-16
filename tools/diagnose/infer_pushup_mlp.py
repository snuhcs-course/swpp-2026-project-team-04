"""Run the exported experimental binary model on upright ML Kit streams.

Usage:
  python tools/diagnose/infer_pushup_mlp.py MODEL.npz REPLAY.jsonl PROPOSALS.jsonl OUTPUT.jsonl

PROPOSALS uses {"source_id": "...", "events": {"app_default": [[frame, reason], ...]}}.
The reason field is ignored. The file must already contain causal event times.
REPLAY uses the existing native nine-class benchmark pose schema. MP4 pixels
must first be extracted using the Android ML Kit recorder.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from scipy.special import expit
from threadpoolctl import threadpool_limits

from pushup_span_mlp import JOINTS, coordinates, vector
from score_pushup_nine import read_sources


class ExportedBinaryMlp:
    def __init__(self, path):
        with np.load(path, allow_pickle=False) as data:
            if str(data["format"]) != "gymrats-span-binary-mlp-v1":
                raise ValueError("Unsupported exported model format")
            self.mean = data["mean"].copy()
            self.scale = data["scale"].copy()
            self.classes = data["classes"].astype(str)
            self.weights = [data[f"weights_{i}"].copy() for i in range(int(data["layers"]))]
            self.biases = [data[f"biases_{i}"].copy() for i in range(int(data["layers"]))]
        if list(self.classes) != ["invalid", "normal"]:
            raise ValueError("Expected class order invalid, normal")

    def predict(self, features):
        # StandardScaler uses two in-place operations on the input float32.
        # Preserve their rounding, as well as every fitted layer's dtype.
        activation = np.asarray(features, dtype=np.float32).copy()
        if activation.ndim != 2 or activation.shape[1] != len(self.mean):
            raise ValueError("Unexpected feature shape")
        activation -= self.mean
        activation /= self.scale
        np.clip(activation, -6, 6, out=activation)
        for i, (weights, bias) in enumerate(zip(self.weights, self.biases)):
            activation = activation @ weights
            activation += bias
            if i + 1 < len(self.weights):
                np.maximum(activation, 0, out=activation)
            else:
                expit(activation, out=activation)
        normal_probability = activation.ravel()
        return self.classes[(normal_probability > .5).astype(int)], normal_probability


def stream_features(source, proposals):
    indices, times, poses = coordinates(source)
    if any(b <= a for a, b in zip(indices, indices[1:])):
        raise ValueError("Pose frame indices must strictly increase")
    if any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError("Pose times must strictly increase")
    features, previous_time, previous_frame = [], -1, -1
    for frame, _ in proposals:
        if frame <= previous_frame:
            raise ValueError("Proposals must be unique and ordered")
        previous_frame = frame
        end = int(indices.searchsorted(frame))
        if end == len(indices) or indices[end] != frame:
            raise ValueError(f"Unknown proposal frame {frame}")
        start = times.searchsorted(max(previous_time + 1, times[end] - 1600))
        x = vector(times[start:end+1], poses[start:end+1])
        if x is None:
            x = vector(np.array([0]), np.full((1, len(JOINTS), 2), np.nan))
        features.append(x)
        previous_time = times[end]
    return np.stack(features) if features else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("model", "replay", "proposals", "output"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    model = ExportedBinaryMlp(args.model)
    proposals = read_sources(args.proposals)
    seen = set()
    with args.output.open("x", encoding="utf8") as out, args.replay.open(encoding="utf8") as inp:
        with threadpool_limits(limits=1):
            for line in inp:
                source = json.loads(line)
                key = source["source_id"]
                if key in seen:
                    raise ValueError(f"Duplicate source {key}")
                seen.add(key)
                events = proposals[key]["events"]["app_default"]
                x = stream_features(source, events)
                predictions = []
                if x is not None:
                    labels, probabilities = model.predict(x)
                    predictions = [
                        {"frame": int(event[0]), "label": str(label),
                         "normal_probability": float(probability)}
                        for event, label, probability in zip(events, labels, probabilities)
                    ]
                out.write(json.dumps({"source_id": key, "predictions": predictions},
                                     separators=(",", ":")) + "\n")
    if seen != set(proposals):
        raise ValueError("Replay and proposal inventories differ")


if __name__ == "__main__":
    main()

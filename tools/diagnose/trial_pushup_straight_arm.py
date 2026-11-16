"""Development experiment for a straight-arm forward/backward rock on planted hands.

Only refine an existing shallow rejection after observing a complete excursion.
The resulting events cannot duplicate a repetition or alter the valid count.
"""
import argparse
import json
import math
from collections import deque
from pathlib import Path

from score_pushup_nine import evaluate, read_sources

BASE = "small30_elev60_knees_tilt15"
NAME = "observed_straight_arm_rock"
GUARDED = "observed_straight_arm_without_knee_evidence"


def angle(a, b, c):
    ax, ay = a[0] - b[0], a[1] - b[1]
    cx, cy = c[0] - b[0], c[1] - b[1]
    size = math.hypot(ax, ay) * math.hypot(cx, cy)
    if size < 1:
        return 0
    return math.degrees(math.acos(max(-1., min(1., (ax * cx + ay * cy) / size))))


class StraightArmRock:
    def __init__(self):
        self.window = deque()

    def observe(self, ms, joints, width, height):
        observed = joints[11:17]
        if (len(observed) != 6 or
                any(p is None or p[2] < .6 or not (0 <= p[0] < width and 0 <= p[1] < height)
                    for p in observed)):
            self.window.clear()
            return
        a, b, c, d, e, f = observed
        span = math.dist(a[:2], b[:2])
        wrist_span = math.dist(e[:2], f[:2])
        if (span < .07 * min(width, height) or wrist_span < .4 * span
                or max(abs((a[1] - b[1])/span), abs((e[1] - f[1])/wrist_span)) > .5):
            self.window.clear()
            return
        if self.window and (ms - self.window[-1][0] > 250 or ms <= self.window[-1][0]):
            self.window.clear()
        if self.window and ms - self.window[-1][0] < 40:
            return
        elbow = min(angle(a, c, e), angle(b, d, f))
        self.window.append((ms, span / wrist_span, span, (a[1] + b[1])/2, e[:2], f[:2], elbow))
        while ms - self.window[0][0] > 3700:
            self.window.popleft()

    def rocking(self):
        obs = list(self.window)
        if len(obs) < 9:
            return False
        now = obs[-1]
        # Large-scale rock rather than a flexed-arm floor repetition. Both arms
        # remain seen throughout, including three samples around maximal travel.
        for j in range(4, len(obs) - 2):
            bottom = obs[j]
            if min(now[0] - bottom[0], bottom[0] - obs[0][0]) < 160:
                continue
            if bottom[1] > min(o[1] for o in obs[j-1:j+2]):
                continue
            peak = max(obs[:j-2], key=lambda o: o[1])
            if bottom[0] - peak[0] < 250:
                continue
            compression = peak[1] - bottom[1]
            travel = bottom[3] - peak[3]
            if (compression < .29 * peak[1] or travel < .30 * peak[2]
                    or now[1] - bottom[1] < .25 * compression
                    or bottom[3] - now[3] < .56 * travel):
                continue
            relevant = [o for o in obs if o[0] >= peak[0]]
            if (min(o[6] for o in relevant) < 140 or
                    min(o[6] for o in obs[j-1:j+2]) < 150):
                continue
            if any(max(math.dist(o[4], peak[4]), math.dist(o[5], peak[5])) > .20 * peak[2]
                   for o in relevant):
                continue
            return True
        return False


def refine(frames, width, height, events):
    rock = StraightArmRock()
    by_frame = {i: label for i, label in events}
    result = []
    for i, stamp, joints in frames:
        if joints is None:
            rock.window.clear()
            continue
        rock.observe(stamp, joints, width, height)
        old = by_frame.get(i)
        if old:
            result.append([i, "armsStraight" if old == "insufficientDepth" and rock.rocking() else old])
    if len(result) != len(events):
        raise ValueError("Event frame was missing")
    return result


def native_frames(doc):
    for i, f in enumerate(doc["frames"]):
        if f.get("mark") == "abandon" or not f.get("p"):
            yield i, 0, None
        else:
            p = f["p"]
            yield i, f["t"]/1000, [
                [p[j], p[j+1], p[j+3]] if p[j] is not None else None
                for j in range(0, len(p), 4)]


def knee_priority(old, changed, evidence):
    if len(old) != len(evidence):
        raise ValueError("Mismatched production event features")
    return [result if vector[9] == 0 else original
            for original, result, vector in zip(old, changed, evidence)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("benchmark", type=Path)
    p.add_argument("root", type=Path)
    p.add_argument("out", type=Path)
    args = p.parse_args()
    base = args.benchmark
    manifest = read_sources(base / "units.jsonl")
    outputs = read_sources(base / "final-events.jsonl")
    web_features = read_sources(base / "tree-plus-events.jsonl")
    revised = {}
    for r in map(json.loads, (base / "replay.jsonl").open(encoding="utf8")):
        if r["split"] != "development":
            continue
        key = r["source_id"]
        old = outputs[key]["events"][BASE]
        new = refine(r["frames"], r["width"], r["height"], old)
        source_features = web_features[key]
        if old != source_features["events"][BASE]:
            raise ValueError("Need event features from the same backend")
        guarded = knee_priority(old, new, source_features["features"][BASE])
        revised[key] = {"events": {BASE: old, NAME: new, GUARDED: guarded}}
    results = {c: evaluate(manifest, revised, c, {"development"}) for c in (BASE, NAME, GUARDED)}
    changed = {k: [[i, o, p] for (i,o),(_,p) in zip(v["events"][BASE], v["events"][NAME]) if o != p]
               for k,v in revised.items()}
    results["changed"] = {k:v for k,v in changed.items() if v}
    native, guarded_native = {}, {}
    f_features = read_sources(base / "tree-plus-fixtures.jsonl")
    for r in map(json.loads, (base / "final-fixtures.jsonl").open(encoding="utf8")):
        key = r["source_id"]
        folder = args.root / "gymrats_app" / r["suite"]
        path = next(folder.rglob(key + ".json"))
        doc = json.loads(path.read_text(encoding="utf8"))
        first = next(f for f in doc["frames"] if f.get("p"))
        old = r["events"][BASE]
        new = refine(native_frames(doc), first["w"], first["h"], old)
        if new != old:
            native[key] = dict(before=old, after=new)
        guarded = knee_priority(old, new, f_features[key]["features"][BASE])
        if guarded != old:
            guarded_native[key] = dict(before=old, after=guarded)
    results["changed_native_fixtures"] = native
    results["changed_native_knee_priority"] = guarded_native
    args.out.write_text(json.dumps(results, indent=2), encoding="utf8")
    for c in (BASE, NAME, GUARDED):
        s=results[c]
        print(c, s["macro_f1"], s["correct"], s["classes"]["armsStraight"])
    print("Refined development sources:", len(results["changed"]))
    print("Refined native sessions:", list(native))


if __name__ == "__main__":
    main()

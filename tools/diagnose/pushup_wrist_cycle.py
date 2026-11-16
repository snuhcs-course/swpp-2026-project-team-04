"""Development-only ablation: detect reversals in shoulder-to-wrist height."""
import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
import warnings

import numpy as np

from score_pushup_nine import evaluate, match, read_sources
from sklearn.tree import DecisionTreeClassifier


def joint_angle(a, b, c):
    u, v = a - b, c - b
    cosine = (u * v).sum(-1) / (np.linalg.norm(u, axis=-1) * np.linalg.norm(v, axis=-1))
    return np.degrees(np.arccos(np.clip(cosine, -1, 1)))


def signals(points, times):
    p = points[..., :2].copy()
    p[points[:, :, 2] < .55] = np.nan
    shoulders, elbows, wrists = (p[:, [i, i + 1]] for i in (11, 13, 15))
    hips, knees, ankles = (p[:, [i, i + 1]] for i in (23, 25, 27))
    width = np.linalg.norm(shoulders[:, 0] - shoulders[:, 1], axis=1)
    width[width < 2] = np.nan
    shoulder_y = shoulders[:, :, 1].mean(axis=1)
    wrist_y = np.nanmean(wrists[:, :, 1], axis=1)
    hip_y, knee_y = (np.nanmean(k[:, :, 1], axis=1) for k in (hips, knees))
    arm = joint_angle(shoulders, elbows, wrists)
    diagonal = np.degrees(np.arctan2(abs(shoulders[:, 0, 1] - shoulders[:, 1, 1]),
                                     abs(shoulders[:, 0, 0] - shoulders[:, 1, 0])))
    raw = np.column_stack(((wrist_y - shoulder_y) / width,
                           np.nanmean(arm, axis=1), np.nanmin(arm, axis=1), diagonal,
                           np.nanmean(joint_angle(hips, knees, ankles), axis=1),
                           (knee_y - wrist_y) / width, (hip_y - wrist_y) / width,
                           (hip_y - shoulder_y) / width))
    # Time-domain smoothing starts anew after a gap. Missing joints remain
    # missing for the current frame even if an earlier sample was visible.
    out = np.full_like(raw, np.nan)
    state = np.full(raw.shape[1], np.nan)
    last_seen = np.full(raw.shape[1], -np.inf)
    for i, t in enumerate(times):
        visible = np.isfinite(raw[i])
        gap = t - last_seen[visible]
        old = state[visible]
        state[visible] = np.where(gap > .35, raw[i, visible],
                                  old + (1 - np.exp(-gap / .065)) * (raw[i, visible] - old))
        last_seen[visible] = t
        out[i, visible] = state[visible]
    return out


def detect(samples, times, frames, entry):
    """Events close when the observed height recovers or falls again after a rebound."""
    events = []
    top = low = crest = None
    last_good = -math.inf
    last_event = -math.inf
    for i, (t, value) in enumerate(zip(times, samples[:, 0])):
        if not np.isfinite(value):
            continue
        if t - last_good > .35:
            top = low = crest = None
        last_good = t
        if top is None or (low is None and value >= samples[top, 0]):
            top = i
            continue
        if low is None:
            if value > samples[top, 0] - entry:
                # Keep the last top plateau fresh during a long setup.
                if t - times[top] > 3:
                    top = i
                continue
            low = i
            continue
        if t - times[top] > 6 or value < samples[low, 0]:
            if t - times[top] > 6:
                top, low, crest = i, None, None
            else:
                low, crest = i, None
            continue
        depth = samples[top, 0] - samples[low, 0]
        if crest is None or value > samples[crest, 0]:
            crest = i
        recovery = (samples[crest, 0] - samples[low, 0]) / depth
        if recovery < .52 or t - times[low] < .09:
            continue
        restored = recovery >= .83 and samples[i, 1] >= 153
        next_descent = samples[crest, 0] - value >= entry * .65
        plateau = recovery >= .72 and t - times[crest] >= .18
        if not (restored or next_descent or plateau):
            continue
        if t - last_event >= .36 and t - times[top] >= .24:
            region = samples[top:i + 1]
            f = [float(depth), float(recovery), samples[top, 0], samples[low, 0],
                 np.nanmin(region[:, 1]), samples[top, 1], samples[crest, 2],
                 np.nanpercentile(region[:, 3], 80), np.nanmedian(region[:, 4]),
                 np.nanmedian(region[:, 5]), np.nanmax(region[:, 6]),
                 np.nanmin(region[:, 7]), np.nanmax(region[:, 7])]
            events.append((int(frames[top]), int(frames[i]), f))
            last_event = t
        top, low, crest = crest, None, None
    return events


def verdict(features):
    drop, recovery, _, _, min_arm, top_arm, lockout, tilt, knee_angle, knee_gap, hip_gap, torso_low, torso_high = features
    if torso_low > 1.3:
        return "notFloorPushUp"
    if torso_high > 1.1 and -.08 <= hip_gap <= .45:
        return "bellyDown"
    if knee_angle < 148 and knee_gap > -.35:
        return "armsStraight" if min_arm >= 150 else "kneesDown"
    if min_arm >= 157 and drop > .65:
        return "armsStraight"
    if tilt >= 15 and top_arm - min_arm >= 18:
        return "shouldersNotLevel"
    if drop < .52 and not (drop >= .31 and min_arm <= 100):
        return "insufficientDepth"
    if lockout < 153 or recovery < .75:
        return "incompleteExtension"
    return "normal"


def add_supplement(primary, detected, times_by_frame, reject_only):
    """Delay new feedback 250 ms; a primary verdict inside that window wins."""
    combined = list(primary)
    frames = np.array(sorted(times_by_frame))
    t = np.array([times_by_frame[i] for i in frames])
    primary_t = [times_by_frame[x] for x, _ in primary]
    last = -math.inf
    for start, end, label in detected:
        begin, close = times_by_frame[start], times_by_frame[end]
        when = np.searchsorted(t, close + .25)
        if when >= len(t) or t[when] - close > .40:
            continue
        if (reject_only and label == "normal") or t[when] - last < .4:
            continue
        if any(begin - .12 <= at <= t[when] for at in primary_t):
            continue
        combined.append([int(frames[when]), label])
        last = t[when]
    return sorted(combined)


def group_fold(group):
    return int(hashlib.sha256(group.encode()).hexdigest(), 16) % 5


def summarize(manifest, output, key):
    result = evaluate(manifest, output, key, {"development"})
    folds = []
    for fold in range(5):
        subset = {k: v for k,v in manifest.items() if group_fold(v["group_id"]) == fold}
        folds.append(evaluate(subset, output, key, {"development"})["macro_f1"])
    return {k: result[k] for k in ("macro_f1", "accuracy", "correct", "misses", "extras", "classes")} | {"fold_macro_f1": folds}


def compare_native(results, native_primary, primary_name):
    report = {}
    for name in next(iter(results.values()))["events"]:
        extra_on_matching, changed_matching, extra_valid, false_accept = [], [], [], []
        for source, row in native_primary.items():
            primary = row["events"][primary_name]
            events = results[source]["events"][name]
            expected = row["expected"]
            if expected is None:
                continue
            unlabelled = row.get("labelled") is None
            labels = ["normal" if x == "valid" else x for x in row.get("labelled") or []]
            expected_hist = Counter(expected["rejected"])
            expected_hist["normal"] = expected["valid"]
            original = [c for _,c in primary]
            candidate = [c for _,c in events]
            matches = original == labels if not unlabelled else Counter(original) == expected_hist
            if matches:
                if len(candidate) > len(original):
                    extra_on_matching.append(source)
                if original != candidate:
                    changed_matching.append(source)
            if candidate.count("normal")>original.count("normal"):
                extra_valid.append(source)
                if expected["valid"] == 0:
                    false_accept.append(source)
        report[name]={"more_valid_sets":extra_valid,"new_false_counts_on_invalid_sets":false_accept,
                      "more_events_on_previously_correct_sets":extra_on_matching,
                      "verdict_change_on_previously_correct_sets":changed_matching}
    return report


def process(name, times, frames, points, base, target):
    samples = signals(points, times)
    events = {"primary": base}
    by_frame = dict(zip(frames, times))
    event_features = {}
    for entry in (.16, .23, .31):
        det = detect(samples, times, frames, entry)
        labelled = [(first,last,verdict(f)) for first,last,f in det]
        suffix = str(round(entry*100))
        events["wrist"+suffix] = [[last,label] for _,last,label in labelled]
        if suffix == "23":
            event_features["wrist23"] = [f for _, _, f in det]
        events["add_reject"+suffix] = add_supplement(base,labelled,by_frame,True)
        events["add_all"+suffix] = add_supplement(base,labelled,by_frame,False)
    event_features["primary"] = []
    for end, original in base:
        i = np.searchsorted(frames,end)
        # Both windows stop at the actual production event, without using
        # later recovery or a reference interval. Include the original reason.
        feature = [float(original == label) for label in
                   ("insufficientDepth", "shouldersNotLevel", "kneesDown", "incompleteExtension")]
        for duration in (.65, 1.65):
            start = np.searchsorted(times[:i+1], times[i] - duration)
            region = samples[start:i+1]
            upper, lower = np.nanpercentile(region[:,0],[90,10])
            feature.extend((upper-lower, samples[i,0]-lower,
                            np.nanmin(region[:,1]), samples[i,2],
                            np.nanpercentile(region[:,3],80), np.nanmedian(region[:,4]),
                            np.nanmedian(region[:,5]), np.nanmax(region[:,6]),
                            np.nanmin(region[:,7]), np.nanmax(region[:,7])))
        event_features["primary"].append(feature)
    target[name] = {"events":events,"feature":event_features}


def training_rows(manifest, outputs, event_source):
    features, labels, folds = [], [], []
    protected = {"bellyDown","notFloorPushUp","phoneMoved"}
    for key, source in manifest.items():
        units = sorted((u for u in source["units"] if not u.get("confirmed_duplicate_of")),
                       key=lambda u:(u["end"],u["start"],u["unit_id"]))
        events = outputs[key]["events"][event_source]
        pairs, _ = match(units, events, source["fps"])
        for ui, ei in pairs.items():
            truth = units[ui]["label"]
            if not truth or truth in protected or events[ei][1] in protected:
                continue
            if event_source=="primary" and (truth=="normal" or events[ei][1]=="normal"):
                continue
            features.append(outputs[key]["feature"][event_source][ei])
            labels.append(truth)
            folds.append(group_fold(source["group_id"]))
    return np.nan_to_num(features,nan=-999.), np.array(labels),np.array(folds)


def predict_tree(model, collection, keys, event_source, name, cutoff, rule="all"):
    protected = {"bellyDown","notFloorPushUp","phoneMoved"}
    if event_source=="primary":
        protected.add("normal")
    for key in keys:
        row = collection[key]
        base = row["events"][event_source]
        new = [list(e) for e in base]
        if new:
            x = np.nan_to_num(row["feature"][event_source],nan=-999.)
            prob = model.predict_proba(x)
            predictions = model.classes_[prob.argmax(axis=1)]
            for i, predicted in enumerate(predictions):
                allowed_source = rule=="all" or (base[i][1]=="insufficientDepth" or
                          rule.startswith("weak") and base[i][1]=="shouldersNotLevel")
                f=row["feature"][event_source][i]
                evidence = (predicted=="shouldersNotLevel" and max(f[8],f[18]) >= 10 or
                            predicted=="kneesDown" and
                            (f[9] < 145 and f[10] > -.65 or f[19] < 145 and f[20] > -.65) or
                            predicted=="incompleteExtension" and min(f[7],f[17])<155 or
                            predicted=="armsStraight" and min(f[6],f[16])>=148 or
                            predicted=="insufficientDepth") if rule.endswith("evidence") else True
                if rule.endswith("visible"):
                    evidence = (predicted=="shouldersNotLevel" and max(f[8],f[18])>=8 or
                                predicted=="kneesDown" and (f[9]<150 or f[19]<150 or
                                  -.22 <= f[10] <= .45 or -.22 <= f[20] <= .45) or
                                predicted=="incompleteExtension" and min(f[7],f[17])<165 or
                                predicted=="armsStraight" and min(f[6],f[16])>=145 or
                                predicted=="insufficientDepth")
                if allowed_source and evidence and base[i][1] not in protected and np.max(prob[i])>=cutoff:
                    new[i][1] = str(predicted)
        row["events"][name] = new


def learn(manifest, results, native):
    for event_source in ("wrist23","primary"):
        x,y,folds = training_rows(manifest,results,event_source)
        for depth in (2,4):
            for cutoff in (.65,.85):
                for fold in range(6):
                    fitting = folds!=fold
                    model=DecisionTreeClassifier(max_depth=depth,min_samples_leaf=20,
                                                 class_weight="balanced",random_state=19)
                    model.fit(x[fitting],y[fitting])
                    keys = native if fold == 5 else [
                        k for k,v in manifest.items() if group_fold(v["group_id"])==fold]
                    for rule in (("all", "shallow", "shallow_evidence", "weak_evidence","shallow_visible")
                                 if event_source == "primary" else ("all",)):
                        name = f"{event_source}_tree{depth}_p{int(cutoff*100)}_{rule}"
                        predict_tree(model,native if fold==5 else results,keys,event_source,name,cutoff,rule)


def run(args):
    root = args.root
    manifest = {k:v for k,v in read_sources(root/'units.jsonl').items() if v["split"]=="development"}
    primary = read_sources(root/args.events)
    results = {}
    with (root / 'replay.jsonl').open(encoding='utf-8') as f:
        for line in f:
            source=json.loads(line)
            if source["source_id"] not in manifest:
                continue
            key=source["source_id"]
            frames=source["frames"]
            points=np.array([[(np.nan, np.nan, 0) if p is None else p for p in fr[2]] for fr in frames])
            process(key,np.array([fr[1]/1000 for fr in frames]),[fr[0] for fr in frames],
                    points,primary[key]["events"][args.primary],results)
    native = read_sources(root/args.fixtures)
    native_results = {}
    for folder in ('test/fixtures/pushup_cases','test/ai_eval/cases'):
        for path in (args.app/folder).rglob('*.json'):
            with path.open(encoding="utf-8-sig") as f:
                doc=json.load(f)
            key=doc["id"]; frames=doc["frames"]
            points=np.full((len(frames),33,3),np.nan)
            for i,frame in enumerate(frames):
                if frame.get("p"):
                    points[i]=np.asarray(frame["p"],dtype=float).reshape(33,4)[:,[0,1,3]]
            times=np.array([fr["t"]/1e6 for fr in frames])
            process(key,times,list(range(len(frames))),points,native[key]["events"][args.primary],native_results)
    learn(manifest,results,native_results)
    report = {"development": {name:summarize(manifest, results, name)
                             for name in next(iter(results.values()))["events"]}}
    report["fixtures"]=compare_native(native_results,native,args.primary)
    args.output.write_text(json.dumps(report,indent=2),encoding='utf-8')
    for name,score in report["development"].items():
        safety=report["fixtures"][name]
        print(name,round(score["macro_f1"],4),score["correct"],score["misses"],score["extras"],
              {k:len(v) for k,v in safety.items()})


if __name__=="__main__":
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument("--root",required=True,type=Path)
    parser.add_argument("--app",type=Path,default=Path("gymrats_app"))
    parser.add_argument("--events",default="final-events.jsonl")
    parser.add_argument("--fixtures",default="final-fixtures.jsonl")
    parser.add_argument("--primary",default="small30_elev60_knees_tilt15")
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore",category=RuntimeWarning)
        run(args)

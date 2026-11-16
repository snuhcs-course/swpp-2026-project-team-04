"""Train rejection feedback on observed development cycles using source-separated folds.

Input windows are produced causally before looking at interval labels. Train and
score only once per development source and cycle. The companion Dart extractor
produces exactly the runtime feature vector. The classifier never awards a rep.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.tree import DecisionTreeClassifier

from score_pushup_nine import LABELS, evaluate, match, read_sources
from assess_pushup_span_cycles import eligible, read_clocks

SIGNALS = ("elbow", "weakerElbow", "elbowDifference", "shoulderTilt", "hipAngle",
           "kneeAngle", "handShoulderY", "handShoulderX", "hipShoulderY",
           "hipShoulderX", "kneeWristY", "ankleKneeY", "hipWristY",
           "noseShoulderY", "wristWidth", "shoulderWidth")
STATS = ("low", "high", "middle", "start", "bottom", "finish")
REASONS = LABELS[1:6]
MISSING = -999.0


def feature(values, name, stat):
    return values[SIGNALS.index(name) * len(STATS) + STATS.index(stat)]


def supported(reason, x):
    # A leaf can use other correlated joints, but the named fault must be
    # independently visible on the joints that describe it.
    if reason == "incompleteExtension":
        top = feature(x, "elbow", "finish")
        return top is not None and top < 170
    if reason == "shouldersNotLevel":
        tilt = feature(x, "shoulderTilt", "high")
        return tilt is not None and tilt >= 7
    if reason == "kneesDown":
        angle = feature(x, "kneeAngle", "low")
        gap = feature(x, "kneeWristY", "high")
        return (angle is not None and angle < 150) or (gap is not None and abs(gap) <= 0.45)
    if reason == "armsStraight":
        elbow = feature(x, "elbow", "low")
        return elbow is not None and elbow > 144
    if reason == "insufficientDepth":
        top = feature(x, "handShoulderY", "start")
        down = feature(x, "handShoulderY", "bottom")
        elbow = feature(x, "elbow", "low")
        return top is not None and down is not None and 0.035 <= top-down < 0.49 and elbow is not None and 80 < elbow < 165
    return False


def records_for(manifest, cycles, evidence, preset):
    result = []
    for key, source in manifest.items():
        if source["split"] != "development":
            raise ValueError("The trainer accepts only the development manifest")
        units = sorted((u for u in source["units"] if not u.get("confirmed_duplicate_of")),
                       key=lambda u: (u["end"], u["start"], u["unit_id"]))
        ws = cycles[key]["windows"][preset]
        pairs, _ = match(units, [(w[2], "") for w in ws], source["fps"])
        truths = {j: units[i]["label"] for i, j in pairs.items()}
        for j, w in enumerate(ws):
            values = evidence[key]["evidence"][",".join(map(str, w))]
            if values is not None:
                result.append((source["group_id"], key, w, values, truths.get(j)))
    return result


def train(records, depth, leaf, exponent):
    labelled = [r for r in records if r[4] is not None]
    ys = [r[4] for r in labelled]
    counts = Counter(ys)
    model = DecisionTreeClassifier(max_depth=depth, min_samples_leaf=leaf,
            class_weight={k: (len(ys)/n)**exponent for k, n in counts.items()}, random_state=37)
    model.fit([[MISSING if v is None else v for v in r[3]] for r in labelled], ys)
    tree, nodes = model.tree_, []
    for k, f in enumerate(tree.feature):
        if f < 0:
            label = str(model.classes_[np.argmax(tree.value[k])])
            nodes.append({"label": label})
        else:
            nodes.append({"feature": int(f), "threshold": round(float(tree.threshold[k]), 6),
                          "left": int(tree.children_left[k]), "right": int(tree.children_right[k])})
    return nodes


def predict(nodes, values):
    reason = nodes[leaf_for(nodes, values)]['label']
    return reason if supported(reason, values) else None


def leaf_for(nodes, values):
    n = 0
    while "feature" in nodes[n]:
        node = nodes[n]
        val = values[node["feature"]]
        n = node["left"] if (MISSING if val is None else val) <= node["threshold"] else node["right"]
    return n


def veto_fixture_leaves(nodes, fixture_values):
    # These leaves would emit an additional rejection in a recorded phone
    # scenario. Preserve that scenario, including evidence interruptions.
    for values in fixture_values:
        leaf = leaf_for(nodes, values)
        label = nodes[leaf]["label"]
        if supported(label, values):
            nodes[leaf]["label"] = "abstain"


def eligible_items(cycles, evidence, primary, clocks, preset, delay, quiet):
    data = {}
    for sid in clocks:
        ws = cycles[sid]["windows"][preset]
        old = primary[sid]["events"]["app_default"]
        # Ask the causal arbitrator about each window independently; a window
        # at which the classifier abstains never starts its 400 ms cooldown.
        candidates = []
        open_at = dict(cycles[sid]["primary_open"])
        for i,w in enumerate(ws):
            delivery = eligible([w], old, clocks[sid], delay, quiet)
            if delivery and open_at.get(delivery[0][1], float("inf")) > w[2]:
                values = evidence[sid]["evidence"][",".join(map(str,w))]
                if values is not None:
                    frame = delivery[0][1]
                    candidates.append((i,frame,clocks[sid][frame],values))
        data[sid] = candidates
    return data


def fuse(manifest, data, primary, predictor):
    out = {}
    for k,info in manifest.items():
        before = primary[k]["events"]["app_default"]
        preds, last = [], -10**18
        for i,f,t,x in data[k]:
            if t-last < 400000:
                continue
            reason = predictor(info,k,i,x)
            if reason is not None:
                preds.append([f,reason])
                last=t
        out[k] = {"source_id":k,"events":{"fused":sorted(before+preds),"added":preds}}
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", required=True,type=Path)
    p.add_argument("--out", required=True,type=Path)
    p.add_argument("--preset", default="0.12")
    p.add_argument("--delay-ms", type=int, default=0)
    p.add_argument("--quiet-ms", type=int, default=0)
    p.add_argument("--window-prefix", default="span-owner-windows")
    args=p.parse_args()
    base=args.root
    manifest=read_sources(base/"native-development"/"units.jsonl")
    cycles=read_sources(base/f"{args.window_prefix}-development.jsonl")
    evidence=read_sources(base/"span-final-evidence-development.jsonl")
    primary=read_sources(base/"native-final"/"shipping.jsonl")
    clocks=read_clocks(base/"native-development"/"replay.jsonl")
    fixtures=read_sources(base/"native-winner-frozen.jsonl")
    fws=read_sources(base/f"{args.window_prefix}-fixtures.jsonl")
    fvs=read_sources(base/"span-final-evidence-fixtures.jsonl")
    fclocks=read_clocks(base/"span-source-fixtures.jsonl")
    preset=args.preset
    records=records_for(manifest,cycles,evidence,preset)
    factors=(preset,args.delay_ms*1000,args.quiet_ms*1000)
    data=eligible_items(cycles,evidence,primary,clocks,*factors)
    native=eligible_items(fws,fvs,fixtures,fclocks,*factors)
    fixture_values=[v for samples in native.values() for _,_,_,v in samples]
    groups=sorted({r["group_id"] for r in manifest.values()},
                  key=lambda g:hashlib.sha256(("gymrats-fold-5/"+g).encode()).digest())
    folds={g:i%5 for i,g in enumerate(groups)}
    args.out.mkdir(exist_ok=True,parents=True)
    ranks, fitted, all_predictions=[],{},{}
    for depth,leaf,exp in [(d,l,e) for d,l in ((2,20),(3,15),(4,12),(5,16),(6,12)) for e in (.25,.65,1)]:
        name=f"tree{depth}_leaf{leaf}_balance{exp}"
        trees=[train([r for r in records if folds[r[0]]!=k],depth,leaf,exp) for k in range(5)]
        model=train(records,depth,leaf,exp)
        for tr in trees+[model]:
            veto_fixture_leaves(tr,fixture_values)
        preds=fuse(manifest,data,primary,lambda r,k,i,x:predict(trees[folds[r["group_id"]]],x))
        score=evaluate(manifest,preds,"fused",{"development"})
        c = score["confusion"]
        normal_total = score["classes"]["normal"]["support"]
        invalid_total = score["labelled"] - normal_total
        invalid_right = sum(c[a][b] for a in LABELS[1:] for b in LABELS[1:])
        normal_recall = c["normal"]["normal"]/normal_total
        invalid_recall = invalid_right/invalid_total
        ranks.append({"name":name,"binary_balanced":(normal_recall+invalid_recall)/2,
                      "normal_recall":normal_recall,"invalid_recall":invalid_recall,
                      "macro":score["macro_f1"],"micro":score["micro_f1"],
                      "correct":score["correct"],"misses":score["misses"],"extras":score["extras"],
                      "invalid_counted":score["invalid_reps_counted"],"classes":score["classes"]})
        fitted[name]=model
        all_predictions[name]=preds
    ranks.sort(key=lambda r:(r["binary_balanced"],r["macro"],r["micro"]),reverse=True)
    winner=ranks[0]["name"]
    model=fitted[winner]
    result={"preset":preset,"delivery_delay_ms":args.delay_ms,"primary_quiet_ms":args.quiet_ms,
            "development_groups":len(groups),"records":len(records),
            "development_labels":dict(Counter(r[4] or "unmatched_or_unlabelled" for r in records)),
            "fusion_eligible_windows":sum(map(len,data.values())),"native_gating_windows":len(fixture_values),
            "ranking":ranks,"winner":winner,"nodes":model,"signals":SIGNALS,"statistics":STATS,"missing":MISSING}
    (args.out/"model.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf8")
    (args.out/"tree-body.dart.txt").write_text(dart_tree(model)+"\n", encoding="utf8")
    with (args.out/"out-of-fold.jsonl").open("w",encoding="utf8") as fp:
        for output in all_predictions[winner].values():
            fp.write(json.dumps(output)+"\n")
    print(winner,{k:v for k,v in ranks[0].items() if k!="classes"},result["native_gating_windows"])


def dart_tree(nodes):
    """Compact the tree and emit ordinary Dart branches with named signals."""
    def compact(i):
        n=nodes[i]
        if "label" in n:
            return "null" if n["label"] not in REASONS else "RejectReason."+n["label"]
        left,right=compact(n["left"]),compact(n["right"])
        return left if left==right else (n["feature"],n["threshold"],left,right)
    def emit(n,indent):
        space="  "*indent
        if isinstance(n,str):
            return [space+"return "+n+";"]
        idx,threshold,left,right=n
        sig,stat=divmod(idx,len(STATS))
        cond=f"value(PushupSpanSignal.{SIGNALS[sig]}, PushupSpanStat.{STATS[stat]}) <= {threshold}"
        return [space+"if ("+cond+") {",*emit(left,indent+1),space+"}",*emit(right,indent)]
    return "\n".join(emit(compact(0),2))


if __name__ == "__main__":
    main()

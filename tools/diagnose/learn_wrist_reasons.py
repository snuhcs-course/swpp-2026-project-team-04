"""Fit grouped, rejection-only wrist-window feedback; preserve all native fixture events."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.tree import DecisionTreeClassifier

from score_pushup_nine import evaluate, match, read_sources

DEFAULT_BASE = "small30_elev60_knees_tilt15"


def supports(label, features, evidence):
    if label == "kneesDown":
        return features[27] >= 3 if evidence == "strict" else max(features[24:26]) >= 3
    if label == "shouldersNotLevel":
        return features[28 if evidence == "strict" else 26] >= 3
    return False


def terminal(model, features):
    nodes = model["nodes"]
    i = 0
    while nodes[i][0] != -1:
        col, cut, left, right = nodes[i]
        x = features[col] if features[col] is not None else -999
        i = left if x <= cut else right
    return i


def label_candidate(old, model, features):
    if old != "insufficientDepth":
        return old
    _, label, confidence = model["nodes"][terminal(model, features)]
    if confidence >= model["confidence"] and supports(label, features, model["evidence"]):
        return label
    return old


def events(row, model, base_name=DEFAULT_BASE):
    base, features = row["events"][base_name], row["wrist_features"]
    if len(base) != len(features) or any(len(f) != 29 for f in features):
        raise ValueError("Unexpected event count or wrist feature schema")
    return [[frame, label_candidate(old, model, f)] for (frame,old),f in zip(base,features)]


def records(manifest, rows, task, evidence, base_name):
    examples = []
    for key, r in manifest.items():
        units = sorted((u for u in r["units"] if not u.get("confirmed_duplicate_of")),
                       key=lambda u: (u["end"],u["start"],u["unit_id"]))
        base = rows[key]["events"][base_name]
        matches, _ = match(units, base, r["fps"])
        for ui, ei in matches.items():
            original = base[ei][1]
            if original in {"normal","bellyDown","notFloorPushUp","phoneMoved"}:
                continue
            truth = units[ui]["label"]
            if truth is None or truth in {"bellyDown","notFloorPushUp","phoneMoved"}:
                continue
            f = rows[key]["wrist_features"][ei]
            if task == "eligible":
                if original != "insufficientDepth":
                    continue
                truth = truth if supports(truth, f, evidence) else "keep"
            elif truth == "normal":
                continue
            examples.append((r["group_id"],[v if v is not None else -999 for v in f[:24]],truth))
    return examples


def fit(examples, evidence, depth, cutoff, fixtures, base_name):
    x = [e[1] for e in examples]
    y = [e[2] for e in examples]
    estimator = DecisionTreeClassifier(max_depth=depth,min_samples_leaf=20,
                                       class_weight="balanced",random_state=19)
    estimator.fit(np.array(x),y)
    t = estimator.tree_
    nodes = []
    for i in range(t.node_count):
        if t.children_left[i] != t.children_right[i]:
            nodes.append([int(t.feature[i]),float(t.threshold[i]),int(t.children_left[i]),int(t.children_right[i])])
        else:
            weights = t.value[i].flatten()
            winner = weights.argmax()
            nodes.append([-1,str(estimator.classes_[winner]),float(weights[winner]/weights.sum())])
    model = dict(nodes=nodes,evidence=evidence,confidence=cutoff)
    banned = set()
    for r in fixtures.values():
        for (_,old),f in zip(r["events"][base_name],r["wrist_features"]):
            if label_candidate(old, model, f) != old:
                banned.add(terminal(model,f))
    for i in banned:
        nodes[i][1]="keep"
    model["vetoed_native_leaves"]=sorted(banned)
    return model


def write(path,rows):
    with path.open("w",encoding="utf-8") as stream:
        for row in rows:
            stream.write(json.dumps(row, allow_nan=False, separators=(",",":"))+"\n")


def combine(args, models, trained, refit, native_fixtures):
    base_name = args.base
    heldout = read_sources(args.heldout_features)
    if trained.keys() & heldout.keys():
        raise ValueError("Repeated source between OOF and inference splits")
    for key, row in heldout.items():
        output = dict(source_id=key,events={base_name:row["events"][base_name]})
        for name, model in models.items():
            output["events"][name] = events(row,model,base_name)
        trained[key] = refit[key] = output
    merged=args.out/"merged"
    merged.mkdir(exist_ok=True)
    reference=read_sources(args.append_to/"events-with-trees.jsonl")
    for key, row in trained.items():
        if reference[key]["events"][base_name] != row["events"][base_name]:
            raise ValueError(f"{key}: computed wrist features belong to a different base run")
    for filename, extra in (("events-with-trees.jsonl",trained),("refit-events.jsonl",refit),
                            ("fixtures-with-trees.jsonl",native_fixtures)):
        incumbents=read_sources(args.append_to/filename)
        if incumbents.keys()!=extra.keys():
            raise ValueError(f"{filename}: original inventories differ")
        for key, new in extra.items():
            old=incumbents[key]
            baseline=new["events"][base_name]
            if base_name in old["events"] and old["events"][base_name]!=baseline:
                raise ValueError(f"{key}: base events differ in {filename}")
            for name in models:
                output=new["events"][name]
                if name in old["events"]:
                    raise ValueError(f"Refusing to replace {name}")
                old["events"][name]=output
                if filename.startswith("fixtures"):
                    if output!=baseline:
                        raise ValueError(f"{name}: changed native verdict in {key}")
                    for group in ("safety","tally"):
                        if base_name in old.get(group,{}):
                            old[group][name]=old[group][base_name]
        write(merged/filename,incumbents.values())


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ("units","features","fixture-features","out"):
        p.add_argument("--"+key,type=Path,required=True)
    p.add_argument("--base", default=DEFAULT_BASE, help="Name of the judge that emitted the input wrist features")
    p.add_argument("--append-to",type=Path,help="Prior comparison folder to extend in OUT/merged")
    p.add_argument("--heldout-features",type=Path,help="Unlabelled held-out pose features; required with --append-to")
    args=p.parse_args()
    base_name=args.base
    if bool(args.append_to)!=bool(args.heldout_features):
        p.error("--append-to and --heldout-features must be used together")
    rows=read_sources(args.features)
    fixtures=read_sources(args.fixture_features)
    manifest={k:r for k,r in read_sources(args.units).items() if r["split"]=="development"}
    if rows.keys()!=manifest.keys():
        raise ValueError("Supply feature rows for the development split only")
    groups=sorted({r["group_id"] for r in manifest.values()},
                  key=lambda g:hashlib.sha256(("gymrats-fold-5/"+g).encode()).digest())
    fold={g:i%5 for i,g in enumerate(groups)}
    models,stats={},{}
    cvout={k:dict(source_id=k,events={base_name:r["events"][base_name]}) for k,r in rows.items()}
    refit={k:dict(source_id=k,events={base_name:r["events"][base_name]}) for k,r in rows.items()}
    fixture_out={k:dict(source_id=k,events={base_name:r["events"][base_name]}) for k,r in fixtures.items()}
    for task in ("all","eligible"):
        for evidence in ("soft","strict"):
            data=records(manifest,rows,task,evidence,base_name)
            for depth,cutoff in ((2,.65),(4,.65),(4,.85)):
                name=f"tree_wrist_{task}_{evidence}_d{depth}_p{round(cutoff*100)}"
                final=fit(data,evidence,depth,cutoff,fixtures,base_name)
                cv=[fit([r for r in data if fold[r[0]]!=i],evidence,depth,cutoff,fixtures,base_name)
                    for i in range(5)]
                models[name]=final
                for k,r in rows.items():
                    cvout[k]["events"][name]=events(r,cv[fold[manifest[k]["group_id"]]],base_name)
                    refit[k]["events"][name]=events(r,final,base_name)
                for k,r in fixtures.items():
                    results=events(r,final,base_name)
                    if results!=r["events"][base_name]:
                        raise ValueError(f"{name}: changed fixture {k}")
                    fixture_out[k]["events"][name]=results
                metrics=evaluate(manifest,cvout,name,{"development"})
                stats[name]={k:metrics[k] for k in ("macro_f1","micro_f1","correct","misses","extras","classes")}
                stats[name]["fit_labels"]=dict(Counter(r[2] for r in data))
                print(name,round(metrics["macro_f1"],5),metrics["correct"],"vetoed",final["vetoed_native_leaves"])
    args.out.mkdir(parents=True,exist_ok=True)
    (args.out/"wrist-models.json").write_text(json.dumps(dict(base=base_name,models=models),indent=2,allow_nan=False),encoding="utf-8")
    (args.out/"wrist-dev-scores.json").write_text(json.dumps(stats,indent=2,allow_nan=False),encoding="utf-8")
    write(args.out/"wrist-oof.jsonl",cvout.values())
    write(args.out/"wrist-refit.jsonl",refit.values())
    write(args.out/"wrist-fixtures.jsonl",fixture_out.values())
    if args.append_to:
        combine(args,models,cvout,refit,fixture_out)


if __name__=="__main__":
    main()

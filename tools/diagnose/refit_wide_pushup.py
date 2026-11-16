"""Re-fit the already selected proposal MLP and compare native safety with real app events."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import numpy as np
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from pushup_span_mlp import collect, make_network, on_phone, sample_weights
from score_pushup_nine import read_sources
from infer_pushup_mlp import ExportedBinaryMlp


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("root",type=Path)
    p.add_argument("result",type=Path)
    p.add_argument("--target",choices=["binary","reasons"],required=True)
    p.add_argument("--export",action="store_true")
    args=p.parse_args()
    root,result=args.root,args.result
    manifest=read_sources(root/"native-all/units.jsonl")
    events=read_sources(result/"proposals.jsonl")
    features,rows=collect(root/"native-all/replay.jsonl",manifest,events,"stream")
    train_ids=[i for i,r in enumerate(rows) if r[1]=="development" and r[4]]
    x=features[train_ids]
    y=np.array(["invalid" if args.target=="binary" and rows[i][4]!="normal" else rows[i][4] for i in train_ids])
    old=json.loads((result/f"stream-{args.target}-results.json").read_text())
    config=old["validation_ranking"][0]
    scaler=StandardScaler().fit(x)
    model=make_network(config["layers"])
    scaled=scaler.transform(x).clip(-6,6)
    with threadpool_limits(limits=1):
        weights=sample_weights(y,config["balance"])
        for _ in range(config["epochs"]):
            model.partial_fit(scaled,y,classes=np.unique(y),sample_weight=weights)
        if args.export:
            if args.target != "binary":
                raise ValueError("This export schema is for the binary network")
            target=result/"binary-model.npz"
            saved=dict(format=np.array("gymrats-span-binary-mlp-v1"),
                       mean=scaler.mean_,scale=scaler.scale_,classes=model.classes_,
                       layers=np.array(len(model.coefs_)))
            saved.update({f"weights_{i}":m for i,m in enumerate(model.coefs_)})
            saved.update({f"biases_{i}":m for i,m in enumerate(model.intercepts_)})
            np.savez_compressed(target,**saved)
            exported=ExportedBinaryMlp(target)
            held=[i for i,r in enumerate(rows) if r[1]=="holdout"]
            labels,probs=exported.predict(features[held])
            native=model.predict(scaler.transform(features[held]).clip(-6,6))
            if not np.array_equal(labels,native):
                raise AssertionError("Exported network predictions differ from refit")
            expected={}
            with (result/"stream-binary-predictions.csv").open(newline="",encoding="utf8") as fp:
                for row in csv.DictReader(fp):
                    expected[row["source_id"],int(row["end_frame"])]=row["mlp"]
            if len(expected)!=len(held):
                raise AssertionError("Original holdout proposal inventory differs")
            for i,label in zip(held,labels):
                if expected[rows[i][0],rows[i][3]]!=label:
                    raise AssertionError("Export differs from frozen original holdout prediction")
            probability_error=float(np.max(np.abs(probs-model.predict_proba(
                scaler.transform(features[held]).clip(-6,6))[:,1])))
            spec=dict(format="gymrats-span-binary-mlp-v1",classes=list(model.classes_),
                      decision="normal if sigmoid probability > 0.5, otherwise invalid",
                      features=int(features.shape[1]),layers=config["layers"],
                      activation="relu",output="sigmoid",selected_hyperparameters=config,
                      scaler="in-place float32 StandardScaler, then clip -6..6",
                      input="upright original-image 2D ML Kit joints (x,y,likelihood), source-timed",
                      window="preceding 1600 ms ending at causal proposal; starts after previous proposal",
                      proposals=dict(span_minimum=.06,soft_joint_threshold=.095,causal_cooldown_ms=800),
                      pooling="six temporal medians, 90-10 percentile travel, joint visibility, duration",
                      sensor="recorded phone angles unavailable in video training; no inferred angle input",
                      verified_original_holdout_predictions=len(held),
                      export_label_mismatches=0,maximum_probability_error=probability_error,
                      model_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                      status="offline experiment; native phone regressions disqualify app deployment",
                      known_native_new_critical_acceptances=70,
                      known_native_extra_normal_events=62,
                      inference_command="python tools/diagnose/infer_pushup_mlp.py MODEL.npz REPLAY.jsonl PROPOSALS.jsonl OUTPUT.jsonl",
                      inference_dependencies=["numpy", "scipy", "scikit-learn", "threadpoolctl"])
            (result/"binary-model.json").write_text(json.dumps(spec,indent=2)+"\n")
            print("Exported",target,"verified",len(held),"original heldout predictions",flush=True)
            return
        checked=on_phone(root/"span-source-fixtures.jsonl",result/"fixtures-proposals.jsonl",
                         model,scaler,baseline=root/"native-winner-frozen.jsonl")
    old["phone_fixture_checks"]=checked
    old["phone_baseline"]=str(root/"native-winner-frozen.jsonl")
    (result/f"stream-{args.target}-results.json").write_text(json.dumps(old,indent=2)+"\n")
    print(args.target,"extra",checked["extra_counted"],"new critical",len(checked["new_critical_accepts"]),
          "native",checked["mlp"]["balanced_accuracy"],flush=True)


if __name__=="__main__":
    main()

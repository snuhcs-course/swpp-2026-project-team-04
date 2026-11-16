"""Fit compact grouped binary calibration of soft primary verdicts from 2D spans."""
import argparse
from collections import Counter
import hashlib,json
from pathlib import Path
import numpy as np
from sklearn.tree import DecisionTreeClassifier
from score_pushup_nine import LABELS, read_sources, match, evaluate


SOFT=("normal","insufficientDepth","shouldersNotLevel","incompleteExtension")


def inputs(rows,units=None):
    meta=[]; vals=[]; gates=[]; folds=[]; y=[]
    for key,row in rows.items():
        expected={}
        if units is not None:
            source=units[key]
            attempts=sorted((u for u in source["units"] if not u.get("confirmed_duplicate_of")),
                            key=lambda u:(u["end"],u["start"],u["unit_id"]))
            matched,_=match(attempts,[e[:2] for e in row["primary"]],source["fps"])
            expected={j:attempts[i]["label"] for i,j in matched.items()}
            fold=int(hashlib.sha256(source["group_id"].encode()).hexdigest(),16)%5
        else: fold=-1
        for j,(frame,reason,raw,observed_return) in enumerate(row["primary"]):
            if raw is None or reason not in SOFT: continue
            x=np.array(raw,dtype=float).reshape(-1,6)
            mean,weak,_,tilt,hip,knee,hand,_,torso,_,kw,ak,hw,*_=x
            # The visible weaker arm must extend and then reopen, and the mean
            # must show flexion rather than a bob of the head.
            traveled=hand[1]-hand[0]
            both=weak[1]>=157 and mean[0]<=140 and mean[1]-mean[0]>=20
            if reason=="incompleteExtension": both=both and weak[5]>=168
            support=(hand[1]>=.35 and traveled>=.10 and torso[2]<=.75 and
                     (not np.isfinite(tilt[2]) or tilt[2]<=13) and
                     (not np.isfinite(hip[2]) or hip[2]>=140) and
                     (not np.isfinite(knee[2]) or knee[2]>=140))
            loose=both and support and observed_return
            tighter=loose and weak[1]>=165 and mean[0]<=124 and traveled>=.18
            down=None
            if tilt[1]>=15 and x[15,2]>=.28: down="shouldersNotLevel"
            elif knee[2]<140 and hip[2]<147 and -.50<kw[2]<.30: down="kneesDown"
            elif weak[1]<160 and mean[1]-mean[0]>=22: down="incompleteExtension"
            elif traveled<=.21 and mean[0]>=125: down="insufficientDepth"
            gates.append([loose,tighter,down]);meta.append((key,frame,reason))
            vals.append(np.r_[np.nan_to_num(x.flatten(),nan=-999.),SOFT.index(reason)])
            truth=expected.get(j); y.append(1 if truth=="normal" else 0 if truth else -1)
            folds.append(fold)
    return meta,np.array(vals),gates,np.array(folds),np.array(y)


def choices(model,dev,native,indices,guard,up_cut,down_cut):
    lm,lv,lg,_,_=native
    leaves=model.apply(lv)
    forbidden=[set(),set()]
    for (k,f,orig),gate,leaf in zip(lm,lg,leaves):
        if gate[guard] and orig!="normal": forbidden[1].add(int(leaf))
        if gate[2] and orig=="normal": forbidden[0].add(int(leaf))
    meta,v,gates,_,_=dev
    prob=model.predict_proba(v[indices])[:,list(model.classes_).index(1)]
    leaves=model.apply(v[indices])
    changes=[]
    for i,p,leaf in zip(indices,prob,leaves):
        reason=meta[i][2]; gate=gates[i]
        if reason!="normal" and gate[guard] and p>=up_cut and leaf not in forbidden[1]:
            changes.append((i,"normal"))
        elif reason=="normal" and gate[2] and 1-p>=down_cut and leaf not in forbidden[0]:
            changes.append((i,gate[2]))
    return changes,forbidden


def metrics(score):
    mx=score["confusion"]; n=score["classes"]["normal"]["support"]; faults=score["labelled"]-n
    v=mx["normal"]["normal"]
    inv=sum(mx[t][p] for t in LABELS[1:] for p in LABELS[1:])
    return dict(normal=v,invalid=inv,invalid_as_valid=score["invalid_reps_counted"],
                binary_balanced=(v/n+inv/faults)/2,macro=score["macro_f1"])


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root",type=Path); ap.add_argument("output",type=Path)
    args=ap.parse_args(); base=args.root
    units=read_sources(base/"native-development/units.jsonl")
    rows=read_sources(base/"span-complete-primary-development.jsonl")
    fixtures=read_sources(base/"span-complete-primary-fixtures.jsonl")
    dev=inputs(rows,units); native=inputs(fixtures); meta,x,g,fold,y=dev
    baseline={k:{"events":{"old":[e[:2] for e in d["primary"]]}} for k,d in rows.items()}
    bs=metrics(evaluate(units,baseline,"old",{"development"}))
    supports=[sum(s["units"][i]["label"]=="normal" for i in range(len(s["units"])) if not s["units"][i].get("confirmed_duplicate_of")) for s in units.values()]
    n=sum(supports); faults=sum(sum(bool(u["label"]) and not u.get("confirmed_duplicate_of") for u in s["units"]) for s in units.values())-n
    result=[]
    for depth in (2,3,4,5):
        for leaf in (12,28):
            for weight in (1,2):
                def fit(mask):
                    return DecisionTreeClassifier(max_depth=depth,min_samples_leaf=leaf,random_state=13,
                        class_weight={0:1,1:weight}).fit(x[mask],y[mask])
                fits=[fit((y>=0)&(fold!=f)) for f in range(5)]
                for guard in (0,1):
                    for uc,dc in ((.55,.60),(.65,.75),(.75,.75),(.65,1.01),(1.01,.65)):
                        changes=[]
                        for f,model in enumerate(fits):
                            c,_=choices(model,dev,native,np.where(fold==f)[0],guard,uc,dc)
                            changes.extend(c)
                        delta=Counter()
                        for i,new in changes:
                            target=y[i]; old=meta[i][2]
                            if target<0: continue
                            delta["normal"]+=int(target==1)*((new=="normal")-(old=="normal"))
                            delta["invalid"]+=int(target==0)*((new!="normal")-(old!="normal"))
                        gain=(delta["normal"]/n+delta["invalid"]/faults)/2
                        result.append((gain,delta["normal"],delta["invalid"],depth,leaf,weight,guard,uc,dc,len(changes)))
    result.sort(reverse=True)
    # Choose from stricter physical evidence only. Better average recall
    # cannot displace a candidate if either class loses correct answers.
    for best in result:
        _,n_gain,i_gain,depth,leaf,weight,guard,uc,dc,_=best
        if n_gain < 0 or i_gain < 0: continue
        model=DecisionTreeClassifier(max_depth=depth,min_samples_leaf=leaf,class_weight={0:1,1:weight},
            random_state=13).fit(x[y>=0],y[y>=0])
        final_changes,blocked=choices(model,dev,native,np.arange(len(meta)),guard,uc,dc)
        n_delta=sum((1 if new=="normal" else -1) for i,new in final_changes if y[i]==1)
        i_delta=sum((-1 if new=="normal" else 1) for i,new in final_changes if y[i]==0)
        if n_delta >= 0 and i_delta >= 0: break
    else:
        raise ValueError("No Pareto fit")
    oof=[]
    for f in range(5):
        training=(fold!=f)&(y>=0)
        cv=DecisionTreeClassifier(max_depth=depth,min_samples_leaf=leaf,class_weight={0:1,1:weight},
            random_state=13).fit(x[training],y[training])
        c,_=choices(cv,dev,native,np.where(fold==f)[0],guard,uc,dc)
        oof.extend(c)
    def export(changes,tag):
        table={meta[i][:2]:new for i,new in changes}
        secondary=base/"span-primary-open-012"/"out-of-fold.jsonl"
        label="fused" if tag=="oof" and secondary.is_file() else "old"
        events=read_sources(secondary) if label=="fused" else baseline
        pairs={k:{"events":{"selected":[[frame,table.get((k,frame),prior)] for frame,prior in row["events"][label]]}}
               for k,row in events.items()}
        path=args.output.parent/f"span-primary-{tag}-predictions.jsonl"
        with path.open("w",encoding="utf-8") as out:
            for key,row in pairs.items(): print(json.dumps({"source_id":key,**row}),file=out)
        return metrics(evaluate(units,pairs,"selected",{"development"}))
    tr=model.tree_
    report={"baseline":bs,"ranks":result,"candidates":len(result),"fn":"fully blocked native changes, per leaf/direction",
            "selected_config":best,"oof_combined":export(oof,"oof"),"refitted_primary":export(final_changes,"refit"),
            "selected":{"children_left":tr.children_left.tolist(),"children_right":tr.children_right.tolist(),
              "feature":tr.feature.tolist(),"threshold":tr.threshold.tolist(),
              "p":model.predict_proba(x[:1]).shape[1] and (tr.value[:,0,1]/tr.value[:,0,:].sum(axis=1)).tolist(),
              "blocked":[sorted(s) for s in blocked]}}
    args.output.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(bs,"best",best,"gates",Counter((r,gate[0]) for (_,_,r),gate in zip(meta,g)))

if __name__=="__main__":
    main()

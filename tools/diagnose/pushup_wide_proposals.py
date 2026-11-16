"""Freeze a continuous, label-blind union of gesture proposals for the offline MLP.

Tune the temporal proposal F1 on development only. An unmatched extra counts
against precision and a clip without a proposal counts against recall. Neither
labels nor reference boundaries enter the proposal function. The MLP benchmark
can then consume the frozen timeline in the same format as the app replay.
"""
import argparse
from bisect import bisect_left
from itertools import product
import json
from pathlib import Path

import numpy as np

from pushup_span_mlp import coordinates
from score_pushup_nine import evaluate, read_sources


def turns(indices, times, signal, threshold):
    top = low = last_value = None
    top_t = bottom_t = previous_t = None
    found = []
    for index, t, raw in zip(indices, times, signal):
        if not np.isfinite(raw):
            continue
        if previous_t is None or t - previous_t > 320:
            top, low, top_t, bottom_t = raw, None, t, t
            last_value = raw
        last_value += (raw - last_value) * (1 - np.exp(-(t - previous_t) / 80)) if previous_t is not None else 0
        previous_t = t
        value = last_value
        if low is None:
            if value > top or t - top_t > 3200:
                top, top_t = value, t
            elif top - value >= threshold:
                low, bottom_t = value, t
        elif t - top_t > 4800:
            top, top_t, low = value, t, None
        elif value <= low:
            low, bottom_t = value, t
        elif value-low >= max(threshold * .6, (top-low)*.58) and t-bottom_t >= 65 and t-top_t >= 240:
            found.append(int(index))
            top, top_t, low = value, t, None
    return found


def joints_for(source):
    ii, tt, p = coordinates(source)
    np.seterr(invalid="ignore",divide="ignore")
    # Both arms are independent. The best visible one may be used if the other
    # is occluded. Shoulder/wrist displacement gives torso movement even when
    # the person's camera angle projects elbow flexion weakly.
    tall = []
    opened = []
    for s,e,w in [(1,3,5),(2,4,6)]:
        upper, lower = p[:,s] - p[:,e], p[:,w] - p[:,e]
        a, b = np.linalg.norm(upper,axis=1), np.linalg.norm(lower,axis=1)
        denom = a*b
        mask = (a>1) & (b>1)
        el = np.full(len(ii),np.nan)
        el[mask] = np.arccos(np.clip((upper*lower).sum(axis=1)[mask]/denom[mask],-1,1))/np.pi
        height=np.full(len(ii),np.nan)
        height[mask] = (p[:,w,1]-p[:,s,1])[mask] / (a+b)[mask]
        tall.append(height)
        opened.append(el)
    def mean_visible(array):
        arr=np.asarray(array)
        count=np.sum(np.isfinite(arr),axis=0)
        return np.divide(np.nansum(arr,axis=0),count,out=np.full(len(count),np.nan),where=count>0)
    height=mean_visible(tall)
    elbow=mean_visible(opened)
    return {str(t): sorted(set(turns(ii,tt,elbow,t))|set(turns(ii,tt,height,t))) for t in [.055,.095,.155]}


def collect_sources(replay):
    out={}
    with replay.open(encoding="utf8") as src:
        for line in src:
            r=json.loads(line)
            clock={f[0]:f[1] / (1000 if r.get("time_unit")=="us" else 1) for f in r["frames"]}
            out[r["source_id"]]=(clock,joints_for(r))
    return out


def propose(stable, windows, signals, config):
    width, soft, cooldown = config
    clock, optional = signals
    times = []
    for f,label in stable:
        times.append((clock[f],0,f,label))
    for start,low,end in windows[width]:
        times.append((clock[end],1,end,"insufficientDepth"))
    for end in optional.get(soft,[]):
        times.append((clock[end],2,end,"insufficientDepth"))
    # There is no look-ahead. If two sources fire on the very same frame,
    # prefer the primary; otherwise the first timestamp starts the cooldown.
    events=[]
    last=-10**15
    for t, priority, f,label in sorted(times):
        if t-last >= cooldown:
            events.append([f,label])
            last=t
    return events


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("root",type=Path)
    p.add_argument("out",type=Path)
    a=p.parse_args()
    root,out=a.root,a.out
    dev=read_sources(root/"native-development"/"units.jsonl")
    baseline=read_sources(root/"native-final"/"shipping.jsonl")
    pdev=read_sources(out/"development-windows.jsonl")
    sig=collect_sources(root/"native-development"/"replay.jsonl")
    ranking=[]
    for config in product(["0.06","0.09","0.12"],["none","0.055","0.095","0.155"],[250,400,600,800]):
        ef={sid:{"events":{"union":propose(baseline[sid]["events"]["app_default"],p["windows"],sig[sid],config)}} for sid,p in pdev.items()}
        score=evaluate(dev,ef,"union",{"development"})
        matched, extra, misses=score["matched"],score["extras"],score["misses"]
        f1=2*matched/(2*matched+extra+misses)
        ranking.append(dict(config=config,proposal_f1=f1,matched=matched,extras=extra,misses=misses))
    ranking.sort(key=lambda r:(-r["proposal_f1"],r["extras"]))
    config=ranking[0]["config"]
    (out/"proposal-selection.json").write_text(json.dumps({"rankings":ranking,"selected":config},indent=2))
    print("Frozen development setting",ranking[0],flush=True)
    for name,replay,original in [("development",None,baseline),("holdout","native-holdout/replay.jsonl",baseline),
                                  ("fixtures","span-source-fixtures.jsonl",read_sources(root/"native-winner-frozen.jsonl"))]:
        win=read_sources(out/f"{name}-windows.jsonl")
        signal=collect_sources(root/replay) if replay else sig
        with (out/f"{name}-proposals.jsonl").open("w",encoding="utf8") as dest:
            for key,row in win.items():
                prev=original[key]
                events=propose(prev["events"]["app_default"],row["windows"],signal[key],config)
                result=dict(prev,events={"app_default":events})
                print(json.dumps(result,separators=(",",":")),file=dest)
    with (out/"proposals.jsonl").open("wb") as dest:
        for name in ["development","holdout"]:
            dest.write((out/f"{name}-proposals.jsonl").read_bytes())


if __name__=="__main__":
    main()

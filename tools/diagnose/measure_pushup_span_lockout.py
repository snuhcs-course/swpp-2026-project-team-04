"""Development ablation for a visible bilateral lockout following a span cycle."""
import argparse
import json
import warnings
from pathlib import Path

import numpy as np
from assess_pushup_span_cycles import eligible
from score_pushup_nine import read_sources, evaluate


def angle(a,b,c):
    u,v = a-b,c-b
    return np.degrees(np.arccos(np.clip((u*v).sum(-1) /
        (np.linalg.norm(u,axis=-1)*np.linalg.norm(v,axis=-1)),-1,1)))


def recorded(base,tag):
    dev=tag=="development"
    replay=base/("native-development/replay.jsonl" if dev else "span-source-fixtures.jsonl")
    primary=read_sources(base/("native-final/shipping.jsonl" if dev else "native-winner-frozen.jsonl"))
    windows=read_sources(base/f"span-final-windows-{tag}.jsonl")
    output={}
    with replay.open() as stream:
        for line in stream:
            row=json.loads(line); key=row["source_id"]
            old=primary[key]["events"]["app_default"]
            lo=windows[key]["windows"]["0.12"]
            trace=dict(windows[key]["primary_open"])
            clock={f[0]:f[1]*(1000 if dev else 1) for f in row["frames"]}
            locations={f[0]:i for i,f in enumerate(row["frames"])}
            candidates={}
            for delay in (0,180000,300000):
                c=[]
                # Refraction follows a delivered verdict, never a cycle that abstains.
                for a,b,e in lo:
                    retained=eligible([(a,b,e)],old,clock,delay,0)
                    if not retained: continue
                    _,frame=retained[0]
                    if trace.get(frame,float("inf"))<=e: continue
                    c.append((a,b,e,frame))
                candidates[delay]=c
            options={delay:[] for delay in candidates}
            output[key]=(old,options)
            if not any(candidates.values()): continue
            points=np.full((len(row["frames"]),33,3),np.nan)
            for i,f in enumerate(row["frames"]):
                if f[2] is not None:
                    points[i]=np.asarray([(np.nan,np.nan,0) if p is None else p for p in f[2]])
            xy=points[:,:,:2]
            xy[points[:,:,2]<.6]=np.nan
            s,e,w,h,k,an=[xy[:,[j,j+1]] for j in [11,13,15,23,25,27]]
            def norm(v): return np.linalg.norm(v,axis=-1)
            arm=angle(s,e,w)
            scale=(norm(s-e)+norm(e-w)).mean(-1)
            armMin,armMax=arm.min(-1),arm.max(-1)
            hipMin=angle(s,h,k).min(-1)
            kneeMin=angle(h,k,an).min(-1)
            tilt=np.degrees(np.arctan2(np.abs(s[:,0,1]-s[:,1,1]),np.abs(s[:,0,0]-s[:,1,0])))
            hand=((w[:,:,1]-s[:,:,1])/scale[:,None]).min(-1)
            torso=((h[:,:,1]-s[:,:,1])/scale[:,None]).max(-1)
            for delay,items in candidates.items():
                for top,low,end,frame in items:
                    t,b,r,close=(locations[x] for x in (top,low,end,frame))
                    top_end=min(t+1+(b-t)//3,b)
                    bottom_start=max(t,b-(b-t)//3)
                    bottom_end=min(r+1,b+1+(r-b)//3)
                    fin_start=max(b,r-(r-b)//3)
                    # Max of the weaker elbow is a simultaneous two-arm endpoint.
                    top_lock=np.nanmax(armMin[t:top_end])
                    lock=np.nanmax(armMin[fin_start:close+1])
                    flex=np.nanmin(armMax[bottom_start:bottom_end])
                    if not all(np.isfinite([top_lock,lock,flex])): continue
                    si=slice(t,close+1)
                    v=(min(top_lock,lock),flex,np.nanmedian(hipMin[si]),np.nanmedian(kneeMin[si]),
                       np.nanquantile(tilt[si],.85),np.nanquantile(torso[si],.85),
                       min(np.nanmax(hand[t:top_end]),np.nanmax(hand[fin_start:close+1]))-
                          np.nanmin(hand[bottom_start:bottom_end]))
                    if all(np.isfinite(v)): options[delay].append((frame,v))
    return output


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("root",type=Path); p.add_argument("output",type=Path)
    args=p.parse_args()
    with warnings.catch_warnings():
        warnings.simplefilter("ignore",RuntimeWarning)
        dev=recorded(args.root,"development"); native=recorded(args.root,"fixtures")
    units=read_sources(args.root/"native-development/units.jsonl")
    orig={k:{"events":{"base":p}} for k,(p,opts) in dev.items()}
    base=evaluate(units,orig,"base",{"development"})
    results=[]
    for delay in (0,180000,300000):
        for lock in (160,165,170):
            for flex in (100,115,130):
                for lower in (135,150,160):
                    def accepted(v):
                        return (v[0]>=lock and v[1]<=flex and min(v[2:4])>=lower and
                                v[4]<=15 and v[5]<=.65 and v[6]>=.2)
                    def counts(opts):
                        return [[f,"normal"] for f,v in opts[delay] if accepted(v)]
                    merged={k:{"events":{"new":sorted(p+counts(opts))}} for k,(p,opts) in dev.items()}
                    score=evaluate(units,merged,"new",{"development"})
                    fixtures={k:counts(opts) for k,(_,opts) in native.items() if counts(opts)}
                    results.append(dict(config=[delay,lock,flex,lower],
                        extra_valid=score["valid_reps_counted"]-base["valid_reps_counted"],
                        extra_invalid_as_valid=score["invalid_reps_counted"]-base["invalid_reps_counted"],
                        extra_unmatched=score["extras"]-base["extras"],added_phone_counts=fixtures))
    args.output.write_text(json.dumps(results,indent=2),encoding="utf-8")

if __name__=="__main__":
    main()

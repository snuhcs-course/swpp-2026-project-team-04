"""Check fully-observed 2D normal-rep proposals on development data and phone controls."""
import argparse
from collections import Counter
import json
from pathlib import Path

from assess_pushup_span_cycles import eligible, read_clocks
from score_pushup_nine import read_sources, evaluate


def normal(v, lockout, flex, lower, travel):
    if v is None: return False
    def at(signal, stat):
        return v[signal*6+stat]
    # Mean and weaker angle belong to the same pair of visible arms.
    evidence=[at(1,3),at(1,5),at(0,4),at(1,4),at(3,2),at(4,2),
              at(5,2),at(8,2),at(6,3),at(6,4),at(6,5)]
    if None in evidence:
        return False
    start,end,mean,weak,tilt,hip,knee,torso,reach,deep,back=evidence
    return (min(start,end)>=lockout and 2*mean-weak<=flex and
            tilt<=13 and hip>=lower and knee>=lower and torso<=.65 and
            min(reach,back)>=.33 and min(reach,back)-deep>=travel)


def options(base,tag):
    name=(base/"native-development"/"replay.jsonl") if tag=="development" else base/"span-source-fixtures.jsonl"
    clocks=read_clocks(name)
    windows=read_sources(base/f"span-final-windows-{tag}.jsonl")
    evid=read_sources(base/f"span-frozen-evidence-{tag}.jsonl")
    primary=read_sources(base/("native-final/shipping.jsonl" if tag=="development" else "native-winner-frozen.jsonl"))
    out={}
    for k,clock in clocks.items():
        p=primary[k]["events"]["app_default"]
        row=windows[k]
        trace=dict(row["primary_open"])
        opts=[]
        w=row["windows"]["0.12"]
        for j,frame in eligible(w,p,clock,0,0):
            if frame in trace and trace[frame]<=w[j][-1]: continue
            vec=evid[k]["evidence"][",".join(map(str,w[j]))]
            opts.append((frame,vec))
        out[k]=p,opts
    return out


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("root",type=Path)
    p.add_argument("out",type=Path)
    args=p.parse_args()
    dev=options(args.root,"development")
    fixtures=options(args.root,"fixtures")
    units=read_sources(args.root/"native-development/units.jsonl")
    orig={k:{"events":{"base":p}} for k,(p,opts) in dev.items()}
    b=evaluate(units,orig,"base",{"development"})
    results=[]
    for lock in (140,150,160,165):
        for flex in (105,120,135):
            for lower in (135,150,160):
                for travel in (.18,.28):
                    config=(lock,flex,lower,travel)
                    def count(opts): return [[f,"normal"] for f,v in opts if normal(v,*config)]
                    f={k:count(opts) for k,(_,opts) in fixtures.items()}
                    merged={k:{"events":{"new":sorted(p+count(opts))}} for k,(p,opts) in dev.items()}
                    score=evaluate(units,merged,"new",{"development"})
                    results.append(dict(config=config,
                        extra_valid=score["valid_reps_counted"]-b["valid_reps_counted"],
                        extra_invalid_as_valid=score["invalid_reps_counted"]-b["invalid_reps_counted"],
                        extra_unmatched=score["extras"]-b["extras"],
                        added_phone_counts={k:vals for k,vals in f.items() if vals}))
    args.out.write_text(json.dumps(results,indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()

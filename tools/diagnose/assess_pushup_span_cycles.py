"""Measure causal span windows against prior judgements and converted phone fixtures."""
import argparse
from bisect import bisect_left, bisect_right
from collections import Counter
import json
from pathlib import Path

from score_pushup_nine import evaluate, read_sources


def write_fixtures(path):
    app = Path(__file__).resolve().parents[2] / "gymrats_app" / "test"
    with path.open("x", encoding="utf-8") as out:
        for folder in (app/"ai_eval"/"cases", app/"fixtures"/"pushup_cases"):
            for file in sorted(folder.rglob("*.json")):
                doc = json.loads(file.read_text(encoding="utf-8-sig"))
                frames = []
                for i, fr in enumerate(doc["frames"]):
                    if fr.get("mark") == "abandon":
                        frames.append([i, fr["t"], None, "abandon"])
                    elif (p := fr.get("p")) is not None:
                        if len(doc["landmarks"]) != 33 or doc["landmarks"][0] != "nose":
                            raise ValueError("Unexpected landmark order")
                        joints = [None if p[j] is None else [p[j], p[j+1], p[j+3]] for j in range(0,len(p),4)]
                        frames.append([i,fr["t"],joints])
                        size = (fr["w"],fr["h"])
                row = dict(source_id=doc["id"],time_unit="us",width=size[0],height=size[1],frames=frames)
                print(json.dumps(row, separators=(",",":")),file=out)


def read_clocks(path):
    clocks = {}
    with path.open(encoding="utf-8") as inp:
        for line in inp:
            row = json.loads(line)
            scale = 1 if row.get("time_unit") == "us" else 1000
            clocks[row["source_id"]] = {f[0]:f[1]*scale for f in row["frames"]}
    return clocks


def eligible(windows, primary, clock, delay_us, quiet_us):
    """Return candidate window index and delivery frame. Uses only elapsed samples."""
    frame_at = {t:i for i,t in clock.items()}
    times = sorted(frame_at)
    prim_times = sorted(clock[i] for i,_ in primary)
    retained = []
    last_sent = -10**18
    for j,(start, _, end) in enumerate(windows):
        emit = bisect_left(times, clock[end]+delay_us)
        if emit == len(times) or times[emit] - clock[end] > delay_us + 150000:
            continue
        at = times[emit]
        last = bisect_right(prim_times, at)-1
        if last >= 0 and prim_times[last] >= min(clock[start]-120000, at-quiet_us):
            continue
        if at - last_sent < 400000:
            continue
        retained.append((j,frame_at[at]))
        last_sent = at
    return retained


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-fixtures", type=Path)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.build_fixtures:
        return write_fixtures(args.build_fixtures)
    base = args.root
    units=read_sources(base/"native-development"/"units.jsonl")
    dev_windows=read_sources(base/"span-cycles-development.jsonl")
    dev_primary=read_sources(base/"native-final"/"shipping.jsonl")
    dev_clock=read_clocks(base/"native-development"/"replay.jsonl")
    fx_windows=read_sources(base/"span-cycles-fixtures.jsonl")
    fx_clock=read_clocks(base/"span-source-fixtures.jsonl")
    fx_primary=read_sources(base/"native-winner-frozen.jsonl")
    results=[]
    for width in next(iter(dev_windows.values()))["windows"]:
        for delay in (0,150000,250000,350000):
            for quiet in (0,1200000,2200000):
                dev = {}
                for k,clock in dev_clock.items():
                    p=dev_primary[k]["events"]["app_default"]
                    retained=eligible(dev_windows[k]["windows"][width],p,clock,delay,quiet)
                    dev[k]={"events":{"cand":sorted(p+[[frame,"insufficientDepth"] for _,frame in retained])}}
                score=evaluate(units,dev,"cand",{"development"})
                fixtures=Counter()
                for k,clock in fx_clock.items():
                    p=fx_primary[k]["events"]["app_default"]
                    retained=eligible(fx_windows[k]["windows"][width],p,clock,delay,quiet)
                    fixtures["extras"]+=len(retained)
                    if retained:
                        fixtures["affected"]+=1
                    expected=fx_primary[k].get("expected")
                    if expected:
                        want=Counter(expected["rejected"])
                        want["normal"]=expected["valid"]
                        if Counter(r for _,r in p)==want:
                            fixtures["extra_in_matching"]+=len(retained)
                results.append(dict(width=width,delay=delay,quiet=quiet,
                    provisional_macro=score["macro_f1"],correct=score["correct"],misses=score["misses"],
                    extras=score["extras"],fixtures=fixtures))
    args.report.write_text(json.dumps(results,indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()

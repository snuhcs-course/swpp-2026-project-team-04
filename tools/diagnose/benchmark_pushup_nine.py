"""Compare the native Android landmark streams, then verify the selected shipping judge.

Run from the S1 checkout. The 'compare' stage takes a new, empty output directory
and never reports a holdout score. After the selected rules have been put in the
app, 'verify' checks every event and writes the final evaluation.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from score_pushup_nine import file_digest
from run_pushup_nine import dart_binary
from learn_pushup_feedback import BASES as TREE_BASES

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent.parent
BASE = "small30_elev60_knees_tilt15_guarded"
BASES = ("baseline", *TREE_BASES)


def python(script, *args):
    subprocess.run([sys.executable, "-B", TOOLS / script, *map(str, args)], cwd=ROOT, check=True)


def concatenate(output, *inputs):
    with output.open("xb") as dest:
        for path in inputs:
            with path.open("rb") as src:
                shutil.copyfileobj(src, dest)


def check_capture(folder):
    coverage = folder / "coverage.json"
    verification = json.loads((folder / "verified.json").read_text(encoding="utf8"))
    if verification["coverage_sha256"] != file_digest(coverage):
        raise ValueError(f"Unverified capture in {folder}")
    details = json.loads(coverage.read_text(encoding="utf8"))
    for name in ("replay", "units"):
        if file_digest(folder / f"{name}.jsonl") != details[f"{name}_sha256"]:
            raise ValueError(f"Changed {name} in {folder}")


def window_rows(source, events, output):
    subprocess.run([dart_binary(), "--packages=.dart_tool/package_config.json", TOOLS / "pushup_wrist_windows.dart",
                    str(source), events, BASE, output], cwd=ROOT / "gymrats_app", check=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stage", choices=["compare", "verify"])
    p.add_argument("captures", type=Path, help="Parent of native-development and native-holdout")
    p.add_argument("output", type=Path)
    a = p.parse_args()
    out = a.output.resolve()
    dev, test = [a.captures.resolve() / ("native-" + s) for s in ("development", "holdout")]
    combined = out / "units.jsonl"
    train = out / "attempt-trees"
    wrist = out / "window-trees"
    merged = wrist / "merged"
    final_inputs = ["--units", combined, "--events", merged / "events-with-trees.jsonl",
                    "--lock", out / "selection.json"]
    if a.stage == "verify":
        python("run_pushup_nine.py", "--shipping", out / "replay.jsonl", out / "shipping.jsonl")
        python("score_pushup_nine.py", "report", *final_inputs, "--refit-events", merged / "refit-events.jsonl",
               "--shipping", out / "shipping.jsonl", "--out-dir", out)
        return
    if out.exists() and any(out.iterdir()):
        p.error("Use a fresh result folder")
    out.mkdir(parents=True, exist_ok=True)
    for path in (dev, test):
        check_capture(path)
    concatenate(combined, dev / "units.jsonl", test / "units.jsonl")
    concatenate(out / "replay.jsonl", dev / "replay.jsonl", test / "replay.jsonl")
    python("run_pushup_nine.py", "--fixtures", out / "fixtures.jsonl")
    python("run_pushup_nine.py", "--probe", out / "visibility-probes.json")
    python("run_pushup_nine.py", "--fixtures", out / "fixture-features.jsonl", "--attempt-evidence", *BASES)
    window_rows("--fixtures", out / "fixtures.jsonl", out / "fixture-wrist.jsonl")
    for split, folder in (("development", dev), ("holdout", test)):
        path = out / split
        path.mkdir()
        python("run_pushup_nine.py", folder / "replay.jsonl", path / "events.jsonl")
        python("run_pushup_nine.py", folder / "replay.jsonl", path / "features.jsonl",
               "--attempt-evidence", *BASES)
        window_rows(folder / "replay.jsonl", path / "events.jsonl", path / "wrist.jsonl")
    for name in ("events.jsonl", "features.jsonl"):
        concatenate(out / name, out / "development" / name, out / "holdout" / name)
    python("learn_pushup_feedback.py", "--units", combined, "--features", out / "features.jsonl",
           "--fixture-features", out / "fixture-features.jsonl", "--events", out / "events.jsonl",
           "--fixtures", out / "fixtures.jsonl", "--out", train)
    python("learn_wrist_reasons.py", "--units", dev / "units.jsonl",
           "--base", BASE,
           "--features", out / "development/wrist.jsonl", "--fixture-features", out / "fixture-wrist.jsonl",
           "--heldout-features", out / "holdout/wrist.jsonl", "--append-to", train, "--out", wrist)
    python("score_pushup_nine.py", "select", *final_inputs,
           "--fixtures", merged / "fixtures-with-trees.jsonl", "--probes", out / "visibility-probes.json",
           "--wrist-base", BASE)


if __name__ == "__main__":
    main()

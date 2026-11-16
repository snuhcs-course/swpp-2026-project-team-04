"""Replay immutable push-up candidates or the shipping app against saved poses.

From the repository root:
  python tools/diagnose/run_pushup_nine.py INPUT.jsonl NEW_OUTPUT.jsonl
  python tools/diagnose/run_pushup_nine.py --fixtures NEW_OUTPUT.jsonl
  python tools/diagnose/run_pushup_nine.py INPUT.jsonl NEW_OUTPUT.jsonl --attempt-evidence baseline tilt15_shallow18
  python tools/diagnose/run_pushup_nine.py --shipping INPUT.jsonl NEW_OUTPUT.jsonl
  python tools/diagnose/run_pushup_nine.py --shipping --mlp INPUT.jsonl NEW_OUTPUT.jsonl
  python tools/diagnose/run_pushup_nine.py --shipping --fixtures NEW_OUTPUT.jsonl
  python tools/diagnose/run_pushup_nine.py --probe NEW_SAFETY_REPORT.json

Input/output paths are relative to the caller. A preset list is optional.
--features exports [maxDepth, minElbowAngle, maxTilt]. --attempt-evidence
exports the frozen judge's 11 within-attempt measurements (experimental only).
No Flutter download, pub get, checkout or index update is needed.
"""

import json
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

from pushup_guard_probes import write_inputs, write_report

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent.parent
BASE = "d866b456a2bb0b9df863c811e2e7402da2ad01db"
REPLAY = "pushup_nine_replay.dart"
PRESETS = "pushup_nine_presets.dart"
JUDGE_FILES = (
    "lib/models/exercise_type.dart",
    "lib/models/pose_frame.dart",
    "lib/models/rep_event.dart",
    "lib/services/pose/pose_metrics.dart",
    "lib/services/pose/rep_judge.dart",
)
SCORER_FILES = ("test/ai_eval/eval_plan.dart", "test/ai_eval/eval_scorer.dart")

# The shipping entry point deliberately calls only the stable runtime API.
# It keeps working after experimental fields and callbacks leave the app.
SHIPPING = """import 'package:gymrats_app/services/pose/rep_judge.dart';

const presets = {'app_default': RepJudgeConfig()};
RepJudge newReplayJudge(
  RepJudgeConfig config, RepClock clock, void Function(List<double?>)? evidence,
) => RepJudge(config: config, clock: clock);
"""


def materialize_base(temp, files):
    for name in files:
        relative = f"gymrats_app/{name}"
        dest = temp / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(
            subprocess.check_output(["git", "show", f"{BASE}:{relative}"], cwd=ROOT)
        )


def dart_binary():
    command = shutil.which("dart")
    if command is None:
        raise SystemExit("Add the Dart or Flutter SDK bin directory to PATH.")
    wrapper = Path(command)
    # Flutter may expose a shell/batch wrapper; use its real SDK if installed.
    for name in ("dart.exe", "dart"):
        binary = wrapper.parent / "cache" / "dart-sdk" / "bin" / name
        if binary.is_file():
            return str(binary)
    return command


def main(args):
    if not args or "--help" in args or "-h" in args:
        print(__doc__)
        return
    args = list(args)
    shipping = "--shipping" in args
    if shipping:
        args.remove("--shipping")
    mlp = "--mlp" in args
    if mlp:
        args.remove("--mlp")
        if not shipping:
            raise SystemExit("--mlp requires --shipping")
    if len(args) < 2:
        raise SystemExit("Expected input or --fixtures, followed by a new output path.")
    if shipping and "--attempt-evidence" in args:
        raise SystemExit("--attempt-evidence is available on the frozen candidate replay.")
    probe = args[0] == "--probe"
    if args[0] != "--fixtures" and not probe:
        args[0] = str(Path(args[0]).resolve(strict=True))
    args[1] = str(Path(args[1]).resolve())
    runtime = ROOT / "gymrats_app"
    with TemporaryDirectory(prefix="gymrats-nine-replay-") as name:
        temp = Path(name)
        if probe:
            output = Path(args[1])
            if output.exists():
                raise SystemExit(f"Use a new report path: {output}")
            write_inputs(temp / "probes.jsonl")
            args[0:2] = [str(temp / "probes.jsonl"), str(temp / "events.jsonl")]
        source = temp / "tools" / "diagnose"
        source.mkdir(parents=True)
        shutil.copyfile(TOOLS / REPLAY, source / REPLAY)
        materialize_base(temp, SCORER_FILES)
        if shipping:
            package = runtime
            shipped = SHIPPING.replace("config: config, clock: clock",
                                       "config: config, clock: clock, useMlp: true") if mlp else SHIPPING
            (source / PRESETS).write_text(shipped, encoding="utf-8")
        else:
            package = temp / "gymrats_app"
            materialize_base(temp, JUDGE_FILES)
            for patch in ("pushup_nine_candidates.patch", "pushup_nine_guarded.patch"):
                subprocess.run(
                    ["git", "apply", "--no-index", str(TOOLS / patch)],
                    cwd=temp, check=True,
                )
            shutil.copyfile(TOOLS / PRESETS, source / PRESETS)
        config = temp / "package_config.json"
        config.write_text(json.dumps({
            "configVersion": 2,
            "packages": [{
                "name": "gymrats_app", "rootUri": package.as_uri() + "/",
                "packageUri": "lib/", "languageVersion": "3.13",
            }],
        }), encoding="utf-8")
        subprocess.run(
            [dart_binary(), f"--packages={config}", str(source / REPLAY), *args],
            check=True, cwd=runtime,
        )
        if probe:
            write_report(temp / "events.jsonl", output)


if __name__ == "__main__":
    main(sys.argv[1:])

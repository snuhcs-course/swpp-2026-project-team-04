"""Replay a label-blind holdout sample through the separate Android pose_video_eval APK.

The dedicated gymrats_pose_eval AVD must be running and the existing evaluator
installed. For interruption recovery, the emulator paths below distinguish the
capture inputs from the untouched previous evaluation directory.
"""
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import time
import zipfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from pathlib import Path

import cv2


SEED = "gymrats-nine-native-holdout-v1"
PACKAGE = "com.gymrats.pose_video_eval"
DEVICE = f"/storage/emulated/0/Android/data/{PACKAGE}/files"
ACTIVE = f"{DEVICE}/pose_eval"
STAGED = f"{DEVICE}/nine_native_staged"
SAVED = f"{DEVICE}/nine_native_saved_old"
FINISHED = f"{DEVICE}/nine_native_finished"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def records(path):
    with path.open(encoding="utf-8") as stream:
        for line in stream:
            yield json.loads(line)


def write_json(path, row):
    temporary = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(row, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    temporary.replace(path)


def key(value):
    return hashlib.sha256(f"{SEED}|{value}".encode()).hexdigest()


def prepare(benchmark, output, count, explicit=None, offsets=None):
    groups = {}
    for row in records(benchmark / "units.jsonl"):
        if row["split"] == "holdout":
            groups.setdefault(row["group_id"], []).append(row)
    if explicit is None and not 1 <= count <= len(groups):
        raise ValueError("choose between one and the number of held-out groups")
    # First sample distinct source groups, then pick one member in each group.
    choose = (explicit if explicit is not None else
              [min(groups[g], key=lambda r: key(r["source_sha256"]))
               for g in sorted(groups, key=key)[:count]])
    selected = {row["source_id"] for row in choose}
    method = "all sources in split (checkpoint batch)" if explicit is not None else "first SHA-256 ranks of distinct holdout groups, then of source SHA within each"
    sample = {"seed": SEED, "method": method, "count": len(choose),
              "sources": [{k: row[k] for k in ("source_id", "source_sha256", "group_id")} for row in choose]}
    if explicit is None:
        sample["eligible_groups"] = len(groups)
    output.mkdir(parents=True, exist_ok=True)
    selection = output / "selection.json"
    if selection.exists() and json.loads(selection.read_text(encoding="utf-8")) != sample:
        raise ValueError("output contains a different frozen sample")
    write_json(selection, sample)
    raw = output / "inputs"
    raw.mkdir(exist_ok=True)
    manifest = []
    def chosen_rows():
        if offsets is None:
            yield from (row for row in records(benchmark / "replay.jsonl") if row["source_id"] in selected)
            return
        with (benchmark / "replay.jsonl").open("rb") as file:
            for src in choose:
                file.seek(offsets[src["source_id"]])
                yield json.loads(file.readline())

    with (output / "units.jsonl").open("w", encoding="utf-8", newline="\n") as out:
        for row in chosen_rows():
            sid = row["source_id"]
            if sid not in selected:
                continue
            frames = row.pop("frames")
            path = Path(row["source_path"])
            if digest(path) != row["source_sha256"]:
                raise ValueError(f"{sid}: original changed")
            cap = cv2.VideoCapture(str(path))
            cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)
            entries = []
            read_index = -1
            try:
                for index, stamp, _ in frames:
                    while read_index < index:
                        if not cap.grab():
                            raise ValueError(f"{sid}: decode ended at {read_index}")
                        read_index += 1
                    ok, frame = cap.retrieve()
                    if not ok or frame.shape[:2] != (row["height"], row["width"]):
                        raise ValueError(f"{sid}: upright frame canvas disagrees with labels")
                    filename = f"{sid}_{index:06d}.jpg"
                    if not cv2.imwrite(str(raw / filename), frame, [cv2.IMWRITE_JPEG_QUALITY, 95]):
                        raise OSError(filename)
                    entries.append({"file": filename, "index": index, "ms": stamp})
            finally:
                cap.release()
            row["detector"] = "google_mlkit_pose_detection/0.16.1:accurate/stream:android:upright_jpeg"
            manifest.append({"clip": sid, "width": row["width"], "height": row["height"], "frames": entries})
            out.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
    if len(manifest) != count:
        raise ValueError("sample IDs missing from replay")
    write_json(raw / "manifest.json", manifest)
    print("Frozen sample", count, "sources,", sum(len(m["frames"]) for m in manifest), "frames", flush=True)


def capture(args, output):
    if not re.fullmatch(r"emulator-\d+", args.serial):
        raise ValueError("only the dedicated emulator may be used")
    serial_file = Path(tempfile.gettempdir()) / f"gymrats-pose-eval-{args.serial}.lock"
    serial_lock = claim(serial_file)
    if serial_lock is None:
        raise RuntimeError(f"another local capture is already using {args.serial}")
    try:
        capture_locked(args, output)
    finally:
        serial_lock.close()


def capture_locked(args, output):
    def adb(*parts, check=True):
        result = subprocess.run([str(args.adb), "-s", args.serial, *parts], capture_output=True, text=True)
        if check and result.returncode:
            raise RuntimeError(f"adb {' '.join(parts)}: {result.stderr} {result.stdout}")
        return result

    deadline = time.monotonic() + 180
    while adb("shell", "getprop", "sys.boot_completed", check=False).stdout.strip() != "1":
        if time.monotonic() > deadline:
            raise RuntimeError(f"dedicated AVD {args.serial} not ready after three minutes")
        time.sleep(3)
    if adb("emu", "avd", "name").stdout.strip().splitlines()[0].strip() != "gymrats_pose_eval":
        raise ValueError("wrong AVD")
    apk = args.evaluator / "build/app/outputs/flutter-apk/app-debug.apk"
    package_path = adb("shell", "pm", "path", PACKAGE).stdout.strip().removeprefix("package:")
    expected = digest(apk)
    if adb("shell", "sha256sum", package_path).stdout.split()[0] != expected:
        raise ValueError("installed evaluator and inspected APK do not match")

    def exists(name):
        return adb("shell", "test", "-e", name, check=False).returncode == 0

    # A previous interrupted host can leave its own temporary directory. Keep
    # a recoverable copy and restore the AVD's previous evaluation before reuse.
    # Never reinterpret an unmarked directory as our scratch space.
    if exists(f"{ACTIVE}/.nine_native_owned"):
        adb("shell", "am", "force-stop", PACKAGE)
        adb("shell", "mv", ACTIVE, f"{FINISHED}_interrupted_{time.time_ns()}")
    if exists(SAVED):
        if exists(ACTIVE):
            raise RuntimeError("ambiguous unmarked evaluator directories; preserving both")
        adb("shell", "mv", SAVED, ACTIVE)
    if exists(STAGED):
        if not exists(f"{STAGED}/.nine_native_owned"):
            raise RuntimeError("unmarked evaluator staging already exists; it is preserved")
        adb("shell", "mv", STAGED, f"{FINISHED}_staged_{time.time_ns()}")
    archived = f"{FINISHED}_{time.time_ns()}"
    had_previous = exists(ACTIVE)
    archive = output / "input-frames.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as z:
        for path in (output / "inputs").iterdir():
            z.write(path, path.name)
    available = int(adb("shell", "df", "-k", "/data").stdout.splitlines()[-1].split()[3]) * 1024
    size = archive.stat().st_size
    if available < size * 2 + 250_000_000:
        raise RuntimeError(f"Insufficient AVD scratch: {available} bytes free for {size} frame bytes")
    adb("shell", "mkdir", STAGED)
    adb("shell", "touch", f"{STAGED}/.nine_native_owned")
    adb("push", str(archive), f"{STAGED}/frames.zip")
    adb("shell", "unzip", "-q", f"{STAGED}/frames.zip", "-d", STAGED)
    adb("shell", "rm", f"{STAGED}/frames.zip")
    # Shell extraction on this AVD can default to 0770 for both files and
    # directories. The evaluator UID reads the inputs and writes results here.
    adb("shell", "chmod", "-R", "a+rX", STAGED)
    adb("shell", "chmod", "777", STAGED)
    adb("shell", "am", "force-stop", PACKAGE)
    if had_previous:
        adb("shell", "mv", ACTIVE, SAVED)
    mounted = False
    verified = False
    try:
        adb("shell", "mv", STAGED, ACTIVE)
        mounted = True
        adb("shell", "am", "start", "-n", f"{PACKAGE}/.MainActivity")
        deadline = time.monotonic() + 3600
        while not exists(f"{ACTIVE}/complete.txt"):
            if time.monotonic() > deadline:
                raise TimeoutError("native detector did not finish within one hour")
            time.sleep(5)
        pulled = output / "android-results.partial"
        adb("pull", f"{ACTIVE}/results.json", str(pulled))
        expected_results = adb("shell", "sha256sum", f"{ACTIVE}/results.json").stdout.split()[0]
        if digest(pulled) != expected_results:
            raise ValueError("Native results were corrupted in transit")
        pulled.replace(output / "android-results.json")
        verified = True
    finally:
        adb("shell", "am", "force-stop", PACKAGE)
        if mounted:
            adb("shell", "mv", ACTIVE, archived)
        if had_previous:
            adb("shell", "mv", SAVED, ACTIVE)
        # Delete only this newly created, explicitly marked scratch, after the
        # original directory is back and the copied native result is verified.
        if verified and exists(f"{archived}/.nine_native_owned"):
            adb("shell", "rm", "-r", archived)
    archive.unlink()
    write_json(output / "runtime.json", {"avd": "gymrats_pose_eval", "abi": adb("shell", "getprop", "ro.product.cpu.abi").stdout.strip(),
               "api": adb("shell", "getprop", "ro.build.version.sdk").stdout.strip(), "package": PACKAGE,
               "apk_sha256": expected, "plugin": "0.16.1", "mode": "accurate/stream", "input": "upright JPEG quality 95"})


def convert(args, output):
    dart = (args.evaluator / "lib/models/pose_frame.dart").read_text(encoding="utf-8")
    enum = re.search(r"enum BodyLandmark\s*\{([^}]+)\}", dart).group(1)
    names = [s.strip() for s in enum.split(",") if s.strip()]
    if len(names) != 33 or names[11] != "leftShoulder":
        raise ValueError("unexpected landmark index order")
    sources = {s["source_id"]: s for s in records(output / "units.jsonl")}
    manifest = json.loads((output / "inputs/manifest.json").read_text(encoding="utf-8"))
    results = json.loads((output / "android-results.json").read_text(encoding="utf-8"))
    counts = Counter()
    if len(manifest) != len(results) or len(sources) != len(results):
        raise ValueError("incomplete Android export")
    with (output / "replay.partial").open("w", encoding="utf-8", newline="\n") as out:
        for clip, raw in zip(manifest, results, strict=True):
            sid = clip["clip"]
            row = sources[sid]
            if (sid, row["width"], row["height"]) != (raw["clip"], raw["width"], raw["height"]):
                raise ValueError(f"{sid}: mismatched native result")
            frames = []
            for expected, actual in zip(clip["frames"], raw["frames"], strict=True):
                if expected["ms"] != actual["ms"]:
                    raise ValueError(f"{sid}: clock mismatch")
                joints = []
                for name in names:
                    joint = actual["keypoints"].get(name)
                    if joint and not all(map(math.isfinite, joint)):
                        raise ValueError(f"{sid}: non-finite joint")
                    joints.append([joint[0], joint[1], joint[3]] if joint else None)
                counts["missing_pose"] += all(j is None for j in joints)
                frames.append([expected["index"], expected["ms"], joints])
            counts["frames"] += len(frames)
            counts["sources"] += 1
            out.write(json.dumps({**row, "frames": frames}, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n")
    (output / "replay.partial").replace(output / "replay.jsonl")
    write_json(output / "coverage.json", {**counts, "replay_sha256": digest(output / "replay.jsonl"),
               "units_sha256": digest(output / "units.jsonl")})
    print(dict(counts), flush=True)


def claim(path):
    """Return an open file with an exclusive OS lock, or None if another worker owns it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    file = path.open("a+b")
    if not path.stat().st_size:
        file.write(b"0")
        file.flush()
    file.seek(0)
    try:
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        file.close()
        return None
    return file


def split_index(benchmark, split):
    sources = {r["source_id"]: r for r in records(benchmark / "units.jsonl") if r["split"] == split}
    offsets, frame_sizes = {}, {}
    with (benchmark / "replay.jsonl").open("rb") as file:
        while True:
            where = file.tell()
            line = file.readline()
            if not line:
                break
            row = json.loads(line)
            if row["source_id"] in sources:
                offsets[row["source_id"]] = where
                frame_sizes[row["source_id"]] = len(row["frames"])
    if set(offsets) != set(sources):
        raise ValueError("input replay does not match split manifest")
    return sources, offsets, frame_sizes


def verify_checkpoint(folder, benchmark, sources, offsets):
    """Pair every native row, sidecar, and original reference before reuse."""
    coverage = folder / "coverage.json"
    summary = json.loads(coverage.read_text())
    replay_hash, units_hash = digest(folder / "replay.jsonl"), digest(folder / "units.jsonl")
    if replay_hash != summary["replay_sha256"] or summary.get("units_sha256", units_hash) != units_hash:
        raise ValueError(f"changed native checkpoint: {folder}")
    ids, counts = set(), Counter()
    with (benchmark / "replay.jsonl").open("rb") as reference:
        for native, sidecar in zip(records(folder / "replay.jsonl"), records(folder / "units.jsonl"), strict=True):
            sid = native["source_id"]
            if sid in ids or sid not in sources:
                raise ValueError(f"{folder}: duplicate or unscheduled source {sid}")
            ids.add(sid)
            native_frames = native.pop("frames")
            reference.seek(offsets[sid])
            original = json.loads(reference.readline())
            timing = [(f[0], f[1]) for f in original.pop("frames")]
            if native != sidecar or original != sources[sid] or {k: v for k, v in native.items() if k != "detector"} != original:
                raise ValueError(f"{sid}: sidecar/reference IDs, labels, boundaries, or source metadata changed")
            if [(f[0], f[1]) for f in native_frames] != timing:
                raise ValueError(f"{sid}: native frames not paired with source timestamps")
            counts["sources"] += 1
            counts["frames"] += len(native_frames)
            counts["missing_pose"] += sum(all(j is None for j in f[2]) for f in native_frames)
    if any(summary[k] != counts[k] for k in ("sources", "frames", "missing_pose")):
        raise ValueError(f"{folder}: coverage disagreement")
    if "units_sha256" not in summary:
        # Upgrade early, already-frozen captures only AFTER checking every
        # sidecar field and every clock pair against both independent inputs.
        write_json(coverage, {**summary, "units_sha256": units_hash})
    return ids


def full_split(args):
    run = args.output
    run.mkdir(parents=True, exist_ok=True)
    sources, offsets, frame_sizes = split_index(args.benchmark, args.all_split)
    completed = {}

    def add_capture(path):
        for sid in verify_checkpoint(path, args.benchmark, sources, offsets):
            if sid in completed:
                raise ValueError(f"{sid}: incompatible or duplicate capture")
            completed[sid] = path

    if args.reuse:
        add_capture(args.reuse)
    batch_root = run / "batches"
    batch_root.mkdir(exist_ok=True)
    # Stable batches across restarts. Reused sources are always excluded.
    batches, current, frames = [], [], 0
    for sid in sorted(set(sources) - set(completed)):
        current.append(sources[sid])
        frames += frame_sizes[sid]
        if frames >= 2600 or len(current) >= 36:
            batches.append(current)
            current, frames = [], 0
    if current:
        batches.append(current)
    todo = []
    for i, batch in enumerate(batches, 1):
        out = batch_root / f"batch-{i:03d}"
        if (out / "coverage.json").exists():
            add_capture(out)
        else:
            todo.append((batch, out))
    print(f"{args.all_split}: {len(sources)} sources / {sum(frame_sizes.values())} frames; {len(completed)} reused, {len(todo)} pending batches", flush=True)

    def captured(out):
        return (out / "android-results.json").is_file() and (out / "runtime.json").is_file()

    def prepare_batch(entry):
        batch, out = entry
        if shutil.disk_usage(run).free < 1_500_000_000:
            raise RuntimeError("host needs at least 1.5 GB of scratch")
        if not captured(out):
            prepare(args.benchmark, out, len(batch), explicit=batch, offsets=offsets)

    # Separate read-only copies of the dedicated AVD can share a host queue.
    # Each batch is locked through extraction, inference and publication.
    queue = iter(reversed(todo) if args.reverse else todo)
    def take_next(stack):
        for batch, out in queue:
            lock = claim(out / ".capture.lock")
            if lock is None:
                continue
            if (out / "coverage.json").exists():
                lock.close()
                continue
            stack.callback(lock.close)
            return batch, out
        return None

    with ThreadPoolExecutor(max_workers=1) as worker, ExitStack() as locks:
        active = take_next(locks)
        future = worker.submit(prepare_batch, active) if active else None
        while active:
            _, out = active
            future.result()
            following = take_next(locks)
            if following:
                future = worker.submit(prepare_batch, following)
            if not captured(out):
                capture(args, out)
            convert(args, out)
            add_capture(out)
            # Keep manifests, raw native observations and replay. JPEGs can be
            # reproduced byte-for-byte, so only discard the listed inputs.
            for clip in json.loads((out / "inputs/manifest.json").read_text()):
                for frame in clip["frames"]:
                    name = frame["file"]
                    if not re.fullmatch(r"[A-Za-z0-9_-]+_\d+[.]jpg", name):
                        raise ValueError(f"unexpected scratch filename {name}")
                    (out / "inputs" / name).unlink(missing_ok=True)
            print(f"{args.all_split}: native results persisted for {len(completed)}/{len(sources)} sources", flush=True)
            active = following
    for i, batch in enumerate(batches, 1):
        out = batch_root / f"batch-{i:03d}"
        if batch[0]["source_id"] not in completed and (out / "coverage.json").exists():
            add_capture(out)
    if set(completed) != set(sources):
        print("Other worker owns the remaining batch(es); the last worker publishes the split.", flush=True)
        return
    publish_lock = claim(run / ".publish.lock")
    if publish_lock is None:
        return
    try:
        publish_split(run, completed, sources, frame_sizes, args, batches)
    finally:
        publish_lock.close()


def publish_split(run, completed, sources, frame_sizes, args, batches):
    captures = sorted(set(completed.values()), key=lambda path: path.as_posix())
    with (run / "replay.partial").open("wb") as replay, (run / "units.partial").open("w", encoding="utf-8", newline="\n") as units:
        for capture_dir in captures:
            with (capture_dir / "replay.jsonl").open("rb") as file:
                for line in file:
                    replay.write(line)
                    metadata = json.loads(line)
                    del metadata["frames"]
                    units.write(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")) + "\n")
    for name in ("replay", "units"):
        (run / f"{name}.partial").replace(run / f"{name}.jsonl")
    details = [json.loads((path / "coverage.json").read_text()) for path in captures]
    audit = {k: sum(d[k] for d in details) for k in ("sources", "frames", "missing_pose")}
    if audit["sources"] != len(sources) or audit["frames"] != sum(frame_sizes.values()):
        raise ValueError("aggregate missing frames or sources")
    write_json(run / "coverage.json", {**audit, "replay_sha256": digest(run / "replay.jsonl"),
              "units_sha256": digest(run / "units.jsonl"), "split": args.all_split,
              "reused": str(args.reuse) if args.reuse else None, "batches": len(batches)})
    print(args.all_split, audit, flush=True)


def combine(args):
    """Verify frame-by-frame pairing with the original corpus and publish both splits."""
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    original = {}
    for row in records(args.benchmark / "replay.jsonl"):
        timeline = [(f[0], f[1]) for f in row.pop("frames")]
        original[row["source_id"]] = (row, timeline)
    groups, seen, splits = {}, set(), {}
    aggregate = Counter()
    with (output / "replay.partial").open("wb") as poses, (output / "units.partial").open("w", encoding="utf-8", newline="\n") as units:
        for split in ("development", "holdout"):
            folder = args.benchmark / f"native-{split}"
            summary = json.loads((folder / "coverage.json").read_text())
            for item in ("replay", "units"):
                if digest(folder / f"{item}.jsonl") != summary[f"{item}_sha256"]:
                    raise ValueError(f"{split}: changed {item}")
            counts = Counter()
            for row, sidecar in zip(records(folder / "replay.jsonl"), records(folder / "units.jsonl"), strict=True):
                sid = row["source_id"]
                source, timeline = original[sid]
                group = row["group_id"]
                if sid in seen or row["split"] != split or groups.setdefault(group, split) != split:
                    raise ValueError(f"{sid}: duplicate source or split leakage")
                seen.add(sid)
                if source != {k: v for k, v in row.items() if k not in ("detector", "frames")}:
                    raise ValueError(f"{sid}: native/legacy metadata mismatch")
                native_metadata = {k: v for k, v in row.items() if k != "frames"}
                if native_metadata != sidecar:
                    raise ValueError(f"{sid}: native scoring sidecar differs from verified metadata")
                units.write(json.dumps(native_metadata, ensure_ascii=False, separators=(",", ":")) + "\n")
                if [(t[0], t[1]) for t in row["frames"]] != timeline:
                    raise ValueError(f"{sid}: native/legacy clocks differ")
                counts["sources"] += 1
                counts["units"] += len(row["units"])
                counts["frames"] += len(timeline)
                counts["missing_pose"] += sum(all(j is None for j in t[2]) for t in row["frames"])
            if any(counts[k] != summary[k] for k in ("sources", "frames", "missing_pose")):
                raise ValueError(f"{split}: checkpoint count disagreement")
            counts["groups"] = sum(v == split for v in groups.values())
            splits[split] = {**counts, "replay_sha256": summary["replay_sha256"], "units_sha256": summary["units_sha256"]}
            aggregate.update(counts)
            with (folder / "replay.jsonl").open("rb") as src:
                shutil.copyfileobj(src, poses)
    if seen != set(original):
        raise ValueError("combined native capture omits sources")
    apk = args.evaluator / "build/app/outputs/flutter-apk/app-debug.apk"
    apk_sha = digest(apk)
    capture_dirs = []
    for split in ("development", "holdout"):
        folder = args.benchmark / f"native-{split}"
        split_coverage = json.loads((folder / "coverage.json").read_text())
        batch_paths = [p.parent for p in (folder / "batches").glob("*/coverage.json")]
        if len(batch_paths) != split_coverage["batches"]:
            raise ValueError(f"{split}: missing checkpoint provenance")
        capture_dirs.extend(batch_paths)
        reused = split_coverage.get("reused")
        if reused:
            capture_dirs.append(Path(reused))
    for capture_dir in capture_dirs:
        runtime = json.loads((capture_dir / "runtime.json").read_text())
        if (runtime["apk_sha256"], runtime["plugin"], runtime["mode"], runtime["avd"], runtime["abi"],
                runtime["api"], runtime["input"]) != (
            apk_sha, "0.16.1", "accurate/stream", "gymrats_pose_eval", "x86_64", "36", "upright JPEG quality 95"
        ):
            raise ValueError(f"{capture_dir}: unexpected native detector or evaluator")
    with zipfile.ZipFile(apk) as package:
        artifact = package.read("pose-detection-accurate.properties").decode()
        version = re.search(r"^version=(.+)$", artifact, re.MULTILINE).group(1)
        model = package.read("assets/mlkit_pose/pose_landmark_detector_full_f16_inf.tflite")
    for tmp, final in (("replay.partial", "replay.jsonl"), ("units.partial", "units.jsonl")):
        (output / tmp).replace(output / final)
    write_json(output / "coverage.json", {"schema": "gymrats-nine-native-paired-v1",
               "extractor": "Android ML Kit accurate/stream; plugin 0.16.1; upright JPEG quality 95",
               "live_input_difference": "Android live camera sends NV21 with rotation metadata",
               "native_android_artifact": f"com.google.mlkit:pose-detection-accurate:{version}",
               "apk_sha256": apk_sha, "native_full_landmark_tflite_sha256": hashlib.sha256(model).hexdigest(),
               "pairing": "verified frame indices, times, original SHA-256, dimensions, all original units and group partitions",
               "reference_coverage_sha256": digest(args.benchmark / "replay-audit.json"),
               "replay_sha256": digest(output / "replay.jsonl"), "units_sha256": digest(output / "units.jsonl"),
               "counts": aggregate, "splits": splits})
    print(dict(aggregate), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark", type=Path, required=True)
    parser.add_argument("--evaluator", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--count", type=int, default=36)
    parser.add_argument("--adb", type=Path, default=Path(os.getenv("LOCALAPPDATA", ".")) / "Android/Sdk/platform-tools/adb.exe")
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--steps", choices=("all", "prepare", "capture", "convert"), default="all")
    parser.add_argument("--all-split", choices=("holdout", "development"), help="checkpoint all originals in the specified split")
    parser.add_argument("--reverse", action="store_true", help="claim batches from the opposite end using a second dedicated read-only AVD")
    parser.add_argument("--reuse", type=Path, help="previously verified subset of the same split")
    parser.add_argument("--combine", action="store_true", help="verify and concatenate the two completed native splits")
    parser.add_argument("--verify-only", choices=("holdout", "development"), help="audit each completed batch and the aggregate against original units and clocks")
    args = parser.parse_args()
    if args.combine:
        combine(args)
        return
    if args.verify_only:
        sources, offsets, _ = split_index(args.benchmark, args.verify_only)
        checkpoints = sorted(p.parent for p in (args.output / "batches").glob("*/coverage.json"))
        if args.reuse:
            checkpoints.append(args.reuse)
        checked = set()
        for path in checkpoints:
            ids = verify_checkpoint(path, args.benchmark, sources, offsets)
            if ids & checked:
                raise ValueError("duplicate checkpoint")
            checked.update(ids)
        combined = verify_checkpoint(args.output, args.benchmark, sources, offsets)
        if checked != set(sources) or checked != combined:
            raise ValueError("partial aggregate")
        write_json(args.output / "verified.json", {"groups": len({r["group_id"] for r in sources.values()}),
                   "sources": len(checked), "checkpoints": len(checkpoints), "coverage_sha256": digest(args.output / "coverage.json"),
                   "verified": "all native/replay/sidecar/reference metadata and original frame/time pairs"})
        return
    if args.all_split:
        full_split(args)
        return
    if args.steps in ("all", "prepare"):
        prepare(args.benchmark, args.output, args.count)
    if args.steps in ("all", "capture"):
        capture(args, args.output)
    if args.steps in ("all", "convert"):
        convert(args, args.output)


if __name__ == "__main__":
    main()

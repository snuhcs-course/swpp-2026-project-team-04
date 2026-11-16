"""Prepare paired JPEG inputs and check RTMPose ONNX inference on the CPU.

The Android benchmark consumes device-manifest.json and its images directory.
CPU outputs are for preprocessing/inference parity and offline diagnostics.
Official exported pipelines use RGB, 1.25 full-frame padding, 192x256 affine
input, and SimCC argmax coordinates divided by two.
"""

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import time

import cv2
import numpy as np


PREPROCESS_VERSION = "rtmpose-full-frame-rgb-affine-v1"
INPUT_WIDTH, INPUT_HEIGHT = 192, 256
MEAN = np.asarray([123.675, 116.28, 103.53], dtype=np.float32)
STD = np.asarray([58.395, 57.12, 57.375], dtype=np.float32)
COCO_TO_MLKIT = (0, 2, 5, 7, 8, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2,
                                    allow_nan=False) + "\n", encoding="utf-8")
    for attempt in range(6):
        try:
            temporary.replace(path)
            return
        except PermissionError:
            if attempt == 5:
                raise
            time.sleep(.05 * (2 ** attempt))


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def validate_key(key):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", key):
        raise ValueError(f"Unsafe or unsupported frame key {key!r}")


def prepare(args):
    manifest = load_json(args.manifest)
    frames = manifest["frames"]
    keys = [frame["key"] for frame in frames]
    if len(keys) != len(set(keys)):
        raise ValueError("Duplicate frame keys")
    identity = {"manifest_sha256": digest(args.manifest), "opencv_version": cv2.__version__,
                "jpeg_quality": 95, "decode": "OpenCV sequential upright original frame"}
    args.out.mkdir(parents=True, exist_ok=True)
    images = args.out / "images"
    images.mkdir(exist_ok=True)
    state_path = args.out / "preparation-state.json"
    state = load_json(state_path) if state_path.exists() else {"identity": identity, "images": {}}
    if state["identity"] != identity:
        raise ValueError("Existing preparation belongs to a different manifest or decoder configuration")
    if set(state["images"]) - set(keys):
        raise ValueError("Preparation state contains frames outside this manifest")
    by_source = defaultdict(list)
    for frame in frames:
        validate_key(frame["key"])
        by_source[frame["source_id"]].append(frame)
    completed = 0
    for source_id, members in sorted(by_source.items()):
        members.sort(key=lambda frame: frame["index"])
        first = members[0]
        stable = ("source_path", "source_sha256", "width", "height")
        if any(any(frame[field] != first[field] for field in stable) for frame in members):
            raise ValueError(f"Inconsistent source metadata for {source_id}")
        source = Path(first["source_path"])
        if digest(source) != first["source_sha256"]:
            raise ValueError(f"Original video hash changed for {source_id}")
        pending = []
        for frame in members:
            image_path = images / f"{frame['key']}.jpg"
            expected = state["images"].get(frame["key"])
            if expected and image_path.is_file() and digest(image_path) == expected["sha256"]:
                decoded = cv2.imread(str(image_path))
                if decoded is not None and decoded.shape[:2] == (frame["height"], frame["width"]):
                    continue
            pending.append(frame)
        if pending:
            capture = cv2.VideoCapture(str(source))
            capture.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)
            read_index = -1
            try:
                for frame in pending:
                    while read_index < frame["index"]:
                        if not capture.grab():
                            raise ValueError(f"Video {source_id} ended before frame {frame['index']}")
                        read_index += 1
                    ok, image = capture.retrieve()
                    if not ok or image.shape[:2] != (frame["height"], frame["width"]):
                        raise ValueError(f"Upright dimensions disagree for {frame['key']}")
                    ok, encoded = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 95])
                    if not ok:
                        raise ValueError(f"JPEG encoding failed for {frame['key']}")
                    image_path = images / f"{frame['key']}.jpg"
                    temporary = image_path.with_suffix(".jpg.tmp")
                    temporary.write_bytes(encoded.tobytes())
                    temporary.replace(image_path)
                    state["images"][frame["key"]] = {"sha256": digest(image_path), "bytes": image_path.stat().st_size}
            finally:
                capture.release()
        save_json(state_path, state)
        completed += len(members)
        print(f"Prepared {completed}/{len(frames)} frames ({source_id})", flush=True)
    input_copy = args.out / "evaluation-manifest.json"
    temporary = input_copy.with_suffix(".json.tmp")
    temporary.write_bytes(args.manifest.read_bytes())
    temporary.replace(input_copy)
    device_frames = []
    for frame in frames:
        record = {field: frame[field] for field in ("key", "source_id", "index", "width", "height")}
        record.update(file=f"images/{frame['key']}.jpg", sha256=state["images"][frame["key"]]["sha256"])
        device_frames.append(record)
    device_manifest = {"schema": "gymrats-mobile-pose-input-v1", "source_manifest_sha256": identity["manifest_sha256"],
                       "preparation": identity, "frames": device_frames}
    save_json(args.out / "device-manifest.json", device_manifest)
    print(json.dumps({"frames": len(frames), "sources": len(by_source),
                      "image_bytes": sum(row["bytes"] for row in state["images"].values()),
                      "output": str(args.out)}, indent=2))


def affine_parameters(width, height):
    center = np.asarray([width * .5, height * .5], dtype=np.float32)
    scale = np.asarray([width * 1.25, height * 1.25], dtype=np.float32)
    aspect = INPUT_WIDTH / INPUT_HEIGHT
    if scale[0] > scale[1] * aspect:
        scale[1] = scale[0] / aspect
    else:
        scale[0] = scale[1] * aspect
    source = np.asarray([center, center + [0., -scale[0] * .5],
                         center + [-scale[0] * .5, -scale[0] * .5]], dtype=np.float32)
    target = np.asarray([[INPUT_WIDTH * .5, INPUT_HEIGHT * .5],
                         [INPUT_WIDTH * .5, INPUT_HEIGHT * .5 - INPUT_WIDTH * .5],
                         [0., INPUT_HEIGHT * .5 - INPUT_WIDTH * .5]], dtype=np.float32)
    matrix = cv2.getAffineTransform(source, target)
    return center, scale, matrix


def preprocess_rgb(rgb):
    if rgb.dtype != np.uint8 or rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError("Expected original uint8 RGB image")
    height, width = rgb.shape[:2]
    center, scale, matrix = affine_parameters(width, height)
    warped = cv2.warpAffine(rgb, matrix, (INPUT_WIDTH, INPUT_HEIGHT),
                            flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    normalized = (warped.astype(np.float32) - MEAN) / STD
    tensor = np.ascontiguousarray(normalized.transpose(2, 0, 1)[None], dtype=np.float32)
    metadata = {"version": PREPROCESS_VERSION, "source_width": width, "source_height": height,
                "center": center.tolist(), "scale": scale.tolist(), "source_to_input_affine": matrix.tolist(),
                "input_shape": list(tensor.shape), "layout": "NCHW", "dtype": "little-endian float32",
                "channel_order": "RGB", "mean": MEAN.tolist(), "std": STD.tolist(),
                "warp": "OpenCV INTER_LINEAR, constant zero uint8 RGB border"}
    return tensor, warped, metadata


def dump_golden(image_path, output, key="golden"):
    validate_key(key)
    bgr = cv2.imread(str(image_path))
    if bgr is None:
        raise ValueError(f"Cannot decode {image_path}")
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    tensor, warped, metadata = preprocess_rgb(rgb)
    output.mkdir(parents=True, exist_ok=True)
    paths = {"input_tensor": output / f"{key}.input.f32", "decoded_rgb": output / f"{key}.decoded.rgb",
             "warped_rgb": output / f"{key}.warped.rgb"}
    tensor.astype("<f4", copy=False).tofile(paths["input_tensor"])
    rgb.tofile(paths["decoded_rgb"])
    warped.tofile(paths["warped_rgb"])
    metadata.update(image_sha256=digest(image_path), opencv_version=cv2.__version__,
                    files={name: {"file": path.name, "sha256": digest(path)} for name, path in paths.items()})
    save_json(output / f"{key}.json", metadata)
    return tensor, metadata


def decode_simcc(simcc_x, simcc_y, metadata):
    simcc_x, simcc_y = np.asarray(simcc_x), np.asarray(simcc_y)
    if simcc_x.shape != (1, 17, INPUT_WIDTH * 2) or simcc_y.shape != (1, 17, INPUT_HEIGHT * 2):
        raise ValueError(f"Unexpected SimCC shapes {simcc_x.shape}, {simcc_y.shape}")
    center, scale = np.asarray(metadata["center"]), np.asarray(metadata["scale"])
    points = [None] * 33
    for source, destination in enumerate(COCO_TO_MLKIT):
        x, y = simcc_x[0, source], simcc_y[0, source]
        if not np.isfinite(x).all() or not np.isfinite(y).all():
            continue
        score = float(min(np.max(x), np.max(y)))
        if score <= 0:
            continue
        location = np.asarray([int(np.argmax(x)), int(np.argmax(y))], dtype=np.float32) / 2
        original = location / [INPUT_WIDTH, INPUT_HEIGHT] * scale + center - scale * .5
        points[destination] = [float(original[0]), float(original[1]), score]
    return points


def validate_pipeline(path):
    pipeline = load_json(path)["pipeline"]["tasks"]
    transforms = {row["type"]: row for row in pipeline[0]["transforms"]}
    bbox, affine = transforms["TopDownGetBboxCenterScale"], transforms["TopDownAffine"]
    normal = transforms["Normalize"]
    decoder = pipeline[-1]["params"]
    if bbox["padding"] != 1.25 or affine["image_size"] != [INPUT_WIDTH, INPUT_HEIGHT]:
        raise ValueError("Unsupported exported crop/affine configuration")
    if normal["to_rgb"] is not True or not np.allclose(normal["mean"], MEAN) or not np.allclose(normal["std"], STD):
        raise ValueError("Unsupported exported normalization")
    if decoder["simcc_split_ratio"] != 2 or decoder["use_dark"] or decoder["normalize"] or decoder["flip_test"]:
        raise ValueError("Unsupported exported SimCC decoder")


def existing_predictions(path, expected_keys):
    result = {}
    if not path.exists():
        return result
    with path.open(encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            key = row["key"]
            if key not in expected_keys or key in result:
                raise ValueError(f"Unexpected or duplicate previous prediction {key}")
            result[key] = row
    return result


def infer(args):
    import onnxruntime as ort
    manifest = load_json(args.manifest)
    frames = manifest["frames"]
    keys = {frame["key"] for frame in frames}
    if len(keys) != len(frames):
        raise ValueError("Duplicate input frame keys")
    pipeline = args.pipeline or args.model.with_name(args.model.stem + "-pipeline.json")
    validate_pipeline(pipeline)
    identity = {"manifest_sha256": digest(args.manifest), "model_sha256": digest(args.model),
                "pipeline_sha256": digest(pipeline), "preprocessing": PREPROCESS_VERSION,
                "onnxruntime_version": ort.__version__, "opencv_version": cv2.__version__,
                "provider": "CPUExecutionProvider", "intra_op_threads": args.threads}
    run_path = args.out.with_suffix(".run.json")
    if run_path.exists() and load_json(run_path)["identity"] != identity:
        raise ValueError("Existing inference belongs to a different model, manifest or runtime")
    if args.out.exists() and not run_path.exists():
        raise ValueError("Existing predictions lack provenance; choose a fresh output")
    previous = existing_predictions(args.out, keys)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    save_json(run_path, {"identity": identity, "completed": len(previous), "total": len(frames),
                         "complete": len(previous) == len(frames), "purpose": "CPU parity/offline analysis"})
    options = ort.SessionOptions()
    options.intra_op_num_threads = args.threads
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(args.model), sess_options=options, providers=["CPUExecutionProvider"])
    input_info = session.get_inputs()[0]
    if input_info.shape[1:] != [3, INPUT_HEIGHT, INPUT_WIDTH]:
        raise ValueError(f"Unexpected ONNX input {input_info.shape}")
    if {item.name for item in session.get_outputs()} != {"simcc_x", "simcc_y"}:
        raise ValueError("Expected named SimCC outputs")
    count = 0
    with args.out.open("a", encoding="utf-8", newline="\n") as stream:
        for frame in frames:
            image_path = args.manifest.parent / frame["file"]
            if digest(image_path) != frame["sha256"]:
                raise ValueError(f"Prepared image changed for {frame['key']}")
            if frame["key"] in previous:
                if previous[frame["key"]]["image_sha256"] != frame["sha256"]:
                    raise ValueError(f"Previous prediction has different image for {frame['key']}")
                continue
            bgr = cv2.imread(str(image_path))
            if bgr is None or bgr.shape[:2] != (frame["height"], frame["width"]):
                raise ValueError(f"Prepared dimensions disagree for {frame['key']}")
            start = time.perf_counter()
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            tensor, _, metadata = preprocess_rgb(rgb)
            preprocess_ms = (time.perf_counter() - start) * 1000
            if count == 0:
                if args.golden_dir:
                    dump_golden(image_path, args.golden_dir, frame["key"])
                for _ in range(args.warmup):
                    session.run(["simcc_x", "simcc_y"], {input_info.name: tensor})
            start = time.perf_counter()
            output = session.run(["simcc_x", "simcc_y"], {input_info.name: tensor})
            inference_ms = (time.perf_counter() - start) * 1000
            points = decode_simcc(*output, metadata)
            row = {"key": frame["key"], "points": points, "image_sha256": frame["sha256"],
                   "preprocess_ms": preprocess_ms, "inference_ms": inference_ms,
                   "runtime": "onnxruntime CPU"}
            stream.write(json.dumps(row, separators=(",", ":"), allow_nan=False) + "\n")
            stream.flush()
            previous[frame["key"]] = row
            count += 1
            save_json(run_path, {"identity": identity, "completed": len(previous), "total": len(frames),
                                 "complete": len(previous) == len(frames), "purpose": "CPU parity/offline analysis"})
            print(f"CPU {len(previous)}/{len(frames)} {frame['key']} {inference_ms:.1f} ms", flush=True)
            if args.limit is not None and count >= args.limit:
                break


def self_test():
    import unittest

    class Checks(unittest.TestCase):
        def test_atomic_status_retries_transient_windows_lock(self):
            import tempfile
            from unittest.mock import patch
            original = Path.replace
            attempts = []

            def replace_with_first_lock(path, target):
                attempts.append(path)
                if len(attempts) == 1:
                    raise PermissionError("transient file reader")
                return original(path, target)

            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "status.json"
                with patch.object(Path, "replace", replace_with_first_lock), patch.object(time, "sleep"):
                    save_json(path, {"completed": 1})
                self.assertEqual(load_json(path), {"completed": 1})
                self.assertEqual(len(attempts), 2)

        def test_affine_center_and_scale(self):
            for width, height in ((640, 480), (480, 640), (1920, 1080)):
                center, scale, matrix = affine_parameters(width, height)
                mapped = matrix @ np.r_[center, 1.]
                np.testing.assert_allclose(mapped, [96., 128.], atol=1e-6)
                self.assertAlmostEqual(float(scale[0] / scale[1]), .75)

        def test_rgb_order_normalization_and_shape(self):
            rgb = np.empty((640, 480, 3), dtype=np.uint8)
            rgb[:] = [255, 127, 0]
            tensor, warped, _ = preprocess_rgb(rgb)
            self.assertEqual(tensor.shape, (1, 3, 256, 192))
            self.assertEqual(tensor.dtype, np.float32)
            np.testing.assert_equal(warped[128, 96], [255, 127, 0])
            np.testing.assert_allclose(tensor[0, :, 128, 96], (np.array([255., 127., 0.]) - MEAN) / STD,
                                       atol=1e-6)

        def test_simcc_mapping_and_inverse(self):
            _, _, metadata = preprocess_rgb(np.zeros((640, 480, 3), np.uint8))
            x, y = np.zeros((1, 17, 384)), np.zeros((1, 17, 512))
            x[:, :, 192], y[:, :, 256] = 2., 3.
            points = decode_simcc(x, y, metadata)
            self.assertEqual(len(points), 33)
            self.assertEqual(sum(point is not None for point in points), 17)
            np.testing.assert_allclose(points[25], [240., 320., 2.])
            self.assertIsNone(points[29])
            x[0, 13] = 0
            self.assertIsNone(decode_simcc(x, y, metadata)[25])

        def test_keys_cannot_escape_directory(self):
            validate_key("Q00001__f000012")
            with self.assertRaises(ValueError):
                validate_key("../other")

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks))
    if not result.wasSuccessful():
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--manifest", type=Path, required=True)
    prepare_parser.add_argument("--out", type=Path, required=True)
    infer_parser = commands.add_parser("infer")
    infer_parser.add_argument("--manifest", type=Path, required=True, help="Prepared device-manifest.json")
    infer_parser.add_argument("--model", type=Path, required=True)
    infer_parser.add_argument("--pipeline", type=Path)
    infer_parser.add_argument("--out", type=Path, required=True)
    infer_parser.add_argument("--threads", type=int, default=2)
    infer_parser.add_argument("--warmup", type=int, default=3)
    infer_parser.add_argument("--limit", type=int)
    infer_parser.add_argument("--golden-dir", type=Path)
    golden_parser = commands.add_parser("golden")
    golden_parser.add_argument("--image", type=Path, required=True)
    golden_parser.add_argument("--out", type=Path, required=True)
    commands.add_parser("self-test")
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args)
    elif args.command == "infer":
        if args.threads < 1 or args.warmup < 0 or (args.limit is not None and args.limit < 1):
            parser.error("Threads and limit must be positive; warmup must be nonnegative")
        infer(args)
    elif args.command == "golden":
        dump_golden(args.image, args.out)
    else:
        self_test()


if __name__ == "__main__":
    main()

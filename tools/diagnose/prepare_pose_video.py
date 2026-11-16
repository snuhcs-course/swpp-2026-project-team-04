"""Extract timestamped frames for the on-device GymRats ML Kit replay."""
import argparse
import json
from pathlib import Path

import cv2

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--fps', type=float, default=10)
parser.add_argument('--auto-crop', action='store_true', help='fixed padded person crop for the whole clip')
parser.add_argument('videos', type=Path, nargs='+')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
detector = None
if args.auto_crop:
    import mediapipe as mp
    detector = mp.tasks.vision.PoseLandmarker.create_from_options(
        mp.tasks.vision.PoseLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=r'C:\SWPP\iter4\pushup-reference-videos\pose_landmarker_lite.task'),
            running_mode=mp.tasks.vision.RunningMode.IMAGE,
            num_poses=1))
manifest = []
for number, video in enumerate(args.videos):
    cap = cv2.VideoCapture(str(video))
    fps = cap.get(cv2.CAP_PROP_FPS)
    if not cap.isOpened() or fps <= 0:
        raise ValueError(f'Cannot read video: {video}')
    crop = None
    if detector:
        w, h = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        visible = []
        for k in range(12):
            cap.set(cv2.CAP_PROP_POS_FRAMES, int(k * max(count - 1, 0) / 11))
            ok, sample = cap.read()
            if not ok:
                continue
            image = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(sample, cv2.COLOR_BGR2RGB))
            result = detector.detect(image)
            if result.pose_landmarks:
                visible += [(p.x * w, p.y * h) for p in result.pose_landmarks[0] if p.visibility > .65]
        if len(visible) >= 50:
            xs, ys = zip(*visible)
            x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
            pad = max(x1-x0, y1-y0) * .35
            crop = (max(0, int(x0-pad)), max(0, int(y0-pad)), min(w, int(x1+pad+1)), min(h, int(y1+pad+1)))
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
    frames = []
    next_ms = 0.0
    index = 0
    width = height = 0
    while True:
        ok, image = cap.read()
        if not ok:
            break
        ms = index * 1000 / fps
        index += 1
        if ms + 0.01 < next_ms:
            continue
        if crop:
            x0, y0, x1, y1 = crop
            image = image[y0:y1, x0:x1]
        height, width = image.shape[:2]
        name = f'clip{number:03d}_frame{len(frames):05d}.jpg'
        if not cv2.imwrite(str(args.output / name), image):
            raise OSError(name)
        frames.append({'file': name, 'ms': round(ms)})
        next_ms += 1000 / args.fps
    cap.release()
    manifest.append({'clip': str(video), 'width': width, 'height': height, 'crop': crop, 'frames': frames})
    print(video.name, len(frames), 'frames', flush=True)
(args.output / 'manifest.json').write_text(json.dumps(manifest), encoding='utf8')
if detector:
    detector.close()

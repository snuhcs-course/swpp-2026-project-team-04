"""Exploratory clip-level baseline; NOT an ML Kit rep-judge validation.

The subject split prevents different views of one person leaking across sets.
Download MediaPipe's pose_landmarker_lite.task alongside the video corpus.
"""
import json
import re
from pathlib import Path

import cv2
import joblib
import mediapipe as mp
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, confusion_matrix

ROOT = Path(r'C:\SWPP\iter4\pushup-reference-videos')
CORPUS = ROOT / 'mendeley-multiview'
OUT = ROOT / 's1-reference-experiment.json'
model = ROOT / 'pose_landmarker_lite.task'
options = mp.tasks.vision.PoseLandmarkerOptions(
    base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),
    running_mode=mp.tasks.vision.RunningMode.IMAGE,
    num_poses=1,
    min_pose_detection_confidence=0.5,
)


def features(detector, path):
    capture = cv2.VideoCapture(str(path))
    count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    poses = []
    for index in np.linspace(0.1, 0.9, 8):
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(index * max(count - 1, 0)))
        ok, image = capture.read()
        if not ok:
            continue
        h, w = image.shape[:2]
        image = cv2.resize(image, (int(w * 480 / max(w, h)), int(h * 480 / max(w, h))))
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        result = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
        if not result.pose_landmarks:
            continue
        a = np.array([[p.x, p.y, p.z] for p in result.pose_landmarks[0]], dtype=float)
        center = (a[23] + a[24]) / 2
        scale = np.linalg.norm((a[11] + a[12]) / 2 - center)
        poses.append(((a - center) / max(scale, 0.03)).flatten())
    capture.release()
    if len(poses) < 3:
        return None
    poses = np.array(poses)
    return np.concatenate([poses.mean(axis=0), poses.std(axis=0)]).tolist()


records = []
files = sorted(CORPUS.rglob('*.mp4'))
with mp.tasks.vision.PoseLandmarker.create_from_options(options) as detector:
    for n, path in enumerate(files, 1):
        label, view = path.relative_to(CORPUS).parts[:2]
        match = re.search(r'subject_(\d+)', path.name)
        vector = features(detector, path)
        records.append({'file': str(path.relative_to(ROOT)), 'subject': int(match.group(1)),
                        'view': view, 'label': label, 'features': vector})
        print(f'{n}/{len(files)} {path.name}: {"ok" if vector else "no pose"}', flush=True)

results = {'method': 'MediaPipe lite, 8 sampled frames; random forest; subjects 1-18 train, 19-24 test',
           'warning': 'Exploratory good/bad CLIP labels only; not rep accuracy or ML Kit; no S2 identity labels.',
           'total': len(records), 'missing_pose': [r['file'] for r in records if r['features'] is None],
           'experiments': {}}
for name, selected in [('all_views', records), ('front_only', [r for r in records if r['view'] == 'front'])]:
    train = [r for r in selected if r['subject'] <= 18 and r['features'] is not None]
    test = [r for r in selected if r['subject'] > 18 and r['features'] is not None]
    classifier = RandomForestClassifier(n_estimators=200, min_samples_leaf=2, random_state=4, n_jobs=-1)
    classifier.fit([r['features'] for r in train], [r['label'] for r in train])
    joblib.dump(classifier, ROOT / f's1-exploratory-{name}-classifier.joblib')
    predictions = classifier.predict([r['features'] for r in test])
    labels = [r['label'] for r in test]
    results['experiments'][name] = {'train_clips': len(train), 'test_clips': len(test),
        'accuracy': accuracy_score(labels, predictions),
        'confusion_labels': ['bad', 'good'],
        'confusion_matrix': confusion_matrix(labels, predictions, labels=['bad', 'good']).tolist(),
        'predictions': [{'file': r['file'], 'actual': r['label'], 'predicted': pred}
                        for r, pred in zip(test, predictions)]}
OUT.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(results['experiments'], ensure_ascii=False, indent=2), flush=True)

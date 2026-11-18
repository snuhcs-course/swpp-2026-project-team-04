"""Import native ML Kit coordinates; never copy videos or infer ground truth.

The user/PM authorizes two selected recorder folders. Native exports contain
full-frame JPEG95 observations at original millisecond PTS. Existing confirmed
labels are retained on reimport. MP4s remain outside the public repository.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

LANDMARKS = ('nose leftEyeInner leftEye leftEyeOuter rightEyeInner rightEye '
    'rightEyeOuter leftEar rightEar leftMouth rightMouth leftShoulder '
    'rightShoulder leftElbow rightElbow leftWrist rightWrist leftPinky '
    'rightPinky leftIndex rightIndex leftThumb rightThumb leftHip rightHip '
    'leftKnee rightKnee leftAnkle rightAnkle leftHeel rightHeel '
    'leftFootIndex rightFootIndex').split()


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def coordinate_digest(path):
    # Git may check out JSON with CRLF on Windows. Hash UTF-8/LF content so
    # manifest verification is stable across Windows and Linux checkouts.
    return hashlib.sha256(path.read_text(encoding='utf-8-sig').encode('utf-8')).hexdigest()


def scenario(name):
    if '_squat_' in name:
        key = name.split('_squat_', 1)[1].removesuffix('_gymrats')
        return 'squat', {'normal': 'normal', 'shallow': 'shallowSquat',
            'not_standing': 'standUpFully', 'chair': 'chair'}[key]
    key = name.split('_', 1)[1].removesuffix('_gymrats')
    return 'pushUp', {'normal': 'normal', 'knees': 'kneesDown',
        'bent_arms': 'incompleteExtension', 'belly': 'bellyDown'}[key]


def write_case(path, metadata, frames):
    prefix = json.dumps(metadata, ensure_ascii=False, indent=2)
    assert prefix.endswith('\n}')
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='\n') as stream:
        stream.write(prefix[:-2] + ',\n  "frames": [\n')
        stream.write(',\n'.join('    ' + json.dumps(frame, separators=(',', ':'),
            allow_nan=False) for frame in frames))
        stream.write('\n  ]\n}\n')


def verify(folder):
    manifest = load(folder / 'manifest.json')
    assert manifest['caseCount'] == len(manifest['cases']) == 16
    ids = set()
    for row in manifest['cases']:
        path = folder / row['file']
        assert path.resolve().is_relative_to(folder.resolve())
        assert coordinate_digest(path) == row['jsonSha256'], path
        data = load(path)
        assert data['id'] not in ids
        ids.add(data['id'])
        assert data['participant'] in ('hyunwoo', 'sangwoo')
        assert len(data['frames']) == data['source']['frameCount'] > 0
        times = [f['t'] for f in data['frames']]
        assert times[0] == 0 and all(b > a for a, b in zip(times, times[1:]))
        for frame in data['frames']:
            p = frame['p']
            assert p is None or len(p) == 132
            if p is not None:
                assert all(v is None or math.isfinite(v) for v in p)
        assert len(data['source']['sha256']) == 64
    assert not list(folder.rglob('*.mp4'))
    print(f'Verified16 coordinate cases, {sum(r["frameCount"] for r in manifest["cases"])}frames; no MP4s')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--video-root', type=Path)
    parser.add_argument('--native', type=Path, action='append', default=[])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--refresh-manifest', action='store_true',
        help='Refresh coordinate JSON hashes after human label edits; no videos needed')
    args = parser.parse_args()
    if args.refresh_manifest:
        manifest = load(args.output / 'manifest.json')
        for row in manifest['cases']:
            path = args.output / row['file']
            assert path.resolve().is_relative_to(args.output.resolve())
            data = load(path)
            assert data['source']['sha256'] == row['sourceVideoSha256']
            assert len(data['frames']) == row['frameCount']
            row['jsonSha256'] = coordinate_digest(path)
            row['labelStatus'] = data['label']['status']
        (args.output / 'manifest.json').write_text(json.dumps(manifest,
            ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        verify(args.output)
        return
    if args.verify_only:
        verify(args.output)
        return
    if args.video_root is None or not args.native:
        parser.error('--video-root and --native are required for import')
    import cv2
    videos = {}
    for folder, participant in [('2_hyunwoo_1407-1409', 'hyunwoo'),
                                 ('sangwoo', 'sangwoo')]:
        paths = sorted((args.video_root / folder).glob('*.mp4'))
        assert len(paths) == 8, folder
        for path in paths:
            assert path.stem not in videos
            videos[path.stem] = (path, participant)
    observations = {}
    captures = []
    for path in args.native:
        captures.append({'sha256': digest(path), 'format': 'native ML Kit keypoints'})
        for raw in load(path):
            if raw['clip'] in videos:
                assert raw['clip'] not in observations, raw['clip']
                observations[raw['clip']] = raw
    assert observations.keys() == videos.keys(), sorted(videos.keys() - observations.keys())
    rows = []
    for sid, (video, participant) in sorted(videos.items()):
        raw = observations[sid]
        cap = cv2.VideoCapture(str(video))
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS)
        cap.release()
        assert frame_count == len(raw['frames']) > 0
        source_hash = digest(video)
        exercise, intended = scenario(sid)
        target = args.output / participant / (sid + '.json')
        preserved = load(target) if target.exists() else None
        if preserved:
            assert preserved['source']['sha256'] == source_hash
        data = {
            'format': 'gymrats-iter4-ai-eval', 'version': 1,
            'id': sid, 'participant': participant, 'exercise': exercise,
            'scenario': intended,
            'source': {'fileName': video.name, 'sha256': source_hash,
                'bytes': video.stat().st_size, 'width': raw['width'],
                'height': raw['height'], 'frameCount': frame_count, 'fps': fps},
            'capture': {'detector': 'ML Kit Accurate', 'mode': 'stream',
                'plugin': '0.16.1', 'input': 'full upright frame JPEG95',
                'timestampPrecisionUs': 1000, 'imuRecorded': False,
                'note': 'Offline video PTS, not live processing/sensor timing'},
            'label': preserved['label'] if preserved else {
                'status': 'pending', 'actualReps': None, 'perRep': None,
                'confirmedBy': None, 'note': 'Recorder/PM must confirm from actual motion; filename is intent only'},
            'chairPolicy': preserved.get('chairPolicy') if preserved else
                ('range_only' if intended == 'chair' else None),
            'evaluationWindowUs': preserved.get('evaluationWindowUs') if preserved else None,
            'landmarks': LANDMARKS,
        }
        frames = []
        for frame in raw['frames']:
            points = frame['keypoints']
            flat = [v for name in LANDMARKS for v in points.get(name, [None] * 4)]
            frames.append({'t': frame['ms'] * 1000,
                'p': flat if points else None})
        write_case(target, data, frames)
        rows.append({'id': sid, 'participant': participant, 'exercise': exercise,
            'scenario': intended, 'file': target.relative_to(args.output).as_posix(),
            'jsonSha256': coordinate_digest(target), 'sourceVideoSha256': source_hash,
            'frameCount': frame_count, 'labelStatus': data['label']['status']})
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {'format': 'gymrats-iter4-dataset', 'version': 1,
        'recordedDate': '2026-11-18', 'caseCount': 16,
        'participants': ['hyunwoo', 'sangwoo'],
        'containsVideo': False, 'groundTruthPolicy': 'Human per-rep confirmation required; predictions never supply labels',
        'nativeCaptureProvenance': captures, 'cases': rows}
    (args.output / 'manifest.json').write_text(json.dumps(manifest,
        ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for participant in manifest['participants']:
        sheet = args.output / participant / 'record-sheet.md'
        if sheet.exists():
            continue
        text = [f'# Iteration4 record sheet: {participant} (2026-11-18)', '',
            'Status: pending recorder/PM confirmation. No repetition count is assumed.',
            'Fill each actual repetition with valid or the expected rejection reason.',
            'Labels must follow observed movement, never the app prediction.',
            'Transfer confirmed labels to each JSON label object and set status=confirmed.',
            'Chair policy: range_only (depth and full standing; user confirmed 2026-11-18).', '']
        for row in rows:
            if row['participant'] != participant:
                continue
            text += [f'## {row["id"]}', '',
                f'Exercise: {row["exercise"]}; filming intention: {row["scenario"]}.',
                'Actual repetition count: TODO', 'Confirmed by / date: TODO',
                'Exercise time window (optional, excludes approach/recovery): TODO',
                'Chair policy, if applicable: TODO', '',
                '| Actual rep | Expected label | Visual evidence / notes |',
                '|---|---|---|', '| TODO | TODO | Add one row per observed repetition |', '']
        sheet.write_text('\n'.join(text).rstrip() + '\n', encoding='utf-8')
    verify(args.output)


if __name__ == '__main__':
    main()

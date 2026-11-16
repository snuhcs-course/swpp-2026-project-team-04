"""Group-separated MLP experiment on native, upright 2-D joint coordinates.

The 'cuts' task sees the supplied start/end only. The 'stream' task sees a
verdict time from the running Dart judge and its preceding frames only.
The two models use identical feature extraction, but are trained separately.
"""
import argparse
import csv
import json
import warnings
from pathlib import Path

import numpy as np
from sklearn.metrics import f1_score
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from score_pushup_nine import LABELS, evaluate, match, read_sources
from score_pushup_span import binary_counts, from_stream_score

JOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]
EDGES = [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12),
         (1, 3), (2, 4), (3, 5), (4, 6), (1, 7), (2, 8),
         (7, 9), (8, 10), (9, 11), (10, 12), (1, 5), (2, 6)]


def coordinates(row):
    frames = row['frames']
    points = np.full((len(frames), len(JOINTS), 2), np.nan)
    for i, frame in enumerate(frames):
        joints = frame[2]
        if joints is None:
            continue
        for j, k in enumerate(JOINTS):
            point = joints[k]
            if point and point[2] >= .55 and np.isfinite(point[:2]).all():
                points[i, j] = point[:2]
    times = np.array([f[1] for f in frames])
    if row.get('time_unit') == 'us':
        times = times // 1000
    return np.array([f[0] for f in frames]), times, points


def vector(t, pts):
    if len(t) == 0:
        return None
    # Estimate a fixed reference for this window. A moving origin would erase
    # chest/hip travel. One pixel scale for both axes preserves image aspect.
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        centre = np.nanmedian(pts[:, 1:3], axis=(0, 1))
        centre = np.where(np.isfinite(centre), centre, np.nanmedian(pts, axis=(0, 1)))
        shoulder = pts[:, 2] - pts[:, 1]
        torso = (pts[:, 7] + pts[:, 8] - pts[:, 1] - pts[:, 2]) / 2
        scale = np.nanpercentile(np.stack([np.linalg.norm(shoulder, axis=1),
                                           np.linalg.norm(torso, axis=1)]), 75)
        if not np.isfinite(scale) or scale < 2:
            lengths = [np.linalg.norm(pts[:, a] - pts[:, b], axis=1) for a, b in EDGES]
            scale = np.nanpercentile(lengths, 75)
        norm = (pts - centre) / (scale if np.isfinite(scale) and scale >= 2 else np.nan)
        if np.nanmedian(shoulder[:, 0]) < 0:
            norm[:, :, 0] *= -1
        span = np.stack([norm[:, b] - norm[:, a] for a, b in EDGES], axis=1)
        xy = np.concatenate([norm, span], axis=1)
        # Median pooled bins preserve missing detections. No clip timestamps
        # from outside the actual input interval are used to fill occlusions.
        bins = np.minimum(5, ((t - t[0]) * 6 // max(1, t[-1] - t[0] + 1)))
        values = []
        for i in range(6):
            v = xy[bins == i]
            values.append(np.nanmedian(v, axis=0) if len(v) else
                          np.full(xy.shape[1:], np.nan))
        values = np.array(values)
        travel = np.nanpercentile(xy, 90, axis=0) - np.nanpercentile(xy, 10, axis=0)
        visibility = np.isfinite(xy[:, :, 0]).mean(axis=0)
        flat = np.r_[values.ravel(), travel.ravel(), visibility, (t[-1] - t[0]) / 1000]
        return np.nan_to_num(np.clip(flat, -5, 5), nan=-7.).astype(np.float32)


def collect(replay, units, events, mode):
    rows, features = [], []
    with replay.open(encoding='utf-8') as fp:
        seen = set()
        for line in fp:
            source = json.loads(line)
            key = source['source_id']
            if key in seen:
                raise ValueError(key)
            seen.add(key)
            idx, ts, points = coordinates(source)
            rec = units[key]
            ordered = sorted((u for u in rec['units'] if not u.get('confirmed_duplicate_of')),
                             key=lambda u: (u['end'], u['start'], u['unit_id']))
            if mode == 'cuts':
                segments = [(u['start'], u['end'], u['end'] - 1, u['label'],
                             u['unit_id']) for u in ordered if u['label']]
            else:
                frames = events[key]['events']['app_default']
                paired, _ = match(ordered, frames, rec['fps'])
                by_event = {j: ordered[i] for i, j in paired.items()}
                segments = []
                prev_ms = -1
                for j, (frame, _) in enumerate(frames):
                    end = idx.searchsorted(frame)
                    if end == len(idx) or idx[end] != frame:
                        raise ValueError(f'{key} lacks frame {frame}')
                    start = ts.searchsorted(max(prev_ms + 1, ts[end] - 1600))
                    unit = by_event.get(j, {})
                    segments.append((idx[start], frame + 1, frame,
                                     unit.get('label'), unit.get('unit_id', '')))
                    prev_ms = ts[end]
            for left, right, frame, label, uid in segments:
                lo, hi = idx.searchsorted([left, right])
                v = vector(ts[lo:hi], points[lo:hi])
                # Even an empty window gets a prediction and remains in scores.
                if v is None:
                    v = vector(np.array([0]), np.full((1, len(JOINTS), 2), np.nan))
                features.append(v)
                rows.append((key, rec['split'], rec['group_id'], int(frame), label, uid))
        if seen != set(units):
            raise ValueError('Corpus differs from reference')
    return np.stack(features), rows


def train(x, y, groups, denominators):
    indices = np.arange(len(y))
    # Preserve group isolation for feature scaling, weights, and all choices.
    folds = list(StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=164)
                 .split(indices, y, groups))
    labels = np.unique(y)
    rankings = []
    for dims in [(32, 16), (64, 32)]:
        for balance in [0., .5]:
            forecasts = {epoch: np.empty_like(y) for epoch in [5, 12, 24]}
            for a, b in folds:
                scaler = StandardScaler().fit(x[a])
                xa, xb = scaler.transform(x[a]).clip(-6, 6), scaler.transform(x[b]).clip(-6, 6)
                net = make_network(dims)
                weights = sample_weights(y[a], balance)
                for epoch in range(1, 25):
                    net.partial_fit(xa, y[a], classes=labels, sample_weight=weights)
                    if epoch in forecasts:
                        forecasts[epoch][b] = net.predict(xb)
            for epoch, pred in forecasts.items():
                # Missed events count against both denominators in stream mode.
                correct_normal = np.sum((y == 'normal') & (pred == 'normal'))
                correct_invalid = np.sum((y != 'normal') & (pred != 'normal'))
                rankings.append(dict(layers=dims, balance=balance, epochs=epoch,
                                     binary_balanced=float((correct_normal / denominators[0] +
                                                            correct_invalid / denominators[1]) / 2),
                                     validation_macro=float(f1_score(
                                         y, pred, labels=labels, average='macro', zero_division=0)),
                                     validation_accuracy=float((y == pred).mean())))
    rankings.sort(key=lambda r: (-r['binary_balanced'], -r['validation_macro'], r['epochs']))
    best = rankings[0]
    scaler = StandardScaler().fit(x)
    net = make_network(best['layers'])
    xx = scaler.transform(x).clip(-6, 6)
    weights = sample_weights(y, best['balance'])
    for _ in range(best['epochs']):
        net.partial_fit(xx, y, classes=labels, sample_weight=weights)
    return net, scaler, rankings


def make_network(dims):
    return MLPClassifier(hidden_layer_sizes=tuple(dims), activation='relu',
                         solver='adam', alpha=.01, batch_size=64, random_state=316)


def sample_weights(y, exponent):
    counts = dict(zip(*np.unique(y, return_counts=True)))
    weights = np.array([float(counts[v]) ** -exponent for v in y])
    return weights / np.mean(weights)


def align_order(truth, guesses):
    # Phone fixtures contain ordered labels only (no per-rep source times).
    # Match GymRats eval_scorer's diagonal-first minimum edit alignment.
    n, m = len(truth), len(guesses)
    cost = np.zeros((n + 1, m + 1), dtype=int)
    cost[:, m], cost[n, :] = np.arange(n, -1, -1), np.arange(m, -1, -1)
    for i in reversed(range(n)):
        for j in reversed(range(m)):
            cost[i, j] = min(cost[i + 1, j + 1] + (truth[i] != guesses[j]),
                             cost[i + 1, j] + 1, cost[i, j + 1] + 1)
    i = j = 0
    while i < n or j < m:
        if i < n and j < m and cost[i, j] == cost[i+1, j+1] + (truth[i] != guesses[j]):
            yield i, guesses[j]
            i, j = i + 1, j + 1
        elif i < n and cost[i, j] == cost[i+1, j] + 1:
            yield i, 'no_event'
            i += 1
        else:
            yield None, guesses[j]
            j += 1


def on_phone(replay, records, net, scaler, baseline=None):
    gold = {k: v for k, v in read_sources(records).items() if v.get('labelled')}
    original = read_sources(baseline) if baseline is not None else gold
    actual_predictions = []
    tests = Path(__file__).resolve().parents[2] / 'gymrats_app' / 'test'
    moved = {}
    for folder in [tests / 'ai_eval/cases', tests / 'fixtures/pushup_cases']:
        for path in folder.rglob('*.json'):
            data = json.loads(path.read_text(encoding='utf-8-sig'))
            if data['id'] in gold:
                moved[data['id']] = {i for i, f in enumerate(data['frames']) if f.get('moved')}
    if set(moved) != set(gold):
        raise ValueError('Missing original phone motion flags')
    truths, previous, learned = [], [], []
    new_critical, extra = [], {'rules': 0, 'mlp': 0}
    with replay.open(encoding='utf-8') as fp:
        for line in fp:
            row = json.loads(line)
            key = row['source_id']
            if key not in gold:
                continue
            idx, ts, poses = coordinates(row)
            truth = ['normal' if v == 'valid' else v for v in gold[key]['labelled']]
            events = gold[key]['events']['app_default']
            guesses, previous_ms = [], -1
            for end_frame, rule in events:
                pos = idx.searchsorted(end_frame)
                start = ts.searchsorted(max(previous_ms + 1, ts[pos] - 1600))
                x = vector(ts[start:pos+1], poses[start:pos+1])[None, :]
                verdict = net.predict(scaler.transform(x).clip(-6, 6))[0]
                # Preserve the physical motion veto. A binary learner delegates
                # the explanatory label to the rule whenever both reject.
                if end_frame in moved[key] and verdict == 'normal':
                    verdict = 'phoneMoved'
                if verdict == 'invalid':
                    verdict = rule if rule != 'normal' else 'insufficientDepth'
                guesses.append(verdict)
                previous_ms = ts[pos]
            def aligned(pred, kind):
                selected = []
                for i, v in align_order(truth, pred):
                    if i is None:
                        extra[kind] += int(v == 'normal')
                    else:
                        selected.append(v)
                return selected
            base = aligned([e[1] for e in original[key]['events']['app_default']], 'rules')
            actual_predictions.append(dict(source_id=key, events=[[e[0], p] for e,p in zip(events,guesses)]))
            cand = aligned(guesses, 'mlp')
            new_critical.extend((key, i + 1, label) for i, label in enumerate(truth)
                                if label in ('kneesDown', 'bellyDown', 'incompleteExtension')
                                and base[i] != 'normal' and cand[i] == 'normal')
            truths.extend(truth)
            previous.extend(base)
            learned.extend(cand)
    return dict(recordings=len(gold), rules=binary_counts(truths, previous),
                mlp=binary_counts(truths, learned), new_critical_accepts=new_critical,
                extra_counted=extra, predictions=actual_predictions)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('replay', 'units', 'events', 'output'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--mode', choices=['cuts', 'stream'], required=True)
    parser.add_argument('--target', choices=['reasons', 'binary'], default='reasons')
    parser.add_argument('--phone', nargs=2, type=Path, metavar=('POSES', 'RULE_EVENTS'))
    a = parser.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    manifest, events = read_sources(a.units), read_sources(a.events)
    x, rows = collect(a.replay, manifest, events, a.mode)
    train_ids = [i for i, row in enumerate(rows) if row[1] == 'development' and row[4]]
    test_ids = [i for i, row in enumerate(rows) if row[1] == 'holdout' and row[4]]
    train_groups = {manifest[k]['group_id'] for k in manifest if manifest[k]['split'] == 'development'}
    test_groups = {manifest[k]['group_id'] for k in manifest if manifest[k]['split'] == 'holdout'}
    if train_groups & test_groups:
        raise ValueError('A source group crosses splits')
    def target(label):
        return 'invalid' if a.target == 'binary' and label != 'normal' else label
    reference = [u['label'] for s in manifest.values() if s['split'] == 'development'
                 for u in s['units'] if u['label'] and not u.get('confirmed_duplicate_of')]
    denominators = (reference.count('normal'), len(reference) - reference.count('normal'))
    with threadpool_limits(limits=1):
        net, scale, ranking = train(x[train_ids], np.array([target(rows[i][4]) for i in train_ids]),
                                    np.array([rows[i][2] for i in train_ids]), denominators)
        predicted = net.predict(scale.transform(x).clip(-6, 6))
    actual = np.array([target(rows[i][4]) for i in test_ids])
    held = predicted[test_ids]
    classes = ('normal', 'invalid') if a.target == 'binary' else LABELS
    represented = [k for k in classes if k in actual]
    report = dict(mode=a.mode, target=a.target, development_attempts=len(train_ids), test_attempts=len(test_ids),
                  development_groups=len(train_groups), test_groups=len(test_groups),
                  test_correct=int((held == actual).sum()), test_accuracy=float((actual == held).mean()),
                  test_macro_f1=float(f1_score(actual, held, labels=represented, average='macro', zero_division=0)),
                  class_scores={k: dict(support=int((actual == k).sum()),
                                        predicted=int((held == k).sum()),
                                        correct=int(((held == k) & (actual == k)).sum()))
                                for k in classes}, binary_on_given_windows=binary_counts(actual, held),
                  validation_ranking=ranking)
    if a.mode == 'stream':
        mapped = {k: {'events': {'mlp': []}} for k in manifest}
        for row, pred in zip(rows, predicted):
            # The common nine-way scorer requires a concrete enum; the binary
            # experiments consume only its aggregate invalid column.
            scoring_label = 'insufficientDepth' if pred == 'invalid' else pred
            mapped[row[0]]['events']['mlp'].append([row[3], scoring_label])
        scored = evaluate(manifest, mapped, 'mlp', {'holdout'})
        report['binary_end_to_end'] = from_stream_score(scored)
        if a.target == 'reasons':
            report['end_to_end'] = scored
        report['rules_on_same_events'] = from_stream_score(evaluate(manifest, events, 'app_default', {'holdout'}))
        if a.phone:
            with threadpool_limits(limits=1):
                report['phone_fixture_checks'] = on_phone(*a.phone, net, scale)
    prefix = a.mode + '-' + a.target
    dest = a.output / (prefix + '-results.json')
    dest.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    with (a.output / (prefix + '-predictions.csv')).open('w', newline='', encoding='utf-8') as fp:
        writer = csv.writer(fp)
        writer.writerow(['source_id', 'split', 'group', 'end_frame', 'reference', 'unit_id', 'mlp'])
        writer.writerows([*row, pred] for row, pred in zip(rows, predicted) if row[1] == 'holdout')
    print(dest, report['test_accuracy'], report['test_macro_f1'], flush=True)
    if a.mode == 'stream':
        print('binary end-to-end', report['binary_end_to_end']['balanced_accuracy'])


if __name__ == '__main__':
    main()

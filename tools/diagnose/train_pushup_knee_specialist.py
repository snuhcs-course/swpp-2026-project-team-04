"""Choose a causal knee-support veto using grouped development validation only."""
import argparse
import json
from pathlib import Path

import joblib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier
from threadpoolctl import threadpool_limits

from infer_pushup_mlp import ExportedBinaryMlp, stream_features
from pushup_span_mlp import align_order, collect, make_network
from score_pushup_nine import evaluate, read_sources
from score_pushup_span import from_stream_score


def make_model(config):
    if config['kind'] == 'logistic':
        return LogisticRegression(C=config['C'], max_iter=2000, class_weight='balanced')
    if config['kind'] == 'tree':
        return DecisionTreeClassifier(max_depth=config['depth'], min_samples_leaf=20,
                                      class_weight='balanced', random_state=317)
    return MLPClassifier(hidden_layer_sizes=tuple(config['layers']), alpha=.03,
                         batch_size=64, random_state=317, max_iter=config['epochs'])


def fit_model(x, y, config):
    scaler = StandardScaler().fit(x)
    model = make_model(config)
    model.fit(scaler.transform(x).clip(-6, 6), y)
    return scaler, model


def probabilities(fitted, x):
    scaler, model = fitted
    return model.predict_proba(scaler.transform(x).clip(-6, 6))[:, 1]


def choose_threshold(y, p, maximum_loss):
    # Thresholds at validation scores represent every attainable operating point.
    thresholds = np.unique(np.r_[0., p, 1.])
    normal = p[y == 0]
    knee = p[y == 1]
    valid = [(float(t), float(np.mean(normal > t)), float(np.mean(knee > t)))
             for t in thresholds if np.mean(normal > t) <= maximum_loss]
    return max(valid, key=lambda row: (row[2], -row[1], row[0]))


def corpus_scores(manifest, rows, baseline, veto):
    mapped = {key: {'events': {'candidate': []}} for key in manifest}
    for row, label, is_knee in zip(rows, baseline, veto):
        verdict = 'kneesDown' if is_knee else ('normal' if label == 'normal' else 'insufficientDepth')
        mapped[row[0]]['events']['candidate'].append([row[3], verdict])
    result = evaluate(manifest, mapped, 'candidate', {'holdout'})
    return from_stream_score(result), result


def phone_scores(root, base, fitted, threshold, normal_threshold=.5):
    gold = read_sources(root / 'span-wide-mlp/fixtures-proposals.jsonl')
    moved = {}
    tests = Path(__file__).resolve().parents[2] / 'gymrats_app/test'
    for folder in [tests / 'ai_eval/cases', tests / 'fixtures/pushup_cases']:
        for path in folder.rglob('*.json'):
            data = json.loads(path.read_text(encoding='utf-8-sig'))
            if data['id'] in gold:
                moved[data['id']] = {i for i, frame in enumerate(data['frames']) if frame.get('moved')}
    counts = {name: {} for name in ['baseline', 'specialist']}
    extras = {'baseline': 0, 'specialist': 0}
    raw_pure = {label: dict(truth_reps=0, recordings=0, baseline_normal_events=0,
                           specialist_normal_events=0, total_events=0)
                for label in ['normal', 'kneesDown']}
    records = []
    with (root / 'span-source-fixtures.jsonl').open() as stream:
        for line in stream:
            source = json.loads(line)
            key = source['source_id']
            record = gold[key]
            if not record.get('labelled'):
                continue
            events = record['events']['app_default']
            x = stream_features(source, events)
            if x is None:
                continue
            predicted, normal = base.predict(x)
            p = probabilities(fitted, x)
            candidate = np.where(normal > normal_threshold, 'normal', 'invalid')
            outputs = {'baseline': predicted.tolist(), 'specialist': candidate.tolist()}
            for i, ((frame, reason), score) in enumerate(zip(events, p)):
                for name in outputs:
                    if outputs[name][i] == 'invalid':
                        outputs[name][i] = reason if reason != 'normal' else 'insufficientDepth'
                    if frame in moved.get(key, set()) and outputs[name][i] == 'normal':
                        outputs[name][i] = 'phoneMoved'
                if score > threshold:
                    outputs['specialist'][i] = 'kneesDown'
            truth = ['normal' if value == 'valid' else value for value in record['labelled']]
            if len(set(truth)) == 1 and truth[0] in raw_pure:
                raw = raw_pure[truth[0]]
                raw['truth_reps'] += len(truth)
                raw['recordings'] += 1
                raw['total_events'] += len(events)
                for name in outputs:
                    raw[name + '_normal_events'] += outputs[name].count('normal')
            for name, guesses in outputs.items():
                for i, value in align_order(truth, guesses):
                    if i is None:
                        extras[name] += int(value == 'normal')
                        continue
                    label = truth[i]
                    counter = counts[name].setdefault(label, dict(total=0, normal=0, invalid=0, missed=0))
                    counter['total'] += 1
                    counter['normal'] += int(value == 'normal')
                    counter['invalid'] += int(value not in ['normal', 'no_event'])
                    counter['missed'] += int(value == 'no_event')
            records.append(dict(source_id=key, truth=truth, events=events,
                                knee_probability=p.tolist(), **outputs))
    return dict(counts=counts, extra_normal=extras, raw_pure_recordings=raw_pure, records=records)


def combined_candidate(x, rows):
    selected = np.array([i for i, row in enumerate(rows) if row[1] == 'development' and row[4]])
    truth = np.array([rows[i][4] for i in selected])
    groups = np.array([rows[i][2] for i in selected])
    normal_oof = np.zeros(len(selected))
    folds = list(StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=217).split(selected, truth, groups))
    for train, valid in folds:
        y = np.where(truth[train] == 'normal', 'normal', 'invalid')
        scaler = StandardScaler().fit(x[selected[train]])
        network = make_network([64, 32])
        for _ in range(12):
            network.partial_fit(scaler.transform(x[selected[train]]).clip(-6, 6), y,
                                classes=['invalid', 'normal'])
        normal_oof[valid] = network.predict_proba(scaler.transform(x[selected[valid]]).clip(-6, 6))[:, 1]
    baseline = normal_oof > .5
    normal = truth == 'normal'
    knee = truth == 'kneesDown'
    other = ~(normal | knee)
    base_normal = np.mean(baseline[normal])
    base_other = np.mean(~baseline[other])
    ranking = []
    configs = [dict(kind='logistic', C=c) for c in [.001, .01, .1]]
    configs += [dict(kind='tree', depth=d) for d in [3, 6]]
    configs += [dict(kind='mlp', layers=[32, 16], epochs=25)]
    for config in configs:
        knee_oof = np.zeros(len(selected))
        for train, valid in folds:
            train = train[np.isin(truth[train], ['normal', 'kneesDown'])]
            fitted = fit_model(x[selected[train]], (truth[train] == 'kneesDown').astype(int), config)
            knee_oof[valid] = probabilities(fitted, x[selected[valid]])
        for nt in [.1, .2, .3, .35, .4, .5]:
            for kt in [.25, .4, .5, .6, .7, .8, .9, .95, .98, .99, 1.]:
                accepted = (normal_oof > nt) & (knee_oof <= kt)
                nr = float(np.mean(accepted[normal]))
                kr = float(np.mean(~accepted[knee]))
                other_reject = float(np.mean(~accepted[other]))
                ranking.append(dict(config=config, normal_threshold=nt, knee_threshold=kt, normal_recall=nr,
                                    knee_rejection=kr, other_rejection=other_reject,
                                    eligible=bool(nr >= base_normal and other_reject >= base_other - .05),
                                    score=(nr + kr) / 2))
        print('Combined checked', config, flush=True)
    ranking.sort(key=lambda r: (not r['eligible'], -r['score']))
    return dict(baseline=dict(normal_recall=base_normal, knee_rejection=float(np.mean(~baseline[knee])),
                             other_rejection=base_other), ranking=ranking, selected=ranking[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--combined', action='store_true')
    args = parser.parse_args()
    root, out = args.root, args.output
    out.mkdir(parents=True, exist_ok=True)
    manifest = read_sources(root / 'native-all/units.jsonl')
    events = read_sources(root / 'span-wide-mlp/proposals.jsonl')
    if (out / 'web-features.npz').exists():
        x = np.load(out / 'web-features.npz')['features']
        rows = json.loads((out / 'web-rows.json').read_text())
    else:
        x, rows = collect(root / 'native-all/replay.jsonl', manifest, events, 'stream')
        np.savez_compressed(out / 'web-features.npz', features=x)
        (out / 'web-rows.json').write_text(json.dumps(rows))
    print('feature cache', x.shape, flush=True)
    if args.combined:
        report = combined_candidate(x, rows)
        choice = report['selected']
        train_ids = [i for i,r in enumerate(rows) if r[1] == 'development' and r[4] in ['normal', 'kneesDown']]
        train_y = np.array([int(rows[i][4] == 'kneesDown') for i in train_ids])
        fitted = fit_model(x[train_ids], train_y, choice['config'])
        joblib.dump(fitted, out / 'combined-specialist.joblib')
        base = ExportedBinaryMlp(root / 'span-wide-mlp/binary-model.npz')
        _, normal = base.predict(x)
        knee = probabilities(fitted, x)
        labels = np.where(normal > choice['normal_threshold'], 'normal', 'invalid')
        report['web'], full = corpus_scores(manifest, rows, labels, knee > choice['knee_threshold'])
        report['phone'] = phone_scores(root, base, fitted, choice['knee_threshold'], choice['normal_threshold'])
        (out / 'combined-results.json').write_text(json.dumps(report, indent=2))
        (out / 'combined-web-full.json').write_text(json.dumps(full, indent=2))
        print(json.dumps({k: v for k,v in report.items() if k not in ['phone', 'ranking']}, indent=2), flush=True)
        return
    selected = np.array([i for i, r in enumerate(rows)
                         if r[1] == 'development' and r[4] in ['normal', 'kneesDown']])
    target = np.array([int(rows[i][4] == 'kneesDown') for i in selected])
    groups = np.array([rows[i][2] for i in selected])
    folds = list(StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=217).split(selected, target, groups))
    configs = ([dict(kind='logistic', C=c) for c in [.001, .01, .1, 1.]] +
               [dict(kind='tree', depth=d) for d in [2, 3, 4, 6, 8]] +
               [dict(kind='mlp', layers=[32, 16], epochs=e) for e in [25, 75, 150]])
    ranking = []
    for config in configs:
        oof = np.zeros(len(selected))
        for train, test in folds:
            fitted = fit_model(x[selected[train]], target[train], config)
            oof[test] = probabilities(fitted, x[selected[test]])
        choices = []
        for cap in [.0, .01, .02, .05, .1]:
            threshold, loss, recall = choose_threshold(target, oof, cap)
            choices.append(dict(cap=cap, threshold=threshold, normal_loss=loss, knee_recall=recall))
        item = dict(config=config, operating_points=choices)
        ranking.append(item)
        print(json.dumps(item), flush=True)
    # Predeclared deployment candidate permits at most 2% OOF false rejection.
    ranking.sort(key=lambda r: (-r['operating_points'][2]['knee_recall'],
                                r['operating_points'][2]['normal_loss']))
    winner = ranking[0]
    threshold = winner['operating_points'][2]['threshold']
    fitted = fit_model(x[selected], target, winner['config'])
    joblib.dump(fitted, out / 'knee-specialist.joblib')
    base = ExportedBinaryMlp(root / 'span-wide-mlp/binary-model.npz')
    baseline, normal_probability = base.predict(x)
    knee = probabilities(fitted, x)
    baseline_summary, baseline_full = corpus_scores(manifest, rows, baseline, np.zeros(len(x), dtype=bool))
    summary, full = corpus_scores(manifest, rows, baseline, knee > threshold)
    (out / 'web-baseline-full.json').write_text(json.dumps(baseline_full, indent=2))
    (out / 'web-specialist-full.json').write_text(json.dumps(full, indent=2))
    phone = phone_scores(root, base, fitted, threshold)
    (out / 'phone-results.json').write_text(json.dumps(phone, indent=2))
    report = dict(selection='5-fold development group CV; 2% normal rejection cap; test was used in prior work',
                  selected=winner, ranking=ranking, threshold=threshold,
                  train_normal=int(sum(target == 0)), train_knee=int(sum(target == 1)),
                  baseline=baseline_summary, specialist=summary, phone_counts=phone['counts'],
                  phone_extra_normal=phone['extra_normal'])
    (out / 'results.json').write_text(json.dumps(report, indent=2))
    np.savez_compressed(out / 'predictions.npz', knee=knee, normal=normal_probability)
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    with threadpool_limits(limits=1):
        main()

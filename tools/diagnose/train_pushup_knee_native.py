"""Native-assisted knee support specialist with device-group validation.

Only pure-labelled native recordings supply training posture labels. Every native
validation prediction excludes its entire device group. Web validation excludes
its source group. Historical holdout is used solely after operating-point choice.
"""
import argparse
import hashlib
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
from score_pushup_nine import read_sources
from train_pushup_knee_specialist import corpus_scores


def fit(x, y, native, config):
    scaler = StandardScaler().fit(x)
    weights = np.where(native, config['native_weight'], 1.)
    scaled = scaler.transform(x).clip(-6, 6)
    kind = config.get('kind', 'logistic')
    if kind == 'mlp':
        model = MLPClassifier(hidden_layer_sizes=(32, 16), alpha=.03,
                              batch_size=64, random_state=381)
        balanced = weights / np.bincount(y)[y]
        balanced /= balanced.mean()
        for _ in range(24):
            model.partial_fit(scaled, y, classes=[0, 1], sample_weight=balanced)
    else:
        if kind == 'tree':
            model = DecisionTreeClassifier(max_depth=config['depth'],
                                           min_samples_leaf=15,
                                           class_weight='balanced', random_state=381)
        else:
            model = LogisticRegression(C=config['C'], max_iter=2000,
                                       class_weight='balanced')
        model.fit(scaled, y, sample_weight=weights)
    return scaler, model


def predict(fitted, x):
    scaler, model = fitted
    return model.predict_proba(scaler.transform(x).clip(-6, 6))[:, 1]


def native_data(root, out):
    file = out / 'native-features.npz'
    meta = out / 'native-rows.json'
    if file.exists():
        return np.load(file)['features'], json.loads(meta.read_text())
    records = read_sources(root / 'span-wide-mlp/fixtures-proposals.jsonl')
    rows, features = [], []
    with (root / 'span-source-fixtures.jsonl').open() as stream:
        for line in stream:
            source = json.loads(line)
            key = source['source_id']
            truth = records[key].get('labelled')
            if not truth or len(set(truth)) != 1 or truth[0] not in ['valid', 'kneesDown']:
                continue
            group = key.split('_')[1] if '_' in key else key
            if group == 'knees':
                group = 'unknown-20261027'
            events = records[key]['events']['app_default']
            x = stream_features(source, events)
            if x is None:
                continue
            for row, event in zip(x, events):
                rows.append(dict(source_id=key, group=group, frame=event[0],
                                 label=truth[0], truth_count=len(truth)))
                features.append(row)
    values = np.stack(features)
    np.savez_compressed(file, features=values)
    meta.write_text(json.dumps(rows, indent=2))
    return values, rows


def counts(labels, original, probability, threshold):
    reject = probability > threshold
    return dict(normal_total=int(sum(labels == 0)), knee_total=int(sum(labels == 1)),
                original_normal=int(sum((labels == 0) & original)),
                original_knee_normal=int(sum((labels == 1) & original)),
                final_normal=int(sum((labels == 0) & original & ~reject)),
                final_knee_normal=int(sum((labels == 1) & original & ~reject)),
                extra_normal_loss=int(sum((labels == 0) & original & reject)),
                recovered_knee=int(sum((labels == 1) & original & reject)))


def operating_points(web_y, web_base, web_p, native_y, native_base, native_p):
    candidates = np.unique(np.r_[web_p, native_p, 1.])
    results = []
    for cap in [0., .01, .02, .05, .1]:
        allowed = []
        for threshold in candidates:
            w = counts(web_y, web_base, web_p, threshold)
            n = counts(native_y, native_base, native_p, threshold)
            if w['extra_normal_loss'] / max(1, w['original_normal']) > cap:
                continue
            if n['extra_normal_loss'] / max(1, n['original_normal']) > cap:
                continue
            gain = .5 * (w['recovered_knee'] / max(1, w['original_knee_normal']) +
                         n['recovered_knee'] / max(1, n['original_knee_normal']))
            allowed.append((gain, threshold, w, n))
        best = max(allowed, key=lambda v: (v[0], v[1]))
        results.append(dict(cap=cap, threshold=float(best[1]), score=float(best[0]),
                            web=best[2], native=best[3]))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--extended', action='store_true')
    args = parser.parse_args()
    root, out = args.root, args.output
    out.mkdir(parents=True, exist_ok=True)
    web = np.load(root / 'knee-focus/model/web-features.npz')['features']
    rows = json.loads((root / 'knee-focus/model/web-rows.json').read_text())
    selected = np.array([i for i, row in enumerate(rows)
                         if row[1] == 'development' and row[4] in ['normal', 'kneesDown']])
    wx = web[selected]
    wy = np.array([int(rows[i][4] == 'kneesDown') for i in selected])
    wg = np.array([rows[i][2] for i in selected])
    nx, nr = native_data(root, out)
    ny = np.array([int(row['label'] == 'kneesDown') for row in nr])
    ng = np.array([row['group'] for row in nr])
    base = ExportedBinaryMlp(root / 'span-wide-mlp/binary-model.npz')
    baseline, _ = base.predict(web)
    nb, _ = base.predict(nx)
    wb = baseline[selected] == 'normal'
    nb = nb == 'normal'
    print('native', nx.shape, sorted(set(ng)), 'baseline', counts(ny, nb, np.zeros(len(ny)), 1), flush=True)
    folds = list(StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=381).split(wx, wy, wg))
    configs = [dict(C=c, native_weight=weight) for c in [.0001, .001, .01, .1]
               for weight in [1., 5., 20.]]
    if args.extended:
        configs = [dict(kind='mlp', native_weight=weight) for weight in [1., 5., 20.]]
        configs += [dict(kind='tree', depth=depth, native_weight=weight)
                    for depth in [3, 5] for weight in [1., 5.]]
    reports = []
    for config in configs:
        wp, npred = np.zeros(len(wx)), np.zeros(len(nx))
        for group in sorted(set(ng)):
            valid = ng == group
            xx = np.concatenate([wx, nx[~valid]])
            yy = np.r_[wy, ny[~valid]]
            domains = np.r_[np.zeros(len(wx), bool), np.ones(sum(~valid), bool)]
            model = fit(xx, yy, domains, config)
            npred[valid] = predict(model, nx[valid])
        for train, valid in folds:
            xx = np.concatenate([wx[train], nx])
            yy = np.r_[wy[train], ny]
            domains = np.r_[np.zeros(len(train), bool), np.ones(len(nx), bool)]
            model = fit(xx, yy, domains, config)
            wp[valid] = predict(model, wx[valid])
        choices = operating_points(wy, wb, wp, ny, nb, npred)
        reports.append(dict(config=config, operating_points=choices))
        tag = hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()[:12]
        np.savez_compressed(out / f'oof-{tag}.npz',
                            web=wp, native=npred)
        print(json.dumps(reports[-1]), flush=True)
    reports.sort(key=lambda item: -item['operating_points'][2]['score'])
    winner = reports[0]
    threshold = winner['operating_points'][2]['threshold']
    final = fit(np.concatenate([wx, nx]), np.r_[wy, ny],
                np.r_[np.zeros(len(wx), bool), np.ones(len(nx), bool)], winner['config'])
    destination = out / 'native-knee-model.joblib'
    joblib.dump(final, destination)
    scaler, model = final
    export = out / 'native-knee-model.npz'
    parameters = dict(mean=scaler.mean_, scale=scaler.scale_, threshold=threshold,
                      kind=np.array(winner['config'].get('kind', 'logistic')))
    if hasattr(model, 'coef_'):
        parameters.update(weights=model.coef_[0], bias=model.intercept_[0])
    elif hasattr(model, 'coefs_'):
        parameters['layers'] = len(model.coefs_)
        for i, (weights, bias) in enumerate(zip(model.coefs_, model.intercepts_)):
            parameters[f'weights_{i}'] = weights
            parameters[f'bias_{i}'] = bias
    else:
        tree = model.tree_
        parameters.update(left=tree.children_left, right=tree.children_right,
                          feature=tree.feature, split=tree.threshold,
                          value=tree.value[:, 0, :])
    np.savez_compressed(export, **parameters)
    manifest = read_sources(root / 'native-all/units.jsonl')
    final_p = predict(final, web)
    summary, full = corpus_scores(manifest, rows, baseline, final_p > threshold)
    report = dict(selection='5-fold web-source OOF and leave-device-out native OOF; <=2% loss of original normal events in each domain',
                  caveat='Native validation is reused historical data. Base model used all web development data, so incremental web gains are descriptive. Native pure-sequence posture labels lack exact repetition times.',
                  native_groups=sorted(set(ng)), native_recordings=len(set(r['source_id'] for r in nr)),
                  selected=winner, rankings=reports, web_holdout=summary,
                  export_sha256=hashlib.sha256(export.read_bytes()).hexdigest())
    (out / 'results.json').write_text(json.dumps(report, indent=2))
    (out / 'web-holdout-full.json').write_text(json.dumps(full, indent=2))
    np.savez_compressed(out / 'web-predictions.npz', knee=final_p)
    print('selected', json.dumps(winner), 'holdout', summary, flush=True)


if __name__ == '__main__':
    with threadpool_limits(limits=1):
        main()

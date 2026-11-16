"""Replay a frozen knee veto together with the existing binary push-up MLP.

The output contains the original and final verdict at every causal proposal.
It does not add events or infer ground truth from the file name.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from scipy.special import expit
from threadpoolctl import threadpool_limits

from infer_pushup_mlp import ExportedBinaryMlp, stream_features
from score_pushup_nine import read_sources


class ExportedKneeModel:
    def __init__(self, path):
        with np.load(path, allow_pickle=False) as data:
            self.parameters = {key: data[key].copy() for key in data.files}
        self.threshold = float(self.parameters['threshold'])
        self.kind = str(self.parameters.get('kind', 'logistic'))

    def probability(self, features):
        data = self.parameters
        values = np.asarray(features, dtype=np.float32).copy()
        if values.ndim != 2 or values.shape[1] != len(data['mean']):
            raise ValueError('Unexpected knee feature shape')
        values -= data['mean']
        values /= data['scale']
        np.clip(values, -6, 6, out=values)
        if self.kind == 'logistic':
            return expit(values @ data['weights'] + data['bias'])
        if self.kind == 'mlp':
            for layer in range(int(data['layers'])):
                values = values @ data[f'weights_{layer}']
                values += data[f'bias_{layer}']
                if layer + 1 < int(data['layers']):
                    np.maximum(values, 0, out=values)
            return expit(values).ravel()
        if self.kind != 'tree':
            raise ValueError(f'Unknown knee model kind {self.kind}')
        result = np.zeros(len(values))
        for index, row in enumerate(values):
            node = 0
            while data['left'][node] != data['right'][node]:
                feature = data['feature'][node]
                node = (data['left'][node] if row[feature] <= data['split'][node]
                        else data['right'][node])
            counts = data['value'][node]
            result[index] = counts[1] / counts.sum()
        return result

    def reject(self, features):
        return self.probability(features) > self.threshold


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['base_model', 'knee_model', 'replay', 'proposals', 'output']:
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    base = ExportedBinaryMlp(args.base_model)
    knee = ExportedKneeModel(args.knee_model)
    proposals = read_sources(args.proposals)
    seen = set()
    with args.replay.open(encoding='utf-8') as source, args.output.open('x', encoding='utf-8') as output:
        for line in source:
            row = json.loads(line)
            key = row['source_id']
            if key in seen:
                raise ValueError(f'Duplicate source {key}')
            seen.add(key)
            events = proposals[key]['events']['app_default']
            features = stream_features(row, events)
            predictions = []
            if features is not None:
                original, normal_probability = base.predict(features)
                knee_probability = knee.probability(features)
                for event, label, normal_p, knee_p in zip(
                        events, original, normal_probability, knee_probability, strict=True):
                    predictions.append(dict(
                        frame=event[0], baseline=str(label),
                        label='kneesDown' if knee_p > knee.threshold else str(label),
                        normal_probability=float(normal_p), knee_probability=float(knee_p)))
            output.write(json.dumps(dict(source_id=key, predictions=predictions)) + '\n')
    if seen != set(proposals):
        raise ValueError('Replay and proposal inventories differ')


if __name__ == '__main__':
    with threadpool_limits(limits=1):
        main()

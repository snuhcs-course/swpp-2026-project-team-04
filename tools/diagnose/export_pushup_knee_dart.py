"""Embed the selected knee-veto MLP parameters losslessly in the Dart model."""
import argparse
import base64
import hashlib
from pathlib import Path

import numpy as np

START = '// BEGIN FROZEN PUSHUP KNEE ARRAYS'
END = '// END FROZEN PUSHUP KNEE ARRAYS'
THRESHOLD = 0.9204565286636353


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', type=Path)
    parser.add_argument('dart', type=Path)
    args = parser.parse_args()
    with np.load(args.model, allow_pickle=False) as model:
        if str(model['kind']) != 'mlp' or int(model['layers']) != 3:
            raise ValueError('Expected the three-layer knee MLP')
        if float(model['threshold']) != THRESHOLD:
            raise ValueError('The Dart decision threshold must match the selected model')
        expected = {'mean': (466,), 'scale': (466,),
                    'weights_0': (466, 32), 'weights_1': (32, 16), 'weights_2': (16, 1),
                    'bias_0': (32,), 'bias_1': (16,), 'bias_2': (1,)}
        for key, shape in expected.items():
            if model[key].shape != shape or not np.isfinite(model[key]).all():
                raise ValueError(f'Invalid array {key}')
        if np.any(model['scale'] <= 0):
            raise ValueError('Feature scales must be positive')
        arrays = [('mean', '<f8'), ('scale', '<f8')]
        arrays += [(key, '<f4') for key in (
            'weights_0', 'weights_1', 'weights_2', 'bias_0', 'bias_1', 'bias_2')]
        payload = b''.join(model[key].astype(dtype).tobytes() for key, dtype in arrays)
    encoded = base64.b64encode(payload).decode('ascii')
    lines = [START,
             '// Source native-knee-model.npz SHA-256 ' + hashlib.sha256(args.model.read_bytes()).hexdigest(),
             '// Float64 mean/scale then float32 W0/W1/W2/b0/b1/b2, little-endian.',
             '// Regenerate with tools/diagnose/export_pushup_knee_dart.py.',
             'const _pushupKneeArrays =']
    lines += ["    '" + encoded[i:i + 100] + "'" for i in range(0, len(encoded), 100)]
    lines[-1] += ';'
    lines.append(END)
    source = args.dart.read_text(encoding='utf-8')
    segment = '\n'.join(lines)
    if START in source:
        left = source.index(START)
        right = source.index(END) + len(END)
        source = source[:left] + segment + source[right:]
    else:
        source += '\n' + segment + '\n'
    args.dart.write_text(source, encoding='utf-8')
    print(len(payload), 'array bytes embedded')


if __name__ == '__main__':
    main()

"""Embed the frozen binary MLP arrays losslessly in the pure Dart metric file."""
import argparse
import base64
import hashlib
from pathlib import Path

import numpy as np

START = '// BEGIN FROZEN PUSHUP MLP ARRAYS'
END = '// END FROZEN PUSHUP MLP ARRAYS'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', type=Path)
    parser.add_argument('dart', type=Path)
    args = parser.parse_args()
    model = np.load(args.model, allow_pickle=False)
    if list(model['classes']) != ['invalid', 'normal']:
        raise ValueError('Unexpected class order')
    arrays = [('mean', '<f8'), ('scale', '<f8')]
    arrays += [(name, '<f4') for name in ('weights_0', 'weights_1', 'weights_2',
                                         'biases_0', 'biases_1', 'biases_2')]
    payload = b''.join(model[name].astype(dtype).tobytes() for name, dtype in arrays)
    encoded = base64.b64encode(payload).decode('ascii')
    lines = [START,
             '// Source binary-model.npz SHA-256 ' + hashlib.sha256(args.model.read_bytes()).hexdigest(),
             '// Float64 mean/scale then float32 W0/W1/W2/b0/b1/b2, little-endian.',
             '// Regenerate with tools/diagnose/export_pushup_mlp_dart.py.',
             'const _pushupMlpArrays =']
    lines += ["    '" + encoded[i:i+100] + "'" for i in range(0, len(encoded), 100)]
    lines[-1] += ';'
    lines += [END]
    text = args.dart.read_text(encoding='utf-8')
    segment = '\n'.join(lines)
    if START in text:
        left, right = text.index(START), text.index(END) + len(END)
        text = text[:left] + segment + text[right:]
    else:
        text += '\n' + segment + '\n'
    args.dart.write_text(text, encoding='utf-8')
    print(len(payload), 'array bytes embedded')


if __name__ == '__main__':
    main()

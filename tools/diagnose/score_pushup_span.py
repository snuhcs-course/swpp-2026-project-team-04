"""Compare binary push-up decisions with the same one-to-one time alignment."""
import argparse
import csv
import json
from pathlib import Path

from score_pushup_nine import LABELS, evaluate, read_sources


def binary_counts(truth, predictions):
    # A missing decision is a miss in either class. Record its gameplay effect
    # (no point awarded) separately from identifying the fault.
    rows = {label: dict(normal=0, invalid=0, missing=0) for label in ('normal', 'invalid')}
    for target, guess in zip(truth, predictions, strict=True):
        target = 'normal' if target == 'normal' else 'invalid'
        outcome = 'missing' if guess == 'no_event' else 'normal' if guess == 'normal' else 'invalid'
        rows[target][outcome] += 1
    return binary_table(rows)


def binary_table(rows):
    totals = {label: sum(counts.values()) for label, counts in rows.items()}
    normal = rows['normal']['normal'] / totals['normal'] if totals['normal'] else None
    invalid = rows['invalid']['invalid'] / totals['invalid'] if totals['invalid'] else None
    return dict(counts=rows, totals=totals, normal_recall=normal, invalid_recall=invalid,
                invalid_no_point=(1 - rows['invalid']['normal'] / totals['invalid']
                                  if totals['invalid'] else None),
                balanced_accuracy=(normal + invalid) / 2 if normal is not None and invalid is not None else None)


def from_stream_score(score):
    rows = {key: dict(normal=0, invalid=0, missing=0) for key in ('normal', 'invalid')}
    for actual in LABELS:
        row = rows['normal' if actual == 'normal' else 'invalid']
        conf = score['confusion'][actual]
        row['normal'] += conf['normal']
        row['invalid'] += sum(conf[label] for label in LABELS if label != 'normal')
        row['missing'] += conf['no_event']
    return {**binary_table(rows), 'extra_verdicts': score['extras'],
            'extra_normal': score['confusion']['unmatched_event']['normal']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('units', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('inputs', nargs='+', help='name=path.jsonl; one candidate per input')
    args = parser.parse_args()
    manifest = read_sources(args.units)
    reports = {}
    for spec in args.inputs:
        name, raw = spec.split('=', 1)
        doc = read_sources(Path(raw))
        if set(doc) != set(manifest):
            raise ValueError('Mismatched source set')
        candidates = list(next(iter(doc.values()))['events'])
        if len(candidates) != 1:
            raise ValueError('Expected single-candidate stream')
        reports[name] = {}
        for split in ('development', 'holdout'):
            path = args.output.with_name(f'{args.output.stem}-{name}-{split}.csv')
            with path.open('w', encoding='utf-8', newline='') as fp:
                writer = csv.writer(fp)
                writer.writerow(['source_id','split','unit_id','start','end','reference','event_frame','prediction','duplicate_of'])
                result = evaluate(manifest, doc, candidates[0], {split}, writer=writer)
            reports[name][split] = {'binary': from_stream_score(result), 'nine': result}
    args.output.write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

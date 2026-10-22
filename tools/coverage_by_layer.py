#!/usr/bin/env python3
# AI-generated with Claude (Opus 5.5), 2026-10-22, reviewed by Woohyun Song
"""Per-layer line coverage of the Flutter app, from one or more lcov files.

Usage (from the repository root, Python 3.8+ with no extra packages):

    python tools/coverage_by_layer.py gymrats_app/coverage/lcov.info
    python tools/coverage_by_layer.py gymrats_app/coverage/parts/*.info --html coverage-by-layer.html

Several lcov files (one per test file, if a single `flutter test --coverage`
run crashes) are merged: a line counts as hit when any run hit it.

Layers follow the MVVM split in the Testing Documentation:
    Model      lib/models/
    ViewModel  lib/viewmodels/
    Service    lib/services/
    View       lib/screens/ and lib/widgets/
    Other      everything else under lib/ (main.dart, config, shared, theme)
lib/demo/ (manual entry points) is excluded. Files that no test loads are not
in the lcov data and therefore not counted.
"""
import argparse
import glob
import html
import re
import sys
from collections import defaultdict

LAYERS = [
    ("Model", ("models/",)),
    ("ViewModel", ("viewmodels/",)),
    ("Service", ("services/",)),
    ("View", ("screens/", "widgets/")),
]
EXCLUDED = ("demo/",)


def lib_path(source):
    """'C:\\dev\\repo\\gymrats_app\\lib\\models\\x.dart' -> 'models/x.dart'."""
    path = source.replace("\\", "/")
    match = re.search(r"(?:^|/)lib/(.+)$", path)
    return match.group(1) if match else None


def read_lcov(paths):
    lines = defaultdict(dict)  # file -> {line number: hit}
    for path in paths:
        current = None
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                raw = raw.strip()
                if raw.startswith("SF:"):
                    current = lib_path(raw[3:])
                elif raw.startswith("DA:") and current:
                    number, hits = raw[3:].split(",")[:2]
                    seen = lines[current]
                    seen[int(number)] = seen.get(int(number), False) or int(hits) > 0
                elif raw == "end_of_record":
                    current = None
    return {f: v for f, v in lines.items() if not f.startswith(EXCLUDED)}


def layer_of(file):
    for name, prefixes in LAYERS:
        if file.startswith(prefixes):
            return name
    return "Other"


def summarize(lines):
    totals = defaultdict(lambda: [0, 0])  # layer -> [hit, found]
    for file, seen in lines.items():
        layer = totals[layer_of(file)]
        layer[0] += sum(seen.values())
        layer[1] += len(seen)
    rows = []
    for name in [n for n, _ in LAYERS] + ["Other"]:
        hit, found = totals.get(name, (0, 0))
        rows.append((name, hit, found))
    hit = sum(r[1] for r in rows)
    found = sum(r[2] for r in rows)
    rows.append(("Total", hit, found))
    return rows


def pct(hit, found):
    return f"{100 * hit / found:.1f}%" if found else "–"


def write_html(path, rows, lines, sources):
    files = sorted(lines.items(), key=lambda kv: (layer_of(kv[0]), kv[0]))
    body = "".join(
        f"<tr><td>{html.escape(n)}</td><td>{h} / {f}</td><td><b>{pct(h, f)}</b></td></tr>"
        for n, h, f in rows
    )
    detail = "".join(
        f"<tr><td>{layer_of(name)}</td><td>lib/{html.escape(name)}</td>"
        f"<td>{sum(seen.values())} / {len(seen)}</td><td>{pct(sum(seen.values()), len(seen))}</td></tr>"
        for name, seen in files
    )
    with open(path, "w", encoding="utf-8") as out:
        out.write(
            "<!doctype html><meta charset='utf-8'><title>Coverage by layer</title>"
            "<style>body{font:14px system-ui,sans-serif;margin:24px}table{border-collapse:collapse;margin-bottom:24px}"
            "td,th{border:1px solid #ccc;padding:4px 10px;text-align:left}th{background:#f3f3f3}</style>"
            f"<h2>GymRats app: line coverage by layer</h2><p>Input: {html.escape(', '.join(sources))}</p>"
            f"<table><tr><th>Layer</th><th>Lines hit / found</th><th>Coverage</th></tr>{body}</table>"
            f"<table><tr><th>Layer</th><th>File</th><th>Lines</th><th>Coverage</th></tr>{detail}</table>"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("lcov", nargs="+", help="lcov.info file(s); globs are expanded")
    parser.add_argument("--html", help="also write an HTML report to this path")
    args = parser.parse_args()
    paths = sorted({p for pattern in args.lcov for p in (glob.glob(pattern) or [pattern])})
    lines = read_lcov(paths)
    if not lines:
        sys.exit("no lib/ files found in the lcov data")
    rows = summarize(lines)
    print(f"{len(paths)} lcov file(s), {len(lines)} source files under lib/ (lib/demo/ excluded)\n")
    print("| Layer | Lines hit / found | Coverage |")
    print("|---|---|---|")
    for name, hit, found in rows:
        print(f"| {name} | {hit} / {found} | {pct(hit, found)} |")
    if args.html:
        write_html(args.html, rows, lines, paths)
        print(f"\nHTML report: {args.html}")


if __name__ == "__main__":
    main()

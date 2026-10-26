#!/usr/bin/env python3
"""Build the PR comment for the "Tests and coverage" workflow (.github/workflows/tests.yml).

Usage (in CI, after actions/download-artifact into RESULTS_DIR):
    python3 tools/ci_test_report.py RESULTS_DIR > comment.md

Reads app-results/{analyze-output,test-output}.txt, app-results/coverage-by-layer.md and
server-results/server-output.txt, and prints a Markdown comment with the per-layer coverage
against the Testing Documentation targets, the test counts, and the commit it ran on.
Environment: APP_RESULT, SERVER_RESULT (job results), HEAD_SHA, RUN_URL.
"""
import datetime
import os
import re
import sys
from pathlib import Path

MARKER = "<!-- gymrats-ci-tests -->"
TARGETS = {"Model": 90.0, "ViewModel": 90.0, "Service": 85.0, "View": 75.0}
SERVER_TARGET = 90.0


def read(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def flutter_counts(text):
    """Last progress line of `flutter test`, e.g. '01:02 +658 ~1 -2: Some tests failed.'"""
    found = re.findall(r"\d+:\d+ \+(\d+)(?: ~(\d+))?(?: -(\d+))?: (.*)", text)
    if not found:
        return None
    passed, skipped, failed, tail = found[-1]
    return int(passed), int(skipped or 0), int(failed or 0), tail.strip()


def failing_tests(text, limit=10):
    names = []
    for m in re.finditer(r"\d+:\d+ \+\d+(?: ~\d+)? -\d+: (.+?) \[E\]", text):
        name = m.group(1).strip()
        if name not in names:
            names.append(name)
    return names[:limit]


def layer_rows(md):
    rows = []
    for line in md.splitlines():
        m = re.match(r"\|\s*([A-Za-z]+)\s*\|\s*(\d+)\s*/\s*(\d+)\s*\|\s*([\d.]+)%", line)
        if m:
            rows.append((m.group(1), int(m.group(2)), int(m.group(3)), float(m.group(4))))
    return rows


def server_numbers(text):
    total = re.search(r"^TOTAL\s+\d+\s+\d+\s+(?:\d+\s+\d+\s+)?(\d+)%", text, flags=re.M)
    summary = re.findall(r"=+ (.*(?:passed|failed|error).*) in [\d.]+s", text)
    return (float(total.group(1)) if total else None), (summary[-1] if summary else None)


def mark(value, target):
    if value is None:
        return "–"
    return "met" if value >= target else "**below**"


def main(results):
    app = Path(results) / "app-results"
    srv = Path(results) / "server-results"
    sha = os.environ.get("HEAD_SHA", "")[:7]
    run_url = os.environ.get("RUN_URL", "")
    today = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).strftime("%Y-%m-%d %H:%M KST")

    analyze = read(app / "analyze-output.txt")
    tests = read(app / "test-output.txt")
    layers = layer_rows(read(app / "coverage-by-layer.md"))
    server_cov, server_summary = server_numbers(read(srv / "server-output.txt"))
    counts = flutter_counts(tests)
    issues = re.search(r"(\d+) issues? found", analyze)

    out = [MARKER, "## Tests and coverage (GitHub Actions)", "",
           f"Commit `{sha}` · {today} · [run log]({run_url}) · app job: **{os.environ.get('APP_RESULT', '?')}** · "
           f"server job: **{os.environ.get('SERVER_RESULT', '?')}**", ""]

    out += ["### Flutter app", ""]
    out.append("- `flutter analyze`: " + ("no issues" if "No issues found" in analyze else
                                         (f"{issues.group(1)} issue(s) — see the run log" if issues else "see the run log")))
    if counts:
        passed, skipped, failed, tail = counts
        out.append(f"- `flutter test --coverage`: {passed} passed, {skipped} skipped, {failed} failed ({tail})")
        for name in failing_tests(tests):
            out.append(f"  - failed: {name}")
    else:
        out.append("- `flutter test --coverage`: no result (the run stopped early; see the run log)")
    out.append("")
    if layers:
        out += ["| Layer | Lines hit / found | Coverage | Target | Status |", "|---|---|---|---|---|"]
        for name, hit, found, pct in layers:
            target = TARGETS.get(name)
            out.append(f"| {name} | {hit} / {found} | {pct:.1f}% | {f'{target:.0f}%' if target else '–'} | "
                       f"{mark(pct, target) if target else '–'} |")
    else:
        out.append("No coverage data (see the run log).")

    out += ["", "### Django API", ""]
    out.append(f"- `pytest --cov=accounts --cov=matches --cov=gymrats`: {server_summary or 'no result (see the run log)'}")
    out.append(f"- Coverage: {f'{server_cov:.0f}%' if server_cov is not None else '–'} "
               f"(target {SERVER_TARGET:.0f}%: {mark(server_cov, SERVER_TARGET)})")

    out += ["", "<details><summary>Reproduce</summary>", "", "```",
            "cd gymrats_app && flutter pub get && flutter analyze && flutter test --coverage",
            "python3 tools/coverage_by_layer.py gymrats_app/coverage/lcov.info",
            "cd server && python -m pip install -r requirements-dev.txt && python -m pytest --cov=accounts --cov=matches --cov=gymrats",
            "```", "", "Flutter 3.47.5 (Dart 3.13.4), Python 3.12, ubuntu-latest. lcov.info and the HTML report are in the run's artifacts.",
            "</details>", ""]
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "results")

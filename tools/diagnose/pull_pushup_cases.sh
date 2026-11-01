#!/usr/bin/env bash
# Copies the push-up recordings made with lib/demo/rep_judge_demo.dart from
# the phone into gymrats_app/test/fixtures/pushup_cases/.
# Needs adb on PATH and a debug build of the demo (run-as only works there).
#   bash tools/diagnose/pull_pushup_cases.sh [-s <serial>] [-f]
set -euo pipefail

package=com.gymrats.gymrats_app
out_dir="$(cd "$(dirname "$0")/../.." && pwd)/gymrats_app/test/fixtures/pushup_cases"
device=()
force=0
while getopts "s:f" opt; do
  case "$opt" in
    s) device=(-s "$OPTARG") ;;
    f) force=1 ;;
    *) echo "usage: $0 [-s serial] [-f]" >&2; exit 2 ;;
  esac
done

if ! listing=$(adb ${device[@]+"${device[@]}"} shell "run-as $package ls files/pushup_cases" 2>&1); then
  echo "No recordings on the phone ($listing)."
  exit 0
fi

mkdir -p "$out_dir"
found=0
while IFS= read -r name; do
  name=${name%$'\r'}
  [[ $name == *.json ]] || continue
  found=1
  if [[ ! $name =~ ^[A-Za-z0-9_.-]+\.json$ ]]; then
    echo "skipped $name (unexpected name)" >&2
    continue
  fi
  target="$out_dir/$name"
  if [[ -e $target && $force -eq 0 ]]; then
    echo "exists  $name"
    continue
  fi
  # run-as can read the app's files; the shell user writes the copy, so adb can pull it.
  staging="/data/local/tmp/$name"
  adb ${device[@]+"${device[@]}"} shell "run-as $package cat files/pushup_cases/$name > $staging"
  adb ${device[@]+"${device[@]}"} pull "$staging" "$target" >/dev/null
  adb ${device[@]+"${device[@]}"} shell "rm -f $staging"
  echo "copied  $name"
done <<< "$listing"

[[ $found -eq 1 ]] || echo "No recordings on the phone."

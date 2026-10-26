#!/usr/bin/env bash
# Flutter coverage one test file at a time, for one shard of the test files.
# A single `flutter test --coverage` over the whole suite hangs (CI, Windows) or
# crashes (macOS) while collecting coverage, so each file gets its own run and
# its own lcov part; tools/coverage_by_layer.py merges the parts by line.
#
# Run from gymrats_app/:
#   bash ../tools/coverage_per_file.sh [SHARD] [SHARDS] [OUT_DIR]
# defaults: shard 0 of 1 (all files), OUT_DIR=coverage/parts
# Then: python3 ../tools/coverage_by_layer.py coverage/parts/*.info
# Files that time out or write no coverage are listed in OUT_DIR/left-out.txt.
set -u
shard=${1:-0}
shards=${2:-1}
out=${3:-coverage/parts}
limit=${COVERAGE_FILE_TIMEOUT:-240}   # seconds per test file
mkdir -p "$out"
: > "$out/left-out.txt"
i=0
n=0
for f in $(find test -name '*_test.dart' ! -name 'public_wss_smoke_test.dart' | sort); do
  i=$((i + 1))
  [ $(( (i - 1) % shards )) -eq "$shard" ] || continue
  n=$((n + 1))
  part="$out/$(echo "${f%.dart}" | tr '/' '_').info"
  log="$out/$(echo "${f%.dart}" | tr '/' '_').log"
  start=$(date +%s)
  timeout --kill-after=10 "$limit" flutter test --coverage --coverage-path="$part" "$f" > "$log" 2>&1
  code=$?
  took=$(( $(date +%s) - start ))
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
    echo "$f timeout after ${limit}s" >> "$out/left-out.txt"
  elif [ ! -s "$part" ]; then
    echo "$f no coverage written (exit $code)" >> "$out/left-out.txt"
  fi
  echo "[$shard/$shards] $f exit=$code ${took}s"
done
echo "shard $shard/$shards: $n test files; left out: $(wc -l < "$out/left-out.txt")"

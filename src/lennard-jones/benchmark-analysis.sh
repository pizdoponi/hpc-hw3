#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results}}"
OUTPUT_DIR="${OUTPUT_DIR:-$RESULT_ROOT/analysis}"

python3 scripts/analyze_results.py \
    --result-root "$RESULT_ROOT" \
    --output-dir "$OUTPUT_DIR"

echo "Analysis written to $OUTPUT_DIR"

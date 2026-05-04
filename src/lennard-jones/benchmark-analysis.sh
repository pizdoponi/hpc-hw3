#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RESULT_ROOT="${1:-${RESULT_ROOT:-$SCRIPT_DIR/results}}"
OUTPUT_DIR="${OUTPUT_DIR:-$RESULT_ROOT/analysis}"

python3 "$SCRIPT_DIR/scripts/analyze_results.py" \
    --result-root "$RESULT_ROOT" \
    --output-dir "$OUTPUT_DIR"

echo "Analysis written to $OUTPUT_DIR"

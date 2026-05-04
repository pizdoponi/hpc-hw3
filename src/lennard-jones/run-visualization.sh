#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
EXE="./lj.out"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
VIS_DEVICE="${VIS_DEVICE:-gpu}"
VIS_PARTICLES="${VIS_PARTICLES:-1000}"
VIS_STEPS="${VIS_STEPS:-5000}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"

if [[ ! -x "$EXE" ]]; then
    echo "Executable not found: $EXE" >&2
    echo "Build first with: make" >&2
    exit 1
fi

module load CUDA

run_dir="$RESULT_ROOT/visualization/${VIS_DEVICE}_particles_${VIS_PARTICLES}_steps_${VIS_STEPS}_block_${GPU_BLOCK_SIZE}"
mkdir -p "$run_dir"

csv_file="$run_dir/final_state.csv"
svg_file="$run_dir/final_state.svg"
run_log="$run_dir/visualization.log"

echo "Visualization run -> $run_log"
if [[ "$VIS_DEVICE" == "gpu" ]]; then
    srun "$EXE" \
        --particles "$VIS_PARTICLES" \
        --steps "$VIS_STEPS" \
        --device "$VIS_DEVICE" \
        --block-size "$GPU_BLOCK_SIZE" \
        --save-final-state "$csv_file" \
        > "$run_log" 2>&1
else
    "$EXE" \
        --particles "$VIS_PARTICLES" \
        --steps "$VIS_STEPS" \
        --device "$VIS_DEVICE" \
        --block-size "$GPU_BLOCK_SIZE" \
        --save-final-state "$csv_file" \
        > "$run_log" 2>&1
fi

python3 scripts/plot_final_state.py "$csv_file" "$svg_file"

echo "Visualization files saved to $run_dir"

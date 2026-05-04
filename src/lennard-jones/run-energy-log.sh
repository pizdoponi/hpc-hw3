#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
EXE="./lj.out"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
ENERGY_DEVICE="${ENERGY_DEVICE:-gpu}"
ENERGY_PARTICLES="${ENERGY_PARTICLES:-1000}"
ENERGY_STEPS="${ENERGY_STEPS:-5000}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"

if [[ ! -x "$EXE" ]]; then
    echo "Executable not found: $EXE" >&2
    echo "Build first with: make" >&2
    exit 1
fi

module load CUDA

run_dir="$RESULT_ROOT/energy"
mkdir -p "$run_dir"

run_log="$run_dir/energy_${ENERGY_DEVICE}_particles_${ENERGY_PARTICLES}_steps_${ENERGY_STEPS}_block_${GPU_BLOCK_SIZE}.log"

echo "Energy logging run -> $run_log"
if [[ "$ENERGY_DEVICE" == "gpu" ]]; then
    srun "$EXE" \
        --particles "$ENERGY_PARTICLES" \
        --steps "$ENERGY_STEPS" \
        --device "$ENERGY_DEVICE" \
        --block-size "$GPU_BLOCK_SIZE" \
        --log-energies \
        > "$run_log" 2>&1
else
    "$EXE" \
        --particles "$ENERGY_PARTICLES" \
        --steps "$ENERGY_STEPS" \
        --device "$ENERGY_DEVICE" \
        --block-size "$GPU_BLOCK_SIZE" \
        --log-energies \
        > "$run_log" 2>&1
fi

echo "Energy log saved to $run_log"

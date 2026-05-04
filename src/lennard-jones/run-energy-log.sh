#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EXE="${EXE:-$SCRIPT_DIR/lj.out}"
RESULT_ROOT="${1:-${RESULT_ROOT:-$SCRIPT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
ENERGY_DEVICE="${ENERGY_DEVICE:-gpu}"
ENERGY_PARTICLES="${ENERGY_PARTICLES:-1000}"
ENERGY_STEPS="${ENERGY_STEPS:-5000}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"

if [[ ! -x "$EXE" ]]; then
    echo "Executable not found: $EXE" >&2
    echo "Build first with: make" >&2
    exit 1
fi

RUNNER="${RUNNER:-}"
if [[ -z "$RUNNER" && -n "${SLURM_JOB_ID:-}" ]]; then
    RUNNER="srun"
fi

run_cmd() {
    if [[ -n "$RUNNER" ]]; then
        "$RUNNER" "$@"
    else
        "$@"
    fi
}

run_dir="$RESULT_ROOT/energy"
mkdir -p "$run_dir"

run_log="$run_dir/energy_${ENERGY_DEVICE}_particles_${ENERGY_PARTICLES}_steps_${ENERGY_STEPS}_block_${GPU_BLOCK_SIZE}.log"

echo "Energy logging run -> $run_log"
run_cmd "$EXE" \
    --particles "$ENERGY_PARTICLES" \
    --steps "$ENERGY_STEPS" \
    --device "$ENERGY_DEVICE" \
    --block-size "$GPU_BLOCK_SIZE" \
    --log-energies \
    > "$run_log" 2>&1

echo "Energy log saved to $run_log"

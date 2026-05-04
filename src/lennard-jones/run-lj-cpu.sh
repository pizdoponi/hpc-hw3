#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --job-name=lennard-jones-cpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=02:00:00
#SBATCH --output=slurm-%x-%j.out

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if type module >/dev/null 2>&1; then
    module load CUDA || true
fi

PARTICLES="${PARTICLES:-1000}"
STEPS="${STEPS:-1000}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"
LOG_ENERGIES="${LOG_ENERGIES:-0}"
SAVE_FINAL_STATE="${SAVE_FINAL_STATE:-}"

make clean
make

CMD=(./lj.out --particles "$PARTICLES" --steps "$STEPS" --device cpu --block-size "$GPU_BLOCK_SIZE")

if [[ "$LOG_ENERGIES" == "1" ]]; then
    CMD+=(--log-energies)
fi

if [[ -n "$SAVE_FINAL_STATE" ]]; then
    mkdir -p "$(dirname "$SAVE_FINAL_STATE")"
    CMD+=(--save-final-state "$SAVE_FINAL_STATE")
fi

echo "Running: ${CMD[*]}"
"${CMD[@]}"

#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --partition=gpu
#SBATCH --job-name=lennard-jones
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --time=02:00:00
#SBATCH --output=slurm-%x-%j.out

set -euo pipefail

if [[ ! -f Makefile ]]; then
    echo "Error: run-lj.sh must be run from src/lennard-jones" >&2
    exit 1
fi

module load CUDA

PARTICLES="${PARTICLES:-1000}"
STEPS="${STEPS:-1000}"
DEVICE="${DEVICE:-gpu}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"
LOG_ENERGIES="${LOG_ENERGIES:-0}"
SAVE_FINAL_STATE="${SAVE_FINAL_STATE:-}"

make clean
make

CMD=(./lj.out --particles "$PARTICLES" --steps "$STEPS" --device "$DEVICE" --block-size "$GPU_BLOCK_SIZE")

if [[ "$LOG_ENERGIES" == "1" ]]; then
    CMD+=(--log-energies)
fi

if [[ -n "$SAVE_FINAL_STATE" ]]; then
    mkdir -p "$(dirname "$SAVE_FINAL_STATE")"
    CMD+=(--save-final-state "$SAVE_FINAL_STATE")
fi

echo "Running: ${CMD[*]}"
srun "${CMD[@]}"

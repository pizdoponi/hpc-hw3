#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --partition=gpu
#SBATCH --job-name=lj-basic-suite
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --time=12:00:00
#SBATCH --output=slurm-%x-%j.out

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if type module >/dev/null 2>&1; then
    module load CUDA || true
fi

RESULT_ROOT="${1:-${RESULT_ROOT:-$SCRIPT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"
RUN_BLOCK_SWEEP="${RUN_BLOCK_SWEEP:-1}"
RUN_BASIC_CPU="${RUN_BASIC_CPU:-1}"
RUN_BASIC_GPU="${RUN_BASIC_GPU:-1}"
RUN_ENERGY_LOG="${RUN_ENERGY_LOG:-1}"
RUN_VISUALIZATION="${RUN_VISUALIZATION:-1}"

echo "Benchmark suite result root: $RESULT_ROOT"
mkdir -p "$RESULT_ROOT"

make clean
make

if [[ "$RUN_BLOCK_SWEEP" == "1" ]]; then
    ./benchmark-block-sizes.sh "$RESULT_ROOT"
fi

if [[ "$RUN_BASIC_CPU" == "1" ]]; then
    ./benchmark-cpu.sh "$RESULT_ROOT"
fi

if [[ "$RUN_BASIC_GPU" == "1" ]]; then
    ./benchmark-gpu.sh "$RESULT_ROOT" "$GPU_BLOCK_SIZE"
fi

if [[ "$RUN_ENERGY_LOG" == "1" ]]; then
    GPU_BLOCK_SIZE="$GPU_BLOCK_SIZE" ./run-energy-log.sh "$RESULT_ROOT"
fi

if [[ "$RUN_VISUALIZATION" == "1" ]]; then
    GPU_BLOCK_SIZE="$GPU_BLOCK_SIZE" ./run-visualization.sh "$RESULT_ROOT"
fi

./benchmark-analysis.sh "$RESULT_ROOT"

echo "Benchmark suite finished. Results are in $RESULT_ROOT"

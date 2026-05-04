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

PROJECT_DIR="$(pwd)"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
GPU_BLOCK_SIZE="${GPU_BLOCK_SIZE:-256}"
RUN_BLOCK_SWEEP="${RUN_BLOCK_SWEEP:-1}"
RUN_BASIC_CPU="${RUN_BASIC_CPU:-1}"
RUN_BASIC_GPU="${RUN_BASIC_GPU:-1}"
RUN_ENERGY_LOG="${RUN_ENERGY_LOG:-1}"
RUN_VISUALIZATION="${RUN_VISUALIZATION:-1}"

if [[ ! -f "$PROJECT_DIR/Makefile" ]]; then
    echo "Error: benchmark-suite.sh must be run from src/lennard-jones" >&2
    echo "Current directory: $PROJECT_DIR" >&2
    exit 1
fi

module load CUDA

echo "Benchmark suite project dir: $PROJECT_DIR"
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

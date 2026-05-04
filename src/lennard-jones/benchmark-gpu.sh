#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
EXE="./lj.out"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
GPU_BLOCK_SIZE="${2:-${GPU_BLOCK_SIZE:-256}}"
STEPS="${STEPS:-5000}"
REPEATS="${REPEATS:-5}"
REPEATS_8000="${REPEATS_8000:-$REPEATS}"
PARTICLE_COUNTS_STR="${PARTICLE_COUNTS:-1000 2000 4000 8000}"

if [[ ! -x "$EXE" ]]; then
    echo "Executable not found: $EXE" >&2
    echo "Build first with: make" >&2
    exit 1
fi

module load CUDA

IFS=' ' read -r -a PARTICLE_COUNTS <<< "$PARTICLE_COUNTS_STR"

repeats_for_particle() {
    local particles="$1"
    if [[ "$particles" == "8000" ]]; then
        echo "$REPEATS_8000"
    else
        echo "$REPEATS"
    fi
}

mkdir -p "$RESULT_ROOT/basic/gpu/block_${GPU_BLOCK_SIZE}"

echo "GPU benchmark result root: $RESULT_ROOT"
echo "GPU benchmark particle counts: ${PARTICLE_COUNTS[*]}"
echo "GPU benchmark steps: $STEPS"
echo "GPU benchmark block size: $GPU_BLOCK_SIZE"
echo "GPU benchmark repeats: $REPEATS (8000 -> $REPEATS_8000)"

for particles in "${PARTICLE_COUNTS[@]}"; do
    runs="$(repeats_for_particle "$particles")"
    run_dir="$RESULT_ROOT/basic/gpu/block_${GPU_BLOCK_SIZE}/particles_${particles}"
    mkdir -p "$run_dir"

    echo "--- GPU benchmark: particles=$particles steps=$STEPS block_size=$GPU_BLOCK_SIZE runs=$runs ---"
    for run in $(seq 1 "$runs"); do
        run_log="$run_dir/run_$(printf '%02d' "$run").log"
        echo "[$(date '+%F %T')] GPU run $run/$runs -> $run_log"
        srun "$EXE" \
            --particles "$particles" \
            --steps "$STEPS" \
            --device gpu \
            --block-size "$GPU_BLOCK_SIZE" \
            > "$run_log" 2>&1
    done
    echo

done

echo "GPU benchmarks saved to $RESULT_ROOT/basic/gpu/block_${GPU_BLOCK_SIZE}"

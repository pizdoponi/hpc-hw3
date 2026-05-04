#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
EXE="./lj.out"
RESULT_ROOT="${1:-${RESULT_ROOT:-$PROJECT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
BLOCK_SIZES_STR="${BLOCK_SIZES:-64 128 256 512}"
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

IFS=' ' read -r -a BLOCK_SIZES <<< "$BLOCK_SIZES_STR"
IFS=' ' read -r -a PARTICLE_COUNTS <<< "$PARTICLE_COUNTS_STR"

repeats_for_particle() {
    local particles="$1"
    if [[ "$particles" == "8000" ]]; then
        echo "$REPEATS_8000"
    else
        echo "$REPEATS"
    fi
}

mkdir -p "$RESULT_ROOT/block-sweep"

echo "GPU block-size sweep result root: $RESULT_ROOT"
echo "GPU block sizes: ${BLOCK_SIZES[*]}"
echo "GPU block sweep particle counts: ${PARTICLE_COUNTS[*]}"
echo "GPU block sweep steps: $STEPS"
echo "GPU block sweep repeats: $REPEATS (8000 -> $REPEATS_8000)"

for block_size in "${BLOCK_SIZES[@]}"; do
    for particles in "${PARTICLE_COUNTS[@]}"; do
        runs="$(repeats_for_particle "$particles")"
        run_dir="$RESULT_ROOT/block-sweep/block_${block_size}/gpu/particles_${particles}"
        mkdir -p "$run_dir"

        echo "--- Block sweep: block_size=$block_size particles=$particles steps=$STEPS runs=$runs ---"
        for run in $(seq 1 "$runs"); do
            run_log="$run_dir/run_$(printf '%02d' "$run").log"
            echo "[$(date '+%F %T')] block=$block_size particles=$particles run $run/$runs -> $run_log"
            srun "$EXE" \
                --particles "$particles" \
                --steps "$STEPS" \
                --device gpu \
                --block-size "$block_size" \
                > "$run_log" 2>&1
        done
        echo
    done
done

echo "GPU block-size sweep saved to $RESULT_ROOT/block-sweep"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EXE="${EXE:-$SCRIPT_DIR/lj.out}"
RESULT_ROOT="${1:-${RESULT_ROOT:-$SCRIPT_DIR/results/$(date +%Y%m%d_%H%M%S)}}"
STEPS="${STEPS:-5000}"
REPEATS="${REPEATS:-5}"
REPEATS_8000="${REPEATS_8000:-$REPEATS}"
PARTICLE_COUNTS_STR="${PARTICLE_COUNTS:-1000 2000 4000 8000}"

if [[ ! -x "$EXE" ]]; then
    echo "Executable not found: $EXE" >&2
    echo "Build first with: make" >&2
    exit 1
fi

IFS=' ' read -r -a PARTICLE_COUNTS <<< "$PARTICLE_COUNTS_STR"
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

repeats_for_particle() {
    local particles="$1"
    if [[ "$particles" == "8000" ]]; then
        echo "$REPEATS_8000"
    else
        echo "$REPEATS"
    fi
}

mkdir -p "$RESULT_ROOT/basic/cpu"

echo "CPU benchmark result root: $RESULT_ROOT"
echo "CPU benchmark particle counts: ${PARTICLE_COUNTS[*]}"
echo "CPU benchmark steps: $STEPS"
echo "CPU benchmark repeats: $REPEATS (8000 -> $REPEATS_8000)"

for particles in "${PARTICLE_COUNTS[@]}"; do
    runs="$(repeats_for_particle "$particles")"
    run_dir="$RESULT_ROOT/basic/cpu/particles_${particles}"
    mkdir -p "$run_dir"

    echo "--- CPU benchmark: particles=$particles steps=$STEPS runs=$runs ---"
    for run in $(seq 1 "$runs"); do
        run_log="$run_dir/run_$(printf '%02d' "$run").log"
        echo "[$(date '+%F %T')] CPU run $run/$runs -> $run_log"
        run_cmd "$EXE" \
            --particles "$particles" \
            --steps "$STEPS" \
            --device cpu \
            > "$run_log" 2>&1
    done
    echo

done

echo "CPU benchmarks saved to $RESULT_ROOT/basic/cpu"

#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --job-name=lj-benchmark-cpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --time=04:00:00
#SBATCH --output=benchmark_cpu_%a.log
#SBATCH --array=0-3

RESULT_ROOT="benchmark-results"
REPEATS=5
EXE=lj.out

# Map array index to particle count
PARTICLE_COUNTS=(1000 2000 4000 8000)
PARTICLES=${PARTICLE_COUNTS[$SLURM_ARRAY_TASK_ID]}
STEPS=5000

RUN_DIR="$RESULT_ROOT/cpu/particles_${PARTICLES}"
mkdir -p "$RUN_DIR"

echo "=========================================="
echo "CPU Benchmark: Particles=$PARTICLES, Steps=$STEPS"
echo "=========================================="
echo "Start time: $(date)"
echo ""

for RUN in $(seq 1 $REPEATS); do
    RUN_LOG="$RUN_DIR/run_${RUN}.log"
    echo "Run $RUN/$REPEATS -> $RUN_LOG"
    ./$EXE $PARTICLES $STEPS cpu > "$RUN_LOG" 2>&1
done

echo ""
echo "End time: $(date)"
echo "Logs saved to: $RUN_DIR"

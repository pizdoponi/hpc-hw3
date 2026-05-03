#!/bin/bash

# Benchmark analysis script
# Extracts timing information from CPU and GPU benchmark runs

echo "=========================================="
echo "Lennard-Jones Benchmark Analysis"
echo "=========================================="
echo ""

PARTICLES=(1000 2000 4000 8000)
RESULT_ROOT="benchmark-results"
RESULTS_FILE="$RESULT_ROOT/benchmark_results.txt"
REPEATS=5

mkdir -p "$RESULT_ROOT"

# Initialize results file
cat > $RESULTS_FILE << 'EOF'
Lennard-Jones Simulation Benchmark Results
==========================================

Particle Count | CPU Avg (s) | GPU Avg (s) | Speedup (S=t_cpu/t_gpu)
               |            |            |
EOF

echo "Extracting timing data..."
echo ""

for p in "${PARTICLES[@]}"; do
    CPU_DIR="$RESULT_ROOT/cpu/particles_${p}"
    GPU_DIR="$RESULT_ROOT/gpu/particles_${p}"
    
    echo "Checking particle count: $p"
    
    CPU_SUM=0
    GPU_SUM=0
    CPU_COUNT=0
    GPU_COUNT=0

    for run in $(seq 1 $REPEATS); do
        CPU_LOG="$CPU_DIR/run_${run}.log"
        GPU_LOG="$GPU_DIR/run_${run}.log"

        if [ -f "$CPU_LOG" ]; then
            CPU_TIME=$(grep -oP 'Simulation time \d+ steps: \K[0-9.]+' "$CPU_LOG" 2>/dev/null || echo "")
            if [ -n "$CPU_TIME" ]; then
                CPU_SUM=$(echo "$CPU_SUM + $CPU_TIME" | bc)
                CPU_COUNT=$((CPU_COUNT + 1))
            fi
        fi

        if [ -f "$GPU_LOG" ]; then
            GPU_TIME=$(grep -oP 'Simulation time \d+ steps: \K[0-9.]+' "$GPU_LOG" 2>/dev/null || echo "")
            if [ -n "$GPU_TIME" ]; then
                GPU_SUM=$(echo "$GPU_SUM + $GPU_TIME" | bc)
                GPU_COUNT=$((GPU_COUNT + 1))
            fi
        fi
    done

    if [ "$CPU_COUNT" -gt 0 ]; then
        CPU_AVG=$(echo "scale=3; $CPU_SUM / $CPU_COUNT" | bc)
        echo "  CPU avg: $CPU_AVG seconds over $CPU_COUNT runs"
    else
        CPU_AVG="N/A"
        echo "  CPU avg: no valid logs found"
    fi

    if [ "$GPU_COUNT" -gt 0 ]; then
        GPU_AVG=$(echo "scale=3; $GPU_SUM / $GPU_COUNT" | bc)
        echo "  GPU avg: $GPU_AVG seconds over $GPU_COUNT runs"
    else
        GPU_AVG="N/A"
        echo "  GPU avg: no valid logs found"
    fi
    
    # Calculate speedup if both times available
    if [ "$CPU_AVG" != "N/A" ] && [ "$GPU_AVG" != "N/A" ]; then
        SPEEDUP=$(echo "scale=3; $CPU_AVG / $GPU_AVG" | bc 2>/dev/null || echo "N/A")
        echo "  Speedup: $SPEEDUP x"
    else
        SPEEDUP="N/A"
    fi
    
    # Append to results file
    printf "%14d | %11s | %11s | %s\n" "$p" "$CPU_AVG" "$GPU_AVG" "$SPEEDUP" >> $RESULTS_FILE
    echo ""
done

echo "Results saved to: $RESULTS_FILE"
echo ""
cat $RESULTS_FILE

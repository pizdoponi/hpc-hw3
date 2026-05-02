#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --job-name=lennard-jones-cpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --output=lj_cpu_out.log


EXE=lj.out
if [ ! -x "$EXE" ]; then
	echo "Error: $EXE not found or not executable. Build it on a GPU node before submitting this CPU job." >&2
	exit 1
fi

echo "Running Lennard-Jones simulation on CPU..."
./$EXE 1000 1000 cpu

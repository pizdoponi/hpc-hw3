#!/bin/bash

#SBATCH --reservation=fri
#SBATCH --partition=gpu
#SBATCH --job-name=lennard-jones-gpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --output=lj_gpu_out.log

# LOAD MODULES
module load CUDA

# BUILD
make

# RUN - GPU mode
echo "Running Lennard-Jones simulation on GPU..."
srun ./lj.out 1000 1000 gpu

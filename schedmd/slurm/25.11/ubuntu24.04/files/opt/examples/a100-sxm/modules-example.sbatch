#!/bin/bash
#SBATCH --job-name=module-test
#SBATCH --nodes=1

# Load environment modules. The module command is available in all job scripts.
module load cuda/12.8.1
module load hpcx/2.25.1

echo "CUDA_HOME=$CUDA_HOME"
echo "MPI_HOME=$MPI_HOME"
nvidia-smi --query-gpu=name --format=csv,noheader

# To use personal module files stored in your home directory:
#   module use ~/.modulefiles
#   module load my-software/1.0

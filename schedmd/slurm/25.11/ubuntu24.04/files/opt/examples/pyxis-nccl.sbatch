#!/bin/bash

#SBATCH --job-name=pyxis_nccl
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --time=20:00
#SBATCH --output="%x_%j.out"
#SBATCH --exclusive

export NCCL_IB_PCI_RELAXED_ORDERING=1
export NCCL_IB_SPLIT_DATA_ON_QPS=0
export NCCL_IB_QPS_PER_CONNECTION=2
export NCCL_IBEXT_DISABLE=1
export NCCL_NVLS_ENABLE=1
export NCCL_IB_SL=1

export NCCL_TOPO_FILE=/etc/crusoe/nccl_topo/a100-80gb-sxm-ib-cloud-hypervisor.xml
export NCCL_SOCKET_IFNAME=eth0
export NCCL_IB_HCA="mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_7:1,mlx5_8:1"
export NCCL_IB_MERGE_VFS=0
export NCCL_DEBUG=WARN

export OMPI_MCA_coll_hcoll_enable=0
export PMIX_MCA_gds='^ds12'

export UCX_NET_DEVICES="mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_7:1,mlx5_8:1"

export CONTAINER_IMAGE='nvcr.io/nvidia/pytorch:25.12-py3'
export CONTAINER_SQSH='./nvidia-pytorch_25.12-py3.sqsh'
export CONTAINER_NAME='pyxis-nccl-mpi'

# Step 1: Build NCCL tests with MPI support on every node
#         --ntasks-per-node=1 ensures the named container is created on each node
srun --ntasks-per-node=1 \
        --container-name=${CONTAINER_NAME} \
        --container-image=${CONTAINER_IMAGE} \
        --container-writable \
        bash -c "git clone https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests && \
                 cd /opt/nccl-tests && \
                 make MPI=1 MPI_HOME=/opt/hpcx/ompi CUDA_HOME=/usr/local/cuda NCCL_HOME=/usr/lib/x86_64-linux-gnu -j"

# Step 2: Run the MPI-compiled NCCL all_reduce_perf test
srun --container-name=${CONTAINER_NAME} \
        --container-writable \
        --container-mounts=/etc/crusoe:/etc/crusoe:ro \
        --gpu-bind=closest \
        --mpi=pmix \
        /opt/nccl-tests/build/all_reduce_perf -b 1M -e 16G -f 2 -g 1 -n 20
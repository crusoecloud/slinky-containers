#!/bin/bash

#SBATCH --job-name=pyxis_nccl_torch
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:8
#SBATCH --output="%x_%j.out"
#SBATCH --time=01:00:00

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
#export CONTAINER_IMAGE=${CONTAINER_SQSH}
export CONTAINER_NAME='pyxis-torch'

# Set up environment variables for torchrun
GPUS_PER_NODE=8
NNODES=$SLURM_NNODES
MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
MASTER_PORT=6000

srun --container-writable \
     --container-name=${CONTAINER_NAME} \
     --container-image=${CONTAINER_IMAGE} \
     --container-mounts=/opt/examples/torch:/workspace,/etc/crusoe:/etc/crusoe:ro \
     python -u -m torch.distributed.run \
         --nproc_per_node $GPUS_PER_NODE \
         --nnodes $NNODES \
         --rdzv_endpoint ${MASTER_ADDR}:${MASTER_PORT} \
         --rdzv_backend c10d \
         --max_restarts 0 \
         --role `hostname -s`':' \
         --tee 3 \
         all_reduce_bench.py --num_iterations=1 --num_warmup_iterations=2
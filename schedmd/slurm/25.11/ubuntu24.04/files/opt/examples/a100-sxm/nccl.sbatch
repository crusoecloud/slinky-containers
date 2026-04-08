#!/bin/bash

#SBATCH --job-name=nccl_tests
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

# export UCX_RNDV_SCHEME=get_zcopy
# export UCX_TLS=self,sm,cuda_copy

export NCCL_TOPO_FILE=/etc/crusoe/nccl_topo/a100-80gb-sxm-ib-cloud-hypervisor.xml
export NCCL_SOCKET_IFNAME=eth0
export NCCL_IB_HCA="mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_7:1,mlx5_8:1"
export NCCL_IB_MERGE_VFS=0
export NCCL_DEBUG=WARN

export OMPI_MCA_coll_hcoll_enable=0
export PMIX_MCA_gds='^ds12'

export UCX_NET_DEVICES="mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_7:1,mlx5_8:1"
#export UCX_IB_GPU_DIRECT_RDMA=1
#export UCX_TLS=rc,cuda_copy,cuda_ipc,gdr_copy

srun --mpi=pmix /opt/nccl-tests/build/all_reduce_perf -b 1M -e 16G -f 2 -g 1 -n 20
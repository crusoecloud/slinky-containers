#!/bin/bash
# capture-hpcx-env.sh - Capture and format HPC-X environment variables
#
# Usage:
#   capture-hpcx-env.sh           - Output NAME=value format (for sudoers processing)
#   capture-hpcx-env.sh export    - Output export NAME=value format (for shell scripts)
#   capture-hpcx-env.sh ENV       - Output ENV NAME=value format (for Dockerfile)

set -euo pipefail

# List of HPC-X related environment variables to capture
# These are set by hpcx_load in the calling context
HPCX_VARS=(
    "HPCX_DIR"
    "HPCX_UCX_DIR"
    "HPCX_UCC_DIR"
    "HPCX_SHARP_DIR"
    "HPCX_NCCL_RDMA_SHARP_PLUGIN_DIR"
    "HPCX_HCOLL_DIR"
    "HPCX_MPI_DIR"
    "HPCX_OSHMEM_DIR"
    "HPCX_MPI_TESTS_DIR"
    "HPCX_OSU_DIR"
    "HPCX_OSU_CUDA_DIR"
    "HPCX_IPM_DIR"
    "HPCX_CLUSTERKIT_DIR"
    "OMPI_HOME"
    "MPI_HOME"
    "OSHMEM_HOME"
    "OPAL_PREFIX"
    "PATH"
    "LD_LIBRARY_PATH"
    "LIBRARY_PATH"
    "CPATH"
    "PKG_CONFIG_PATH"
    "OLD_PATH"
    "OLD_LD_LIBRARY_PATH"
    "OLD_LIBRARY_PATH"
    "OLD_CPATH"
)

FORMAT="${1:-}"

case "$FORMAT" in
    export)
        # Output: export NAME="value"
        # Used for /etc/profile.d/hpcx-env.sh
        for var in "${HPCX_VARS[@]}"; do
            if [ -n "${!var+x}" ]; then
                # Variable is set (even if empty)
                printf 'export %s="%s"\n' "$var" "${!var}"
            fi
        done
        ;;

    ENV)
        # Output: ENV NAME=value
        # Used for Dockerfile ENV directives
        for var in "${HPCX_VARS[@]}"; do
            if [ -n "${!var+x}" ]; then
                printf 'ENV %s=%s\n' "$var" "${!var}"
            fi
        done
        ;;

    *)
        # Output: NAME=value
        # Used for sudoers processing and general purposes
        for var in "${HPCX_VARS[@]}"; do
            if [ -n "${!var+x}" ]; then
                printf '%s=%s\n' "$var" "${!var}"
            fi
        done
        ;;
esac

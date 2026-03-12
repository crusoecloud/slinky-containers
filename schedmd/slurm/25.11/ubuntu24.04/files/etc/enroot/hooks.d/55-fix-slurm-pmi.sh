#!/usr/bin/env bash
# Fix for PMIx mount failures in non-MPI jobs
# Adds nofail flag to pmix mounts when directories don't exist
#
# This hook runs after 50-slurm-pmi.sh and modifies the ENROOT_MOUNTS
# file to make PMIx mounts optional if the directories weren't created
# by Slurm (which happens for non-MPI jobs).

set -euo pipefail

# Only run if we're in a Slurm job
if [ -z "${SLURM_JOB_ID-}" ] || [ -z "${SLURM_STEP_ID-}" ]; then
    exit 0
fi

# Only run if PMIx hook already processed (check for ENROOT_MOUNTS file)
if [ ! -f "${ENROOT_MOUNTS}" ]; then
    exit 0
fi

# Check if pmix mount was added by 50-slurm-pmi.sh
# If the directory doesn't exist, add nofail flag to prevent fatal errors
if command -v scontrol >/dev/null 2>&1; then
    slurm_spool=$(scontrol show config | awk '/^SlurmdSpoolDir/ {print $3}')
    pmix_path="${slurm_spool}/pmix.${SLURM_JOB_ID}.${SLURM_STEP_ID}"

    # If pmix directory doesn't exist, make the mount optional by adding nofail
    if [ ! -e "${pmix_path}" ]; then
        # Use sed to add nofail flag to the pmix mount line
        sed -i "s|\(${pmix_path}.*\)private\$|\1private,nofail|" "${ENROOT_MOUNTS}" 2>/dev/null || true
    fi
fi
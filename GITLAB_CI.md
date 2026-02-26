# GitLab CI/CD and Container Registry Guide

This document explains how to use the GitLab CI/CD pipeline and pull container images from the GitLab Container Registry.

## Overview

Container images are automatically built and published to the GitLab Container Registry on every push to any branch. The CI/CD pipeline builds 8 Slurm container images (6 core + 2 Pyxis extras) for Slurm 25.11 on Ubuntu 24.04.

## CI/CD Pipeline

### Pipeline Stages

The pipeline consists of two stages:

1. **build** - Builds all container images and pushes to registry with branch-specific tags
2. **publish** - Re-tags main branch builds with production "latest" tags (main branch only)

### What Gets Built

The pipeline builds the following images:

**Core Images (6):**
- **slurmctld** - Slurm Control Plane (central management daemon)
- **slurmd** - Slurm Worker Agent (compute node daemon)
- **slurmdbd** - Slurm Database Agent (accounting database)
- **slurmrestd** - Slurm REST API Agent
- **sackd** - Slurm Auth/Cred Server
- **login** - Slurm Login Container (workload submission)

**Pyxis Extras (2):**
- **slurmd-pyxis** - slurmd with NVIDIA Pyxis plugin (GPU workloads)
- **login-pyxis** - login with NVIDIA Pyxis plugin

### Image Tagging Convention

Images are tagged with the following pattern:

**Format:** `<version>-<flavor>-<branch>-<identifier>`

**Examples:**
- `25.11-ubuntu24.04-main-latest` - Latest build from main branch (production)
- `25.11-ubuntu24.04-main-a1b2c3d4` - Specific commit on main branch
- `25.11-ubuntu24.04-dev-ci-pipeline-latest` - Latest build from dev-ci-pipeline branch
- `25.11-ubuntu24.04-latest` - Alias for main-latest (main branch only)

**When to use which tag:**
- **Production deployments:** Use `25.11-ubuntu24.04-latest`
- **Testing specific changes:** Use branch-specific tags like `25.11-ubuntu24.04-feature-xyz-latest`
- **Reproducible deployments:** Use commit SHA tags like `25.11-ubuntu24.04-main-a1b2c3d4`

### Monitoring Pipeline Execution

1. Go to your GitLab project: **CI/CD > Pipelines**
2. Click on a running pipeline to see job details
3. View logs for build_images job to monitor progress

**Build Times:**
- First build (no cache): 30-45 minutes
- Incremental build (with cache): 10-15 minutes

## Pulling Images from GitLab Registry

### Prerequisites

1. **GitLab Account** with access to the `crusoeenergy/island/external/slinky-containers` project
2. **Docker installed** on your machine
3. **Authentication token** (Personal Access Token or Deploy Token)

### Authentication Setup

#### Option 1: Personal Access Token (for developers)

1. **Create Personal Access Token:**
   - Navigate to: GitLab > User Settings > Access Tokens
   - Click "Add new token"
   - Fill in:
     - Name: "Slinky Container Registry"
     - Expiration date: (choose appropriate date)
     - Scopes: Check `read_registry` (minimum), optionally `write_registry`
   - Click "Create personal access token"
   - **IMPORTANT:** Copy the token immediately (shown only once)

2. **Store token securely:**

```bash
# Option 1: Store in environment variable
export GITLAB_TOKEN="your-token-here"

# Option 2: Store in file (restrict permissions)
echo "your-token-here" > ~/.gitlab-token
chmod 600 ~/.gitlab-token
```

3. **Login to registry:**

```bash
# Using environment variable
echo "$GITLAB_TOKEN" | docker login registry.gitlab.com -u your-username --password-stdin

# Using file
cat ~/.gitlab-token | docker login registry.gitlab.com -u your-username --password-stdin

# One-time login (prompted for password)
docker login registry.gitlab.com -u your-username
```

#### Option 2: Deploy Token (for servers/CI)

1. **Create Deploy Token:**
   - Navigate to: GitLab Project > Settings > Repository > Deploy Tokens
   - Click "Add token"
   - Fill in:
     - Name: "Slinky Container Pull"
     - Expiration date: (optional)
     - Scopes: Check `read_registry`
   - Click "Create deploy token"
   - **IMPORTANT:** Copy both username AND token (shown only once)

2. **Store credentials:**

```bash
export GITLAB_DEPLOY_USER="gitlab+deploy-token-123"
export GITLAB_DEPLOY_TOKEN="your-token-here"
```

3. **Login to registry:**

```bash
echo "$GITLAB_DEPLOY_TOKEN" | docker login registry.gitlab.com -u "$GITLAB_DEPLOY_USER" --password-stdin
```

### Pull Commands

#### Single Image Pull

```bash
# Registry URL format
REGISTRY="registry.gitlab.com/crusoeenergy/island/external/slinky-containers"

# Pull latest stable (from main branch)
docker pull ${REGISTRY}/slurmctld:25.11-ubuntu24.04-latest

# Pull from specific branch
docker pull ${REGISTRY}/slurmd:25.11-ubuntu24.04-dev-ci-pipeline-latest

# Pull specific commit
docker pull ${REGISTRY}/slurmdbd:25.11-ubuntu24.04-main-a1b2c3d4
```

#### Bulk Pull Script

Create a script to pull all images at once:

```bash
#!/bin/bash
# pull-slinky-images.sh

REGISTRY="registry.gitlab.com/crusoeenergy/island/external/slinky-containers"
TAG="${1:-25.11-ubuntu24.04-latest}"  # Default to latest, or use first argument

echo "Pulling Slinky container images with tag: ${TAG}"

# Core images
CORE_IMAGES=(slurmctld slurmd slurmdbd slurmrestd sackd login)
for IMAGE in "${CORE_IMAGES[@]}"; do
  echo "Pulling ${IMAGE}..."
  docker pull ${REGISTRY}/${IMAGE}:${TAG}
done

# Pyxis extras
PYXIS_IMAGES=(slurmd-pyxis login-pyxis)
for IMAGE in "${PYXIS_IMAGES[@]}"; do
  echo "Pulling ${IMAGE}..."
  docker pull ${REGISTRY}/${IMAGE}:${TAG}
done

echo "All images pulled successfully!"
```

**Usage:**

```bash
chmod +x pull-slinky-images.sh
./pull-slinky-images.sh                                           # Pull latest
./pull-slinky-images.sh 25.11-ubuntu24.04-dev-ci-pipeline-latest  # Pull from specific branch
```

### Using Images in Docker Compose

```yaml
version: '3.8'

services:
  slurmctld:
    image: registry.gitlab.com/crusoeenergy/island/external/slinky-containers/slurmctld:25.11-ubuntu24.04-latest
    container_name: slurmctld
    hostname: slurmctld
    networks:
      - slurm-network
    # ... rest of configuration

  slurmd:
    image: registry.gitlab.com/crusoeenergy/island/external/slinky-containers/slurmd-pyxis:25.11-ubuntu24.04-latest
    container_name: slurmd
    hostname: slurmd
    networks:
      - slurm-network
    # ... rest of configuration

  slurmdbd:
    image: registry.gitlab.com/crusoeenergy/island/external/slinky-containers/slurmdbd:25.11-ubuntu24.04-latest
    container_name: slurmdbd
    hostname: slurmdbd
    networks:
      - slurm-network
    # ... rest of configuration

networks:
  slurm-network:
    driver: bridge
```

### Using Images in Kubernetes

1. **Create image pull secret:**

```bash
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=registry.gitlab.com \
  --docker-username=DEPLOY_USERNAME \
  --docker-password=DEPLOY_TOKEN \
  --docker-email=your-email@example.com \
  --namespace=your-namespace
```

2. **Use in Pod/Deployment:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slurm-controller
spec:
  imagePullSecrets:
    - name: gitlab-registry-secret
  containers:
    - name: slurmctld
      image: registry.gitlab.com/crusoeenergy/island/external/slinky-containers/slurmctld:25.11-ubuntu24.04-latest
```

### Viewing Available Tags

#### Via GitLab Web UI

1. Navigate to: **Project > Packages & Registries > Container Registry**
2. Click on a specific image (e.g., "slurmctld")
3. View all available tags with metadata (size, pushed date, etc.)
4. Copy tag for use in pull commands

#### Via GitLab API

```bash
# List all container repositories
curl --header "PRIVATE-TOKEN: YOUR_TOKEN" \
  "https://gitlab.com/api/v4/projects/crusoeenergy%2Fisland%2Fexternal%2Fslinky-containers/registry/repositories"

# List tags for a specific image (replace REPOSITORY_ID)
curl --header "PRIVATE-TOKEN: YOUR_TOKEN" \
  "https://gitlab.com/api/v4/projects/crusoeenergy%2Fisland%2Fexternal%2Fslinky-containers/registry/repositories/REPOSITORY_ID/tags"
```

## Troubleshooting

### Authentication Failed

**Symptom:** "Error response from daemon: unauthorized"

**Solutions:**
1. Verify token hasn't expired
2. Check token scopes include `read_registry`
3. Regenerate token if needed
4. For deploy tokens, ensure you're using the exact username provided

### Image Not Found

**Symptom:** "Error response from daemon: manifest unknown"

**Solutions:**
1. Check available tags in GitLab UI (Project > Packages & Registries > Container Registry)
2. Verify tag name matches convention
3. Ensure build completed successfully (check CI/CD > Pipelines)
4. Note that branch names with slashes become dashes (e.g., `feature/xyz` → `feature-xyz`)

### Cache Not Working (Slow Builds)

**Symptom:** Every build takes 30+ minutes even for small changes

**Solutions:**
1. Verify previous build succeeded and pushed images
2. Check registry permissions (read access required for cache)
3. Verify cache reference exists:
   ```bash
   docker manifest inspect registry.gitlab.com/crusoeenergy/island/external/slinky-containers/slurmctld:25.11-ubuntu24.04-<branch>-latest
   ```

### Build Timeout

**Symptom:** Job fails with "Timeout" error

**Solution:** The timeout is set to 2 hours in [.gitlab-ci.yml](.gitlab-ci.yml). If builds consistently timeout, contact your GitLab admin to increase runner resources or check for infrastructure issues.

## Configuration

### CI/CD Variables

You can override default build configuration without editing `.gitlab-ci.yml`:

1. Go to: **Settings > CI/CD > Variables**
2. Add variables:
   - `SLURM_VERSION`: "25.11" (default)
   - `LINUX_FLAVOR`: "ubuntu24.04" (default)
   - `BUILD_GROUP`: "all" (options: core, all, extras)

### GitLab Runner Requirements

The pipeline requires:
- GitLab Runner with Docker executor
- Sufficient disk space (100GB+ recommended)
- Network access to download Slurm sources from schedmd.com

## Additional Resources

- [GitLab Container Registry Documentation](https://docs.gitlab.com/ee/user/packages/container_registry/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Slurm Documentation](https://slurm.schedmd.com/documentation.html)

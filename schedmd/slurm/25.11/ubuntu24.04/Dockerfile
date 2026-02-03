# syntax=docker/dockerfile:1
# SPDX-FileCopyrightText: Copyright (C) SchedMD LLC.
# SPDX-License-Identifier: Apache-2.0

################################################################################

ARG SLURM_VERSION=25.11-latest
ARG SLURM_DIR=slurm
ARG PARENT_IMAGE=hpcx-base:cuda12.8.1-ubuntu24.04

################################################################################
FROM alpine:latest AS slurm-src

ARG SLURM_VERSION
ARG SLURM_DIR
ARG SLURM_TAR="slurm-${SLURM_VERSION}"

WORKDIR /workspace/

ADD https://download.schedmd.com/slurm/${SLURM_TAR}.tar.bz2 ${SLURM_TAR}.tar.bz2

RUN --mount=type=cache,target=/var/cache/apk,sharing=locked <<EOR
# Unpack Slurm Source
set -xeuo pipefail
apk upgrade -q --update-cache
apk add -q tar
mkdir -p ${SLURM_DIR}
tar --strip-components=1 -jxvf ${SLURM_TAR}.tar.bz2 -C ${SLURM_DIR}
rm ${SLURM_TAR}.tar.bz2
EOR

################################################################################
FROM ${PARENT_IMAGE} AS base

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

ARG SLURM_VERSION
ENV SLURM_VERSION=${SLURM_VERSION}

USER root
WORKDIR /tmp/

COPY --from=slurm-src /workspace/${SLURM_DIR} ${SLURM_DIR}

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR

apt-get update && apt-get install -y libjson-c-dev libhttp-parser-dev libjwt-dev libdbus-1-dev libbpf-dev

cd /tmp/${SLURM_DIR}

./configure \
    --with-pmix="/usr/lib/$(gcc -print-multiarch)/pmix2" \
    --with-jwt=/usr/ \
    --with-http-parser=/usr/ \
    --with-json=/usr/ \
    --sysconfdir=/etc/slurm \
    --with-nvml \
    --without-munge

make -j install

rm -rf /etc/slurm
cd /
rm -rf /tmp/slurm-src

EOR

ARG SLURM_USER=slurm
ARG SLURM_USER_UID=401
ARG SLURM_USER_GID=401

RUN <<EOR
# Create SlurmUser
set -xeuo pipefail
groupadd --system --gid=${SLURM_USER_GID} ${SLURM_USER}
useradd --system --no-log-init --uid=${SLURM_USER_UID} --gid=${SLURM_USER_GID} --shell=/usr/sbin/nologin ${SLURM_USER}
EOR

RUN <<EOR
# Remove Users
set -xeuo pipefail
for user in $(ls /home/); do
  userdel --remove $user
done
EOR

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
# Install Dependencies
set -xeuo pipefail
apt-get -qq update
# Init System
apt-get -qq -y install --no-install-recommends \
  supervisor tini
# Debug
apt-get -qq -y install --no-install-recommends \
  procps iputils-ping ncurses-bin
EOR

################################################################################
FROM base AS slurmctld

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

# Ref: https://slurm.schedmd.com/quickstart_admin.html#pkg_install

COPY files/etc/supervisor/supervisord.conf /etc/supervisor/
COPY \
  files/etc/supervisor/conf.d/slurmctld.conf \
  /etc/supervisor/conf.d/
COPY files/usr/local/bin/slurmctld-entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 6817/tcp
ENTRYPOINT ["entrypoint.sh"]

################################################################################
FROM base AS slurmd

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

# Ref: https://slurm.schedmd.com/quickstart_admin.html#pkg_install
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
# Configure
mkdir -p /var/spool/slurmd/
sed -i -E "s/^passwd:[[:space:]]+/&slurm /g" /etc/nsswitch.conf
sed -i -E "s/^group:[[:space:]]+/&slurm /g" /etc/nsswitch.conf
mkdir -p /etc/authselect
authselect select sssd with-mkhomedir --force
rm -f /etc/ssh/ssh_host_*
EOR

COPY files/etc/supervisor/supervisord.conf /etc/supervisor/
COPY \
  files/etc/supervisor/conf.d/fakesystemd.conf \
  files/etc/supervisor/conf.d/slurmd.conf \
  files/etc/supervisor/conf.d/sshd.conf \
  files/etc/supervisor/conf.d/sssd.conf \
  /etc/supervisor/conf.d/
COPY files/usr/local/bin/fakesystemd.sh /usr/local/bin/
COPY files/usr/local/bin/slurmd-entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 6818/tcp 22/tcp
ENTRYPOINT ["entrypoint.sh"]

################################################################################
FROM base AS slurmdbd

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

EXPOSE 6819/tcp
ENTRYPOINT ["tini", "-g", "--", "slurmdbd", "-D"]

################################################################################
FROM base AS slurmrestd

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

EXPOSE 6820/tcp
ENTRYPOINT ["tini", "-g", "--", "slurmrestd"]
CMD ["0.0.0.0:6820"]

################################################################################
FROM base AS sackd

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

ADD https://dl.k8s.io/release/stable.txt kubernetes_stable.txt

# Ref: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
# Install kubectl
set -xeuo pipefail
apt-get -qq update
VERSION="$(cat kubernetes_stable.txt | grep -Eo '^v[0-9]+\.[0-9]+')"
apt-get -qq -y install --no-install-recommends \
  apt-transport-https ca-certificates curl gnupg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get -qq update
apt-get -qq -y install --no-install-recommends kubectl
rm *.txt
EOR

# Ref: https://slurm.schedmd.com/quickstart_admin.html#pkg_install
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
# Prepare Directories
mkdir -p /run/slurm/
chown ${SLURM_USER}:${SLURM_USER} /run/slurm
EOR

COPY files/etc/supervisor/supervisord.conf /etc/supervisor/
COPY \
  files/etc/supervisor/conf.d/sackd.conf \
  files/etc/supervisor/conf.d/fakesystemd-slurm.conf \
  /etc/supervisor/conf.d/
COPY files/usr/local/bin/fakesystemd.sh /usr/local/bin/
COPY files/usr/local/bin/sackd-entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

################################################################################
FROM sackd AS login

SHELL ["bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

USER root
WORKDIR /tmp/

# Ref: https://slurm.schedmd.com/quickstart_admin.html#pkg_install
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
# Configure
mkdir -p /etc/authselect
authselect select sssd with-mkhomedir --force
rm -f /etc/ssh/ssh_host_*
EOR

COPY files/etc/supervisor/supervisord.conf /etc/supervisor/
COPY \
  files/etc/supervisor/conf.d/fakesystemd-slurm.conf \
  files/etc/supervisor/conf.d/sackd.conf \
  files/etc/supervisor/conf.d/sshd.conf \
  files/etc/supervisor/conf.d/sssd.conf \
  /etc/supervisor/conf.d/
COPY files/usr/local/bin/fakesystemd.sh /usr/local/bin/
COPY files/usr/local/bin/login-entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 22/tcp
ENTRYPOINT ["entrypoint.sh"]

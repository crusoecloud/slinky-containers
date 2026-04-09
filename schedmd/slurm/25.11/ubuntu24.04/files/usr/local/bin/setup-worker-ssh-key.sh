#!/bin/bash
# PAM session exec script. Called as root by pam_exec.so on session open.
# Copies the CSO-generated worker SSH private key from the read-only Secret volume
# to /var/lib/worker-ssh-private-keys-perms/ with per-user ownership (0600).
# The SSH client config drop-in (/etc/ssh/ssh_config.d/99-crusoe-worker.conf) points
# ssh(1) to this location via IdentityFile, enabling login-pod -> worker SSH without
# agent forwarding.
#
# No-op if the private keys volume is not mounted (e.g. worker pods, test environments).
set -exuo pipefail

echo "HOSTNAME: $(hostname)"

USERNAME="${PAM_USER}"
KEY_SRC="/var/lib/worker-ssh-private-keys/worker-private-${USERNAME}"
KEY_DST="/var/lib/worker-ssh-private-keys-perms/${USERNAME}"

[ -f "${KEY_SRC}" ] || exit 0

USER_UID=$(id -u "${USERNAME}" 2>/dev/null) || exit 0
USER_GID=$(id -g "${USERNAME}" 2>/dev/null) || exit 0

if [ "${PAM_TYPE}" = "open_session" ]; then
    cp "${KEY_SRC}" "${KEY_DST}"
    chmod 600 "${KEY_DST}"
    chown "${USER_UID}:${USER_GID}" "${KEY_DST}"
elif [ "${PAM_TYPE}" = "close_session" ]; then
    # -f so that we don't fail if key was never created, which would block session close
    rm -f "${KEY_DST}"
fi

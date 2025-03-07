#!/bin/sh

set -eux

# Create mount points
# NOTE: Busybox sh does not support `for ((i=0;i<$N;i++))` form
for f in $(seq 0 $((LIMA_CIDATA_MOUNTS - 1))); do
	mountpointvar="LIMA_CIDATA_MOUNTS_${f}_MOUNTPOINT"
	mountpoint="$(eval echo \$"$mountpointvar")"
	mkdir -p "${mountpoint}"
	gid=$(id -g "${LIMA_CIDATA_USER}")
	chown "${LIMA_CIDATA_UID}:${gid}" "${mountpoint}"
done

# Install or update the guestagent binary
install -m 755 "${LIMA_CIDATA_MNT}"/lima-guestagent /usr/local/bin/lima-guestagent

# Launch the guestagent service
if [ -f /etc/alpine-release ]; then
	# Create directory for the lima-guestagent socket (normally done by systemd)
	mkdir -p /run/user/"${LIMA_CIDATA_UID}"
	gid=$(id -g "${LIMA_CIDATA_USER}")
	chown "${LIMA_CIDATA_UID}:${gid}" /run/user/"${LIMA_CIDATA_UID}"
	chmod 700 /run/user/"${LIMA_CIDATA_UID}"
	# Install the openrc lima-guestagent service script
	cat >/etc/init.d/lima-guestagent <<'EOF'
#!/sbin/openrc-run
supervisor=supervise-daemon

name="lima-guestagent"
description="Forward ports to the lima-hostagent"

export XDG_RUNTIME_DIR="/run/user/${LIMA_CIDATA_UID}"
command=/usr/local/bin/lima-guestagent
command_args="daemon"
command_background=true
command_user="${LIMA_CIDATA_USER}:${LIMA_CIDATA_USER}"
pidfile="${XDG_RUNTIME_DIR}/lima-guestagent.pid"
EOF
	chmod 755 /etc/init.d/lima-guestagent

	rc-update add lima-guestagent default
	rc-service lima-guestagent start
else
	until [ -e "/run/user/${LIMA_CIDATA_UID}/systemd/private" ]; do sleep 3; done
	sudo -iu "${LIMA_CIDATA_USER}" "XDG_RUNTIME_DIR=/run/user/${LIMA_CIDATA_UID}" lima-guestagent install-systemd
fi

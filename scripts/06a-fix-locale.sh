#!/usr/bin/env bash
# Configura en_US.UTF-8 como locale padrão (Server e Desktop). Ver
# docs/pesquisa.md.
#
# Uso: scripts/06a-fix-locale.sh [ROOTFS=output/rootfs por padrão]
#      ROOTFS=output/rootfs-server-snapshot scripts/06a-fix-locale.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${ROOTFS:-$PROJECT_DIR/output/rootfs}"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS" >&2; exit 1; }

docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /etc/resolv.conf /rootfs/etc/resolv.conf
		cp /scripts-lib/inner-fix-locale.sh /rootfs/root/inner-fix-locale.sh
		chmod +x /rootfs/root/inner-fix-locale.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-fix-locale.sh
		rm -f /rootfs/root/inner-fix-locale.sh
	'

#!/usr/bin/env bash
# Instala o gnome-software no Desktop (ver
# scripts/lib/inner-install-gnome-software.sh e docs/pesquisa.md).
#
# Uso: scripts/07c-install-gnome-software.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
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
		cp /scripts-lib/inner-install-gnome-software.sh /rootfs/root/inner-install-gnome-software.sh
		chmod +x /rootfs/root/inner-install-gnome-software.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-install-gnome-software.sh
		rm -f /rootfs/root/inner-install-gnome-software.sh
	'

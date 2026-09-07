#!/usr/bin/env bash
# Instala o mecanismo de auto-resize da partição rootfs no primeiro boot
# (growpart + resize2fs) -- necessário antes da Fase 2 (GNOME precisa de
# bem mais que os 7GB fixos que usamos até agora). Ver docs/pesquisa.md.
#
# Uso: scripts/02g-firstboot-resize.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }

docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /etc/resolv.conf /rootfs/etc/resolv.conf
		cp /scripts-lib/inner-firstboot-resize.sh /rootfs/root/inner-firstboot-resize.sh
		chmod +x /rootfs/root/inner-firstboot-resize.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-firstboot-resize.sh
		rm -f /rootfs/root/inner-firstboot-resize.sh
	'

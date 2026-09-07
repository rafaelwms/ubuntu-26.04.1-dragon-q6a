#!/usr/bin/env bash
# Garante que o firmware pedido bem cedo no boot (GPU/DPU, principalmente
# a660_sqe.fw) esteja dentro do initramfs, não só no rootfs -- ver
# docs/pesquisa.md §4.8. Sem isso a GPU não acelera direito, o que vai
# incomodar bastante na Fase 2 (GNOME).
#
# Uso: scripts/02d-fix-initramfs-firmware.sh
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
		cp /scripts-lib/inner-fix-initramfs-firmware.sh /rootfs/root/inner-fix-initramfs-firmware.sh
		chmod +x /rootfs/root/inner-fix-initramfs-firmware.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-fix-initramfs-firmware.sh
		rm -f /rootfs/root/inner-fix-initramfs-firmware.sh
	'

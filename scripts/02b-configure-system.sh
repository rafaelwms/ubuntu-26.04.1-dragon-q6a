#!/usr/bin/env bash
# Configura o que faltava pra dar pra logar: hostname, usuário radxa/radxa
# com sudo, e SSH habilitado. Ver docs/pesquisa.md.
#
# Uso: scripts/02b-configure-system.sh
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
		cp /scripts-lib/inner-configure-system.sh /rootfs/root/inner-configure-system.sh
		chmod +x /rootfs/root/inner-configure-system.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-configure-system.sh
		rm -f /rootfs/root/inner-configure-system.sh
	'

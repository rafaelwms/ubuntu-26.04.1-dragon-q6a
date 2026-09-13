#!/usr/bin/env bash
# Corrige o bug de áudio do Desktop (SoundWire/WCD938x nunca enumera --
# ver docs/pesquisa.md §6.1). Só o Desktop precisa disso; o Server já
# funciona sem essa correção.
#
# Uso: scripts/07d-fix-desktop-audio-soundwire.sh
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
		cp /scripts-lib/inner-fix-desktop-audio-soundwire.sh /rootfs/root/inner-fix-desktop-audio-soundwire.sh
		chmod +x /rootfs/root/inner-fix-desktop-audio-soundwire.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-fix-desktop-audio-soundwire.sh
		rm -f /rootfs/root/inner-fix-desktop-audio-soundwire.sh
	'

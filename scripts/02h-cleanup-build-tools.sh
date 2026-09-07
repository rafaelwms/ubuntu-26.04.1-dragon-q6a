#!/usr/bin/env bash
# Remove ferramentas de build que só serviram pra compilar o driver aic8800
# via DKMS uma vez -- não precisamos delas na imagem final. Ver
# docs/pesquisa.md.
#
# Uso: scripts/02h-cleanup-build-tools.sh
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
		cp /scripts-lib/inner-cleanup-build-tools.sh /rootfs/root/inner-cleanup-build-tools.sh
		chmod +x /rootfs/root/inner-cleanup-build-tools.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-cleanup-build-tools.sh
		rm -f /rootfs/root/inner-cleanup-build-tools.sh
	'

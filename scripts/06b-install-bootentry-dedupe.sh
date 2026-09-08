#!/usr/bin/env bash
# Instala o serviço que remove a entrada de boot duplicada (ver
# docs/pesquisa.md e scripts/lib/inner-install-bootentry-dedupe.sh).
#
# Uso: scripts/06b-install-bootentry-dedupe.sh [ROOTFS=output/rootfs por padrão]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${ROOTFS:-$PROJECT_DIR/output/rootfs}"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS" >&2; exit 1; }

KVER="$(cd "$ROOTFS/usr/lib/modules" && ls -d */ | sed 's#/##' | grep -v generic | head -n1)"
[ -n "$KVER" ] || { echo "Não achei versão do kernel em $ROOTFS/usr/lib/modules" >&2; exit 1; }
echo ">>> Kernel: $KVER"

docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /scripts-lib/inner-install-bootentry-dedupe.sh /rootfs/root/inner-install-bootentry-dedupe.sh
		chmod +x /rootfs/root/inner-install-bootentry-dedupe.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-install-bootentry-dedupe.sh "'"$KVER"'"
		rm -f /rootfs/root/inner-install-bootentry-dedupe.sh
	'

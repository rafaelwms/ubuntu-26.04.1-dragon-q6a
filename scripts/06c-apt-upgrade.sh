#!/usr/bin/env bash
# Roda apt update && apt upgrade no rootfs, trazendo pro ponto de release
# mais recente (26.04.1). Rode SÓ depois de scripts/06b (o serviço de
# deduplicação da entrada de boot precisa já estar instalado antes, senão
# a entrada duplicada que esse upgrade pode gerar no primeiro boot real
# do usuário não seria limpa).
#
# Uso: scripts/06c-apt-upgrade.sh [ROOTFS=output/rootfs por padrão]
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
		cp /scripts-lib/inner-apt-upgrade.sh /rootfs/root/inner-apt-upgrade.sh
		chmod +x /rootfs/root/inner-apt-upgrade.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-apt-upgrade.sh
		rm -f /rootfs/root/inner-apt-upgrade.sh
	'

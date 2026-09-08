#!/usr/bin/env bash
# Troca o kernel current-qcs6490 (6.18.2) por edge-qcs6490 (7.2.3) no rootfs
# principal, e reconstrói o driver aic8800 (WiFi+BT) contra os headers
# novos. Teste pra ver se resolve a corrida do SoundWire/WCD938x (ver
# docs/pesquisa.md) -- risco conhecido: kernel 7.x tem relato de quebrar
# HDMI nessa placa.
#
# Uso: scripts/05-switch-kernel-edge.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
KERNEL_DEBS="$PROJECT_DIR/artifacts/kernel-edge-qcs6490"
AIC8800_DEBS="$PROJECT_DIR/artifacts/aic8800-dkms"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }
[ -d "$KERNEL_DEBS" ] || { echo "Kernel edge não encontrado em $KERNEL_DEBS — rode ./compile.sh kernel BOARD=radxa-dragon-q6a BRANCH=edge no armbian-build antes." >&2; exit 1; }

echo ">>> Instalando dentro do rootfs (chroot arm64)..."
docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$KERNEL_DEBS":/kernel-edge-debs:ro \
	-v "$AIC8800_DEBS":/aic8800-debs:ro \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /etc/resolv.conf /rootfs/etc/resolv.conf

		mkdir -p /rootfs/root/pkgs-edge
		cp /kernel-edge-debs/*.deb /aic8800-debs/*.deb /rootfs/root/pkgs-edge/
		cp /scripts-lib/inner-switch-kernel-edge.sh /rootfs/root/inner-switch-kernel-edge.sh
		chmod +x /rootfs/root/inner-switch-kernel-edge.sh

		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-switch-kernel-edge.sh
		rm -f /rootfs/root/inner-switch-kernel-edge.sh
	'

echo ">>> Pronto. Kernel do rootfs principal agora é o edge (7.2.3)."

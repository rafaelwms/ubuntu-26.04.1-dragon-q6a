#!/usr/bin/env bash
# Instala o driver Wi-Fi USB AIC8800 (DKMS, mesmos pacotes que o Armbian usa
# pra essa placa) e o alsa-utils (aplay/amixer/speaker-test), pra testar
# áudio de verdade. Precisamos disso rodando localmente porque a Q6A não tem
# rede própria ainda pra instalar essas coisas sozinha.
#
# Uso: scripts/02c-install-wifi-audio-tools.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
KERNEL_DEBS="$PROJECT_DIR/artifacts/kernel-current-qcs6490"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"
CACHE="$PROJECT_DIR/artifacts/aic8800-dkms"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }

mkdir -p "$CACHE"

echo ">>> Baixando pacotes do driver aic8800 (radxa-pkg/aic8800, última release)..."
LATEST_VERSION="$(curl -s https://api.github.com/repos/radxa-pkg/aic8800/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')"
[ -n "$LATEST_VERSION" ] || { echo "Não consegui descobrir a última versão do aic8800." >&2; exit 1; }
echo "Versão: $LATEST_VERSION"

for f in "aic8800-usb-dkms_${LATEST_VERSION}_all.deb" "aic8800-firmware_${LATEST_VERSION}_all.deb"; do
	if [ ! -f "$CACHE/$f" ]; then
		url="https://github.com/radxa-pkg/aic8800/releases/download/${LATEST_VERSION}/${f}"
		curl -sL -o "$CACHE/$f.tmp" "$url"
		mv "$CACHE/$f.tmp" "$CACHE/$f"
	fi
done

echo ">>> Instalando dentro do rootfs (chroot arm64)..."
docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$KERNEL_DEBS":/kernel-debs:ro \
	-v "$CACHE":/aic8800-debs:ro \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /etc/resolv.conf /rootfs/etc/resolv.conf

		mkdir -p /rootfs/root/pkgs
		cp /kernel-debs/linux-headers-*.deb /aic8800-debs/*.deb /rootfs/root/pkgs/
		cp /scripts-lib/inner-install-wifi-audio-tools.sh /rootfs/root/inner-install-wifi-audio-tools.sh
		chmod +x /rootfs/root/inner-install-wifi-audio-tools.sh

		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-install-wifi-audio-tools.sh
		rm -f /rootfs/root/inner-install-wifi-audio-tools.sh
	'

echo ">>> Pronto."

#!/usr/bin/env bash
# Monta a imagem final: instala o pacote systemd-boot no rootfs, cria um .img
# raw com a tabela de partições real (config 16MB + efi 1GB + rootfs = resto,
# ver docs/pesquisa.md §3.1), copia output/rootfs pra dentro, monta a ESP com
# o systemd-boot, e comprime em .img.xz.
#
# Não usa loop device em nenhum momento (ver comentários em
# scripts/lib/provision-partitions.sh sobre por que).
#
# Uso: scripts/03-assemble-image.sh [nome-da-imagem] [tamanho-total, ex.: 12G]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${ROOTFS:-$PROJECT_DIR/output/rootfs}"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"
IMG_NAME="${1:-radxa-dragon-q6a_resolute_server_dev.img}"
IMG_PATH="$PROJECT_DIR/output/$IMG_NAME"
IMG_SIZE="${2:-8G}"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }

echo ">>> Instalando o pacote systemd-boot no rootfs (chroot arm64)..."
docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /etc/resolv.conf /rootfs/etc/resolv.conf
		cp /scripts-lib/inner-install-bootloader-pkg.sh /rootfs/root/inner-install-bootloader-pkg.sh
		chmod +x /rootfs/root/inner-install-bootloader-pkg.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-install-bootloader-pkg.sh
		rm -f /rootfs/root/inner-install-bootloader-pkg.sh
	'

echo ">>> Criando imagem raw vazia ($IMG_SIZE) em $IMG_PATH ..."
rm -f "$IMG_PATH"
truncate -s "$IMG_SIZE" "$IMG_PATH"

echo ">>> Particionando e montando o conteúdo (sem loop device)..."
docker run --rm \
	-v "$PROJECT_DIR/output":/work \
	-v "$ROOTFS":/rootfs-src \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		apt-get update -qq
		apt-get install -y -qq gdisk dosfstools e2fsprogs mtools util-linux uuid-runtime xxd >/dev/null
		IMG="/work/'"$IMG_NAME"'" bash /scripts-lib/provision-partitions.sh
	'

echo ">>> Comprimindo em .img.xz (pode levar alguns minutos)..."
xz -T0 -k -f "$IMG_PATH"

echo ">>> Pronto:"
ls -la "$IMG_PATH" "$IMG_PATH.xz"

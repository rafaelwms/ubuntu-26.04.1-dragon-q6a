#!/usr/bin/env bash
# Instala no rootfs (output/rootfs):
#   - kernel mainline 6.18 (Armbian, current-qcs6490) já baixado em artifacts/
#   - firmware específico da Q6A extraído do install real (artifacts/firmware-qcs6490-dragon-q6a)
#   - linux-firmware completo do Ubuntu (pro resto do hardware)
#   - o backport de alsa-ucm-conf da Radxa (fix do áudio, ver docs/pesquisa.md §2.2/§3.2)
#
# Tudo roda dentro de um container Docker privilegiado (root do container) + qemu-aarch64-static
# pra fazer chroot em arm64 sem precisar de sudo no host (o rootfs é gerado com arquivos
# root:root — só o root do container consegue escrever nele).
#
# Uso: scripts/02-install-kernel-firmware.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
KERNEL_DEBS="$PROJECT_DIR/artifacts/kernel-current-qcs6490"
FW_SRC="$PROJECT_DIR/artifacts/firmware-qcs6490-dragon-q6a"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"
UCM_VER="1.2.16.1-radxa-1"
UCM_URL="https://github.com/radxa-pkg/alsa-ucm-conf/releases/download/${UCM_VER}/alsa-ucm-conf_${UCM_VER}_all.deb"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01-build-rootfs.sh antes." >&2; exit 1; }

echo ">>> Instalando kernel + firmware + fix de áudio dentro do rootfs (container Docker)..."
docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$KERNEL_DEBS":/kernel-debs:ro \
	-v "$FW_SRC":/fw-src:ro \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	-e UCM_URL="$UCM_URL" \
	ubuntu:24.04 bash /scripts-lib/provision-kernel-firmware.sh

echo ">>> Reaplicando por cima o firmware específico verificado da Q6A (garante que ganha do linux-firmware genérico)..."
docker run --rm \
	-v "$ROOTFS":/rootfs \
	-v "$FW_SRC":/fw-src:ro \
	ubuntu:24.04 bash -c "cp -a /fw-src/qcom /fw-src/ath11k /rootfs/usr/lib/firmware/"

echo ">>> Pronto. Kernel instalado:"
ls "$ROOTFS/usr/lib/modules/" 2>&1
echo ">>> alsa-ucm-conf instalado:"
grep -A1 "^Package: alsa-ucm-conf$" "$ROOTFS/var/lib/dpkg/status" 2>&1 | head -4
echo ">>> Symlink do perfil de áudio da Q6A agora resolve?"
ls -la "$ROOTFS/usr/share/alsa/ucm2/conf.d/qcs6490/QCS6490-Radxa-Dragon-Q6A.conf" 2>&1
readlink -f "$ROOTFS/usr/share/alsa/ucm2/conf.d/qcs6490/QCS6490-Radxa-Dragon-Q6A.conf" 2>&1

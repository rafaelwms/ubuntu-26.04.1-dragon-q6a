#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Remove as ferramentas que só serviram pra compilar o driver aic8800 via
# DKMS (gcc, build-essential, dkms, headers do kernel, e o próprio pacote
# aic8800-usb-dkms).
#
# ⚠️ Purgar o `dkms` sozinho REMOVE em cascata o `aic8800-usb-dkms` (que
# depende dele) E os .ko já compilados (dkms limpa os próprios builds ao
# ser removido) -- isso já nos mordeu uma vez. Por isso: copiamos os .ko
# pra fora do controle do dkms ANTES de purgar qualquer coisa, e os
# recolocamos depois como arquivos "soltos" (não gerenciados por pacote
# nenhum, só pelo depmod) -- é assim que módulos out-of-tree funcionam em
# qualquer distro, independente do dkms continuar instalado ou não.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

KVER="$(cd /usr/lib/modules && ls -d */ | sed 's#/##' | grep -v generic | head -n1)"
SRC_DIR="/usr/lib/modules/${KVER}/updates/dkms"
DEST_DIR="/usr/lib/modules/${KVER}/extra/aic8800"

echo "=== módulos aic8800 ANTES da limpeza ==="
find "$SRC_DIR" -type f

echo "=== copiando pra fora do controle do dkms (${DEST_DIR}) ==="
mkdir -p "$DEST_DIR"
cp -a "$SRC_DIR"/*.ko "$DEST_DIR"/

apt-get purge -y \
	aic8800-usb-dkms \
	build-essential dkms bison flex libssl-dev libelf-dev dwarves \
	linux-headers-current-qcs6490 \
	gcc-15 gcc-15-aarch64-linux-gnu g++-15 g++-15-aarch64-linux-gnu \
	gcc gcc-aarch64-linux-gnu g++ g++-aarch64-linux-gnu \
	cpp cpp-15 cpp-15-aarch64-linux-gnu cpp-aarch64-linux-gnu \
	dpkg-dev binutils binutils-aarch64-linux-gnu \
	2>&1 | tail -40 || true
apt-get autoremove -y

# a essa altura o apt/dkms já deve ter apagado $SRC_DIR -- confirma e
# garante que a cópia em $DEST_DIR sobreviveu
echo "=== módulos aic8800 DEPOIS da limpeza (tem que continuar aqui, em extra/) ==="
find "$DEST_DIR" -type f

depmod -a "$KVER"
echo "=== modules.dep reconhece os módulos? ==="
grep -c "extra/aic8800" "/usr/lib/modules/${KVER}/modules.dep" || { echo "AVISO: não apareceu em modules.dep"; exit 1; }

df -h /

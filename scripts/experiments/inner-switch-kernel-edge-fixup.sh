#!/usr/bin/env bash
# Correção pontual: a primeira rodada de inner-switch-kernel-edge.sh purgou
# o kernel current-qcs6490 (6.18.2) num passo que, por algum motivo (talvez
# o postinst do kernel edge ainda segurando algum lock), não teve efeito
# na hora -- dpkg -l confirmou depois que current-qcs6490 continuava
# instalado. Rodado manualmente uma segunda vez, o purge funcionou. Este
# script termina o resto do trabalho que o inner-switch-kernel-edge.sh
# não pôde terminar (ele morreu no "cp .../updates/dkms/*.ko" porque KVER
# tinha detectado o kernel errado -- o 6.18.2 antigo, que já não tinha
# mais updates/dkms desde a limpeza da Fase 1).
#
# Também corrige o bug conhecido (ver docs/pesquisa.md) de
# `apt-get install build-essential dkms` puxar linux-headers-generic (~281MB)
# do kernel HOST (7.0.0-31), que não tem nada a ver com a placa.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== kernels instalados (dpkg) ==="
dpkg -l | grep -i "linux-image\|linux-dtb\|linux-headers" || true

echo "=== removendo lixo do kernel genérico do host (7.0.0-31) ==="
apt-get purge -y linux-headers-generic linux-headers-7.0.0-31-generic linux-headers-7.0.0-31 || true
apt-get autoremove -y
rm -rf /usr/lib/modules/7.0.0-31-generic

echo "=== removendo restos do kernel current-qcs6490 (6.18.2), já purgado do dpkg ==="
rm -rf /usr/lib/modules/6.18.2-current-qcs6490
rm -f /boot/vmlinuz.old /boot/initrd.img.old
rm -f /boot/*-6.18.2-current-qcs6490 /boot/dtb-6.18.2-current-qcs6490 2>/dev/null || true
rm -rf /boot/dtb-6.18.2-current-qcs6490

echo "=== /usr/lib/modules depois da limpeza (só deve sobrar o edge) ==="
ls /usr/lib/modules/
KVER="$(cd /usr/lib/modules && ls -d */ | sed 's#/##' | grep -v generic | head -n1)"
echo "Kernel final: $KVER"
[ "$KVER" = "7.2.3-edge-qcs6490" ] || { echo "ERRO: esperava 7.2.3-edge-qcs6490, achei $KVER"; exit 1; }

echo "=== /boot vmlinuz/initrd atuais ==="
ls -la /boot/vmlinuz* /boot/initrd.img* /boot/dtb-*

echo "=== garantindo que o driver aic8800 foi compilado pro kernel edge ==="
dkms status
find "/usr/lib/modules/${KVER}/updates/dkms" -type f

echo "=== copiando .ko pra fora do controle do dkms ANTES de purgar build tools ==="
DEST_DIR="/usr/lib/modules/${KVER}/extra/aic8800"
mkdir -p "$DEST_DIR"
cp -a "/usr/lib/modules/${KVER}/updates/dkms/"*.ko "$DEST_DIR"/

apt-get purge -y \
	aic8800-usb-dkms \
	build-essential dkms bison flex libssl-dev libelf-dev dwarves \
	linux-headers-edge-qcs6490 \
	gcc-15 gcc-15-aarch64-linux-gnu g++-15 g++-15-aarch64-linux-gnu \
	gcc gcc-aarch64-linux-gnu g++ g++-aarch64-linux-gnu \
	cpp cpp-15 cpp-15-aarch64-linux-gnu cpp-aarch64-linux-gnu \
	dpkg-dev binutils binutils-aarch64-linux-gnu \
	2>&1 | tail -60 || true
apt-get autoremove -y

echo "=== módulos aic8800 depois da limpeza (tem que continuar aqui, em extra/) ==="
find "$DEST_DIR" -type f

depmod -a "$KVER"
echo "=== modules.dep reconhece os módulos? ==="
grep -c "extra/aic8800" "/usr/lib/modules/${KVER}/modules.dep" || { echo "AVISO: não apareceu em modules.dep"; exit 1; }

echo "=== regenerando initramfs pra garantir consistência (só deve existir o do edge agora) ==="
update-initramfs -u -k all
ls -la /boot/initrd.img* /boot/vmlinuz*

rm -rf /root/pkgs-edge
df -h /
echo "=== dpkg final ==="
dpkg -l | grep -i "linux-image\|linux-dtb\|linux-headers" || true

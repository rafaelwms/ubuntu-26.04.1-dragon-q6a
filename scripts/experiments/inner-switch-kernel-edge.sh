#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Troca o kernel current-qcs6490 (6.18.2) pelo edge-qcs6490 (7.2.3) -- teste
# pra ver se a corrida do SoundWire/WCD938x (ver docs/pesquisa.md) já foi
# corrigida numa versão mais nova do kernel. Reconstrói o driver aic8800
# (WiFi+BT) contra os headers novos, do mesmo jeito que 02c fez pro 6.18.
#
# ⚠️ Risco conhecido: kernel 7.x tem uma regressão de HDMI reportada no
# fórum da Radxa pra essa placa (não confirmado se 7.2.3 já corrige).
# Testar HDMI é a PRIMEIRA coisa a verificar depois de gravar.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== kernel atual (antes da troca) ==="
ls /usr/lib/modules/

apt-get update
apt-get -f install -y || true # corrige qualquer pacote deixado pela metade numa tentativa anterior

echo "=== removendo kernel current-qcs6490 (6.18.2) ==="
apt-get purge -y linux-image-current-qcs6490 linux-dtb-current-qcs6490 linux-headers-current-qcs6490 || true
apt-get autoremove -y

echo "=== instalando kernel edge-qcs6490 (7.2.3) ==="
dpkg -i /root/pkgs-edge/linux-image-edge-qcs6490_*.deb /root/pkgs-edge/linux-dtb-edge-qcs6490_*.deb /root/pkgs-edge/linux-libc-dev-edge-qcs6490_*.deb || true
apt-get -f install -y

echo "=== kernel depois da troca ==="
ls /usr/lib/modules/
KVER="$(cd /usr/lib/modules && ls -d */ | sed 's#/##' | grep -v generic | head -n1)"
echo "Novo kernel: $KVER"

echo "=== reconstruindo driver aic8800 (WiFi+BT) pro kernel novo ==="
apt-get install -y build-essential dkms bison flex libssl-dev libelf-dev dwarves
dpkg -i /root/pkgs-edge/linux-headers-edge-qcs6490_*.deb || true
apt-get -f install -y

dpkg -i /root/pkgs-edge/aic8800-firmware_*.deb /root/pkgs-edge/aic8800-usb-dkms_*.deb || true
apt-get -f install -y
dkms status

echo "=== atualizando initramfs (hook zz-qcs6490-firmware já está em /etc/initramfs-tools/hooks) ==="
ls /etc/initramfs-tools/hooks/zz-qcs6490-firmware
update-initramfs -u -k all

echo "=== limpando ferramentas de build de novo (mesmo cuidado do 02h: copiar .ko ANTES de purgar dkms) ==="
SRC_DIR="/usr/lib/modules/${KVER}/updates/dkms"
DEST_DIR="/usr/lib/modules/${KVER}/extra/aic8800"
mkdir -p "$DEST_DIR"
cp -a "$SRC_DIR"/*.ko "$DEST_DIR"/

apt-get purge -y \
	aic8800-usb-dkms \
	build-essential dkms bison flex libssl-dev libelf-dev dwarves \
	linux-headers-edge-qcs6490 \
	gcc-15 gcc-15-aarch64-linux-gnu g++-15 g++-15-aarch64-linux-gnu \
	gcc gcc-aarch64-linux-gnu g++ g++-aarch64-linux-gnu \
	cpp cpp-15 cpp-15-aarch64-linux-gnu cpp-aarch64-linux-gnu \
	dpkg-dev binutils binutils-aarch64-linux-gnu \
	2>&1 | tail -40 || true
apt-get autoremove -y

echo "=== módulos aic8800 depois da limpeza (tem que continuar aqui, em extra/) ==="
find "$DEST_DIR" -type f

depmod -a "$KVER"
echo "=== modules.dep reconhece os módulos? ==="
grep -c "extra/aic8800" "/usr/lib/modules/${KVER}/modules.dep" || { echo "AVISO: não apareceu em modules.dep"; exit 1; }

rm -rf /root/pkgs-edge
df -h /

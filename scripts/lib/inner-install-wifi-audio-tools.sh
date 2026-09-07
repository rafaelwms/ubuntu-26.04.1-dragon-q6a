#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala:
#   - headers do kernel (necessário pro DKMS compilar o módulo)
#   - driver AIC8800 (WiFi+Bluetooth USB, chip combo) via DKMS, mesmos
#     pacotes que o Armbian usa (radxa-pkg/aic8800, extensão radxa-aic8800.sh)
#   - alsa-utils (aplay/amixer/speaker-test) pra testar áudio de verdade
#   - bluez + rfkill pro Bluetooth (mesmo dongle, ver docs/pesquisa.md §4.6)
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -f install -y || true # corrige qualquer pacote deixado pela metade numa tentativa anterior
apt-get install -y build-essential dkms bison flex libssl-dev libelf-dev dwarves

dpkg -i /root/pkgs/linux-headers-*.deb || true
apt-get -f install -y

dpkg -i /root/pkgs/aic8800-firmware_*.deb /root/pkgs/aic8800-usb-dkms_*.deb || true
apt-get -f install -y

mkdir -p /usr/lib/systemd/network/
cat > /usr/lib/systemd/network/50-radxa-aic8800.link <<'EOF'
[Match]
OriginalName=wlan*
Driver=usb

[Link]
NamePolicy=kernel
EOF

apt-get install -y alsa-utils bluez rfkill
systemctl enable bluetooth

rm -f /root/pkgs/linux-headers-*.deb /root/pkgs/aic8800-*.deb

echo "=== módulo aic8800 (dkms status) ==="
dkms status || true

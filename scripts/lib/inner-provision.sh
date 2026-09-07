#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static). $1 = URL do .deb do alsa-ucm-conf da Radxa.
set -euxo pipefail

UCM_URL="$1"
export DEBIAN_FRONTEND=noninteractive

apt-get update
dpkg -i /root/pkgs/*.deb || true
apt-get -f install -y
apt-get install -y linux-firmware wget ca-certificates
rm -rf /root/pkgs

cd /tmp
wget -q "$UCM_URL" -O ucm.deb
dpkg -i ucm.deb
rm -f ucm.deb

update-initramfs -u -k all

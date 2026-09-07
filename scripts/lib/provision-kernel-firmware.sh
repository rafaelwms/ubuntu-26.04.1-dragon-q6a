#!/usr/bin/env bash
# Roda DENTRO do container Docker (root do container), com /rootfs, /kernel-debs
# e /fw-src bind-mountados. Ver scripts/02-install-kernel-firmware.sh.
set -euxo pipefail

cat > /rootfs/etc/apt/sources.list <<EOF
deb http://ports.ubuntu.com/ubuntu-ports resolute main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports resolute-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports resolute-security main restricted universe multiverse
EOF

mkdir -p /rootfs/root/pkgs
cp /kernel-debs/linux-image-*.deb /kernel-debs/linux-dtb-*.deb /rootfs/root/pkgs/
cp /scripts-lib/inner-provision.sh /rootfs/root/inner-provision.sh
chmod +x /rootfs/root/inner-provision.sh

# NÃO copiamos o firmware vendor extraído (artifacts/firmware-qcs6490-dragon-q6a) por cima --
# ele tem um ABI (GPR/AudioReach) de uma versão diferente da que o driver q6apm do kernel
# mainline 6.18 espera, causando "qcom-apm gprsvc: CMD timeout" e travando o áudio (mesmo bug
# que o armbian/firmware#129 corrigiu). O `apt-get install linux-firmware` abaixo já traz as
# versões certas, compatíveis com o kernel mainline. Ver docs/pesquisa.md §4.3.

cp /etc/resolv.conf /rootfs/etc/resolv.conf

mount -t proc proc /rootfs/proc
mount --rbind /sys /rootfs/sys
mount --rbind /dev /rootfs/dev
trap 'umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc' EXIT

chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-provision.sh "$UCM_URL"
rm -f /rootfs/root/inner-provision.sh

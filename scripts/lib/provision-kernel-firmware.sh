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

mkdir -p /rootfs/usr/lib/firmware
cp -a /fw-src/qcom /fw-src/ath11k /rootfs/usr/lib/firmware/

cp /etc/resolv.conf /rootfs/etc/resolv.conf

mount -t proc proc /rootfs/proc
mount --rbind /sys /rootfs/sys
mount --rbind /dev /rootfs/dev
trap 'umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc' EXIT

chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-provision.sh "$UCM_URL"
rm -f /rootfs/root/inner-provision.sh

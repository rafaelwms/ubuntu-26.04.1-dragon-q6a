#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static), com a ESP já montada em /boot/efi.
# $1 = UUID da partição rootfs.
set -euxo pipefail

ROOTFS_UUID="$1"
EFI_UUID="$2"
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y systemd-boot

bootctl install --esp-path=/boot/efi --no-variables

cat > /boot/efi/loader/loader.conf <<'EOF'
timeout 3
EOF

KVER="$(cd /usr/lib/modules && ls -d */ | sed 's#/##' | head -n1)"
[ -n "$KVER" ] || { echo "Não achei versão do kernel em /usr/lib/modules" >&2; exit 1; }

mkdir -p "/boot/efi/ubuntu/${KVER}"
cp "/boot/vmlinuz-${KVER}" "/boot/efi/ubuntu/${KVER}/vmlinuz-${KVER}"
cp "/boot/initrd.img-${KVER}" "/boot/efi/ubuntu/${KVER}/initrd.img-${KVER}"

mkdir -p /boot/efi/loader/entries
cat > "/boot/efi/loader/entries/ubuntu-${KVER}.conf" <<EOF
title      Ubuntu 26.04 LTS (Resolute Raccoon)
version    ${KVER}
options    root=UUID=${ROOTFS_UUID} rw console=ttyMSM0,115200n8 console=tty1 earlycon consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0
linux      /ubuntu/${KVER}/vmlinuz-${KVER}
initrd     /ubuntu/${KVER}/initrd.img-${KVER}
EOF

# fstab básico
cat > /etc/fstab <<EOF
UUID=${ROOTFS_UUID}  /          ext4  defaults  0 1
UUID=${EFI_UUID}     /boot/efi  vfat  umask=0077  0 1
EOF

echo "Entrada BLS criada:"
cat "/boot/efi/loader/entries/ubuntu-${KVER}.conf"
echo "Conteúdo da ESP:"
find /boot/efi -maxdepth 4

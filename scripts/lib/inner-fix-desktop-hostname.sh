#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Corrige o hostname do Desktop: como ele é construído em cima do rootfs
# do Server já configurado (que grava "q6a-server" em scripts/02b), o
# Desktop herdava o mesmo nome. Ver docs/pesquisa.md.
set -euxo pipefail

NEW_HOSTNAME="q6a-desktop"
OLD_HOSTNAME="$(cat /etc/hostname)"

echo "$NEW_HOSTNAME" > /etc/hostname
sed -i "s/\b${OLD_HOSTNAME}\b/${NEW_HOSTNAME}/g" /etc/hosts

echo "=== /etc/hostname ==="
cat /etc/hostname
echo "=== /etc/hosts ==="
cat /etc/hosts

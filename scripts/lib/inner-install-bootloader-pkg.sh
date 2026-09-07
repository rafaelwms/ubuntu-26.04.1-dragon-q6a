#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static). Só instala o pacote
# systemd-boot (pro binário .efi) -- NÃO mexe em nenhuma ESP montada, porque
# nesta etapa ainda não existe nenhuma (montamos/gravamos a ESP depois, fora
# do chroot, sem loop device -- ver scripts/lib/provision-partitions.sh).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y systemd-boot

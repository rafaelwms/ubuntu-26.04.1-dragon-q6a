#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala o GNOME mínimo (ubuntu-desktop-minimal -- sem LibreOffice,
# Thunderbird, jogos etc., por pedido explícito do usuário) por cima do
# Server já validado.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ubuntu-desktop-minimal

echo "=== display manager habilitado? ==="
systemctl is-enabled gdm3 || systemctl is-enabled gdm || true
echo "=== default target ==="
systemctl get-default

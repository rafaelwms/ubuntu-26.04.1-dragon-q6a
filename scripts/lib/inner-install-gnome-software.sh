#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala o gnome-software (Central de Software clássica, via apt/PackageKit,
# SEM depender de snapd) -- a mensagem de boas-vindas do gnome-initial-setup
# menciona um "Centro de Aplicativos" que não vem no ubuntu-desktop-minimal.
# Não instalamos o "App Center" oficial da Ubuntu porque esse é distribuído
# como snap, reintroduzindo o mesmo peso que evitamos no Firefox. Ver
# docs/pesquisa.md.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get install -y gnome-software

echo "=== instalado ==="
dpkg -l gnome-software

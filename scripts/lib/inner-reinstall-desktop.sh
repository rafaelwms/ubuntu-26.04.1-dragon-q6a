#!/usr/bin/env bash
# Correção: o purge de ferramentas de build em inner-switch-kernel-edge-fixup.sh
# incluiu `binutils`, que é dependência DIRETA do pacote `crash` (Depends:
# binutils) -- purgar binutils derrubou crash -> makedumpfile -> a cadeia
# que o ubuntu-desktop-minimal também depende, e o apt decidiu remover o
# desktop inteiro (ubuntu-desktop-minimal, gdm3, x11-xserver-utils) junto.
# Ver docs/pesquisa.md. Este script reinstala o desktop e reaplica o fix
# do tpm2.target. Daqui pra frente, NÃO purgar binutils/binutils-* quando
# o Desktop estiver instalado.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ubuntu-desktop-minimal

systemctl mask tpm2.target

echo "=== display manager habilitado? ==="
systemctl is-enabled gdm3 || systemctl is-enabled gdm || true
echo "=== default target ==="
systemctl get-default

echo "=== kernel/kernel modules pkgs ==="
dpkg -l | grep -i "linux-image\|linux-dtb\|linux-headers"
ls /usr/lib/modules/

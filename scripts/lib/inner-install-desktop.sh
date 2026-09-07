#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala o GNOME mínimo (ubuntu-desktop-minimal -- sem LibreOffice,
# Thunderbird, jogos etc., por pedido explícito do usuário) por cima do
# Server já validado.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ubuntu-desktop-minimal

# O firmware/UEFI dessa placa anuncia presença de TPM via ACPI (tem
# EventLog na tabela EFI), mas não existe chip de verdade respondendo --
# o systemd fica ~90s esperando /dev/tpm0 e /dev/tpmrm0 aparecerem via
# tpm2.target antes de desistir. Não usamos nada que dependa de TPM
# (sem disk encryption seladp por TPM, etc.), então é seguro mascarar.
systemctl mask tpm2.target

echo "=== display manager habilitado? ==="
systemctl is-enabled gdm3 || systemctl is-enabled gdm || true
echo "=== default target ==="
systemctl get-default

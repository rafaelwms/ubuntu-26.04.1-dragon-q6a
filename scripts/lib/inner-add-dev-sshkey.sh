#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static). $1 = conteúdo da chave pública.
#
# ⚠️ SÓ PRA DESENVOLVIMENTO. Antes de gerar a imagem "Server" definitiva
# (e antes de migrar pra Fase 2 / Desktop), rode scripts/02f-remove-dev-sshkey.sh
# pra tirar essa chave da imagem. Ver docs/pesquisa.md §4.9.
set -euxo pipefail

PUBKEY="$1"
USERNAME="radxa"
HOME_DIR="/home/${USERNAME}"

install -d -m 700 -o "$USERNAME" -g "$USERNAME" "${HOME_DIR}/.ssh"
grep -qxF "$PUBKEY" "${HOME_DIR}/.ssh/authorized_keys" 2>/dev/null || echo "$PUBKEY" >> "${HOME_DIR}/.ssh/authorized_keys"
chmod 600 "${HOME_DIR}/.ssh/authorized_keys"
chown "$USERNAME:$USERNAME" "${HOME_DIR}/.ssh/authorized_keys"

echo "Chave de desenvolvimento autorizada para ${USERNAME}."

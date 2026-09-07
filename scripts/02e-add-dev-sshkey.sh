#!/usr/bin/env bash
# ⚠️ SÓ PRA DESENVOLVIMENTO — autoriza a chave SSH deste desktop no rootfs,
# pra não precisar reautorizar a cada regravação do SSD. NÃO deve entrar na
# imagem "Server" definitiva nem em nenhuma imagem que saia da bancada de
# testes -- rode scripts/02f-remove-dev-sshkey.sh antes disso (ver
# docs/pesquisa.md §4.9).
#
# Uso: scripts/02e-add-dev-sshkey.sh [caminho-da-chave-pública]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"
PUBKEY_FILE="${1:-$HOME/.ssh/id_ed25519_q6a.pub}"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }
[ -f "$PUBKEY_FILE" ] || { echo "Chave pública não encontrada: $PUBKEY_FILE" >&2; exit 1; }
PUBKEY="$(cat "$PUBKEY_FILE")"

docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	-e PUBKEY="$PUBKEY" \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT
		cp /scripts-lib/inner-add-dev-sshkey.sh /rootfs/root/inner-add-dev-sshkey.sh
		chmod +x /rootfs/root/inner-add-dev-sshkey.sh
		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-add-dev-sshkey.sh "$PUBKEY"
		rm -f /rootfs/root/inner-add-dev-sshkey.sh
	'

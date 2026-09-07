#!/usr/bin/env bash
# Remove a(s) chave(s) SSH de desenvolvimento adicionadas por
# scripts/02e-add-dev-sshkey.sh. Rodar isso antes de gerar qualquer imagem
# que saia da bancada de testes (a "Server" definitiva, ou antes de migrar
# pra Fase 2 / Desktop). Ver docs/pesquisa.md §4.9.
#
# Uso: scripts/02f-remove-dev-sshkey.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
AUTHKEYS="$ROOTFS/home/radxa/.ssh/authorized_keys"

if [ -f "$AUTHKEYS" ]; then
	docker run --rm -v "$ROOTFS":/rootfs ubuntu:24.04 bash -c "rm -f /rootfs/home/radxa/.ssh/authorized_keys"
	echo ">>> Chave(s) de desenvolvimento removida(s) de $AUTHKEYS"
else
	echo ">>> Nenhuma chave de desenvolvimento encontrada (nada a fazer)."
fi

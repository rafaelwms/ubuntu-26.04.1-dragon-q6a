#!/usr/bin/env bash
# Zera /etc/machine-id no rootfs. Descobrimos que o pacote `systemd`
# gera um machine-id de verdade durante o `apt-get install` dentro do
# chroot (systemd-machine-id-setup roda no postinst) -- isso significa
# que TODO aparelho gravado com a mesma imagem estava saindo com o MESMO
# machine-id (afeta D-Bus, journal, e é usado como "impressão digital" do
# aparelho por vário software). Ver docs/pesquisa.md.
#
# Convenção padrão do systemd pra imagens-molde: deixar /etc/machine-id
# vazio (0 bytes, não ausente) -- o systemd detecta isso e gera um ID
# novo e único no primeiro boot de cada aparelho.
#
# ⚠️ Rodar isso por ÚLTIMO, o mais perto possível de scripts/03-assemble-image.sh
# -- qualquer `apt install`/chroot depois disso pode regenerar o ID.
#
# Uso: scripts/08-clear-machine-id.sh [ROOTFS=output/rootfs por padrão]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${ROOTFS:-$PROJECT_DIR/output/rootfs}"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS" >&2; exit 1; }

echo ">>> machine-id antes: $(cat "$ROOTFS/etc/machine-id" 2>/dev/null || echo '(ausente)')"

docker run --rm -v "$ROOTFS":/rootfs ubuntu:24.04 bash -c ': > /rootfs/etc/machine-id'

echo ">>> machine-id depois: '$(cat "$ROOTFS/etc/machine-id")' (tamanho: $(stat -c%s "$ROOTFS/etc/machine-id"))"

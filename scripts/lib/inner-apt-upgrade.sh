#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# apt update && apt upgrade -- pra trazer o sistema pro ponto de release
# mais recente (26.04.1) como baseline da imagem, em vez de deixar isso
# só pro usuário rodar depois. Ver docs/pesquisa.md §5.1.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get autoremove -y

echo "=== versão final ==="
cat /etc/os-release

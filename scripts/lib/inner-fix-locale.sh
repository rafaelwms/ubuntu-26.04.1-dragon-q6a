#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Gera e configura en_US.UTF-8 como locale padrão. Sem isso, o sistema
# ficava sem NENHUM locale gerado (nem C.UTF-8 de verdade) -- o "inglês"
# que aparecia era só o fallback cru do locale C/POSIX, não um en_US.UTF-8
# de verdade (formatação de data/número/etc. ficava errada). Ver
# docs/pesquisa.md.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get install -y locales

sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
grep -qxF 'en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en

echo "=== /etc/default/locale ==="
cat /etc/default/locale
echo "=== locale -a ==="
locale -a

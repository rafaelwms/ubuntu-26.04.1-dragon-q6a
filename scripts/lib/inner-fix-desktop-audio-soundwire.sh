#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Corrige o bug de áudio do Desktop (ver docs/pesquisa.md §6.1): os módulos
# do caminho SoundWire/WCD938x (clocks LPASS, macros do codec, controlador
# SoundWire da Qualcomm e o próprio codec WCD938x) nunca são carregados
# sozinhos no boot com o Desktop ativo -- por isso o card ALSA nunca chega
# a se registrar (`platform sound: deferred probe pending: snd-sc8280xp:
# WCD Playback: codec dai not found`, e mais fundo,
# `qcom-soundwire: unable to get iface clock`).
#
# Causa raiz confirmada ao vivo: não é um bug de corrida do kernel (como
# suspeitávamos antes) -- é só falta de autoload desses módulos nessa
# combinação específica de kernel+initramfs+Desktop. Carregando-os
# explicitamente e na ordem certa via systemd-modules-load.service, o
# deferred-probe do kernel resolve o resto sozinho e o codec enumera
# normalmente.
set -euxo pipefail

cat > /etc/modules-load.d/dragon-q6a-audio.conf <<'EOF'
# Módulos de áudio do Radxa Dragon Q6A (QCS6490) que não são carregados
# automaticamente no boot via udev/modalias quando o Desktop está ativo.
# Sem eles, o card ALSA (snd-sc8280xp) nunca termina de sondar porque o
# codec WCD938x (via SoundWire) não é encontrado. Ver docs/pesquisa.md §6.1.
lpasscorecc-sc7280
lpasscc-sc7280
snd-soc-lpass-macro-common
snd-soc-lpass-rx-macro
snd-soc-lpass-tx-macro
snd-soc-lpass-wsa-macro
snd-soc-lpass-va-macro
soundwire-qcom
snd-soc-wcd-common
snd-soc-wcd-classh
snd-soc-wcd-mbhc
snd-soc-wcd938x
snd-soc-wcd938x-sdw
EOF

echo "=== /etc/modules-load.d/dragon-q6a-audio.conf ==="
cat /etc/modules-load.d/dragon-q6a-audio.conf

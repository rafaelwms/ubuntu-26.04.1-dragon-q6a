#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala o runtime necessário pra usar a NPU/Hexagon DSP (QCS6490, "Hexagon
# v68") da Q6A a partir dos .deb já baixados em /root/pkgs pelo script
# externo (scripts/02i-install-npu-runtime.sh): o transporte FastRPC
# userspace (kernel-side já é mainline, isso aqui é só a parte de cima) +
# o firmware que roda de fato no DSP.
#
# Confirmado ao vivo, no hardware real: com isso instalado, o
# qnn-platform-validator do QAIRT SDK passa no teste do backend DSP, e um
# modelo de verdade (Llama 3.2 1B, QAIRT SDK 2.42.0.251225) roda inferência
# real na NPU via `genie-t2t-run`. Ver docs/pesquisa.md §10.
#
# O que isso NÃO inclui (de propósito): o QAIRT SDK em si (~2GB, baixado à
# parte de https://softwarecenter.qualcomm.com, conta gratuita necessária --
# são as ferramentas de desenvolvimento/conversão de modelo, não faz sentido
# embutir isso na imagem, do mesmo jeito que não embutimos o Android NDK
# num telefone). O que instalamos aqui é só a base pra NPU funcionar: depois
# de pronta, qualquer app QNN/Genie compilado em outro lugar já roda.
set -euxo pipefail

dpkg -i /root/pkgs/*.deb || true
apt-get -f install -y
rm -rf /root/pkgs

# /usr/lib/dsp -> /usr/share/qcom/qcs6490/radxa/dragon-q6a/dsp é criado pelo
# próprio setup-dsp.sh do pacote fastrpc (hook do postinst, reconhece a
# placa pelo nome "Radxa Dragon Q6A" em /sys/firmware/devicetree/base/model)
# -- mas isso só roda de verdade lendo o devicetree real, que não existe
# dentro do chroot de build. Criamos o link aqui manualmente já apontando
# pro caminho certo pra essa placa; o hook do systemd confirma de novo
# (idempotente) no primeiro boot.
ln -sfn /usr/share/qcom/qcs6490/radxa/dragon-q6a/dsp /usr/lib/dsp

# Usuário padrão no grupo "fastrpc" -- é assim que o pacote fastrpc
# controla acesso aos /dev/fastrpc-* (regra udev própria, grupo+0640, em vez
# de abrir 0666 pra todo mundo). O pacote `fastrpc` da Qualcomm NÃO cria
# esse grupo sozinho (quem cria é o `hexagonrpcd`, via `adduser --system
# --group fastrpc` no postinst dele -- e não instalamos esse pacote de
# propósito, é o daemon concorrente). Criamos o grupo do sistema aqui,
# caso ainda não exista.
getent group fastrpc >/dev/null || groupadd --system fastrpc
usermod -aG fastrpc radxa

echo "=== NPU runtime instalado ==="
echo "--- /usr/lib/dsp ---"
ls -la /usr/lib/dsp/cdsp/ 2>&1 | head -5
echo "--- libcdsprpc.so ---"
ls -la /usr/lib/aarch64-linux-gnu/libcdsprpc.so* 2>&1
echo "--- grupo fastrpc ---"
getent group fastrpc

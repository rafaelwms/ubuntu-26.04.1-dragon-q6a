#!/usr/bin/env bash
# Instala o runtime da NPU/Hexagon DSP (QCS6490, "Hexagon v68") -- o
# transporte FastRPC userspace (libcdsprpc.so + daemons) e o firmware que
# roda de fato no DSP (fastrpc_shell, libs de NN/visão).
#
# Confirmado ao vivo, no hardware real: com isso instalado, o
# qnn-platform-validator do QAIRT SDK (baixado à parte, ver
# docs/pesquisa.md §10) passa no teste do backend DSP, e um modelo real
# (Llama 3.2 1B) roda inferência de verdade na NPU via `genie-t2t-run`.
#
# Todos os pacotes são open source (fastrpc é um repackage de
# github.com/quic/fastrpc, publicado pela própria Qualcomm como BSD) ou
# firmware redistribuível, empacotados pela Radxa em radxa-pkg/* no GitHub.
#
# Uso: scripts/02i-install-npu-runtime.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/output/rootfs"
SCRIPTS_LIB="$PROJECT_DIR/scripts/lib"
CACHE="$PROJECT_DIR/artifacts/npu-runtime"

[ -d "$ROOTFS/etc" ] || { echo "Rootfs não encontrado em $ROOTFS — rode 01 e 02 antes." >&2; exit 1; }

mkdir -p "$CACHE"

echo ">>> Descobrindo as últimas versões dos pacotes (radxa-pkg)..."
FASTRPC_VERSION="$(curl -s https://api.github.com/repos/radxa-pkg/fastrpc/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')"
AUDIOREACH_VERSION="$(curl -s https://api.github.com/repos/radxa-pkg/audioreach-topology/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')"
RADXA_FW_VERSION="$(curl -s https://api.github.com/repos/radxa-pkg/radxa-firmware/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')"
[ -n "$FASTRPC_VERSION" ] || { echo "Não consegui descobrir a última versão do fastrpc." >&2; exit 1; }
[ -n "$AUDIOREACH_VERSION" ] || { echo "Não consegui descobrir a última versão do audioreach-topology." >&2; exit 1; }
[ -n "$RADXA_FW_VERSION" ] || { echo "Não consegui descobrir a última versão do radxa-firmware." >&2; exit 1; }
echo "fastrpc: $FASTRPC_VERSION / audioreach-topology: $AUDIOREACH_VERSION / radxa-firmware: $RADXA_FW_VERSION"

echo ">>> Baixando pacotes (cache em $CACHE)..."
declare -A URLS=(
	["fastrpc_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/fastrpc_${FASTRPC_VERSION}_arm64.deb"
	["fastrpc-dev_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/fastrpc-dev_${FASTRPC_VERSION}_arm64.deb"
	["libcdsprpc1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libcdsprpc1_${FASTRPC_VERSION}_arm64.deb"
	["libadsprpc1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libadsprpc1_${FASTRPC_VERSION}_arm64.deb"
	["libsdsprpc1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libsdsprpc1_${FASTRPC_VERSION}_arm64.deb"
	["libcdsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libcdsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"
	["libadsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libadsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"
	["libsdsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"]="https://github.com/radxa-pkg/fastrpc/releases/download/${FASTRPC_VERSION}/libsdsp-default-listener1_${FASTRPC_VERSION}_arm64.deb"
	["firmware-qcom-audioreach_${AUDIOREACH_VERSION}_all.deb"]="https://github.com/radxa-pkg/audioreach-topology/releases/download/${AUDIOREACH_VERSION}/firmware-qcom-audioreach_${AUDIOREACH_VERSION}_all.deb"
	["radxa-firmware-qcs6490_${RADXA_FW_VERSION}_all.deb"]="https://github.com/radxa-pkg/radxa-firmware/releases/download/${RADXA_FW_VERSION}/radxa-firmware-qcs6490_${RADXA_FW_VERSION}_all.deb"
)
for f in "${!URLS[@]}"; do
	if [ ! -f "$CACHE/$f" ]; then
		curl -sL -o "$CACHE/$f.tmp" "${URLS[$f]}"
		mv "$CACHE/$f.tmp" "$CACHE/$f"
	fi
done

echo ">>> Instalando dentro do rootfs (chroot arm64)..."
docker run --rm --privileged \
	-v "$ROOTFS":/rootfs \
	-v "$CACHE":/npu-debs:ro \
	-v "$SCRIPTS_LIB":/scripts-lib:ro \
	ubuntu:24.04 bash -eux -c '
		mount -t proc proc /rootfs/proc
		mount --rbind /sys /rootfs/sys
		mount --rbind /dev /rootfs/dev
		trap "umount -R /rootfs/dev; umount -R /rootfs/sys; umount /rootfs/proc" EXIT

		mkdir -p /rootfs/root/pkgs
		cp /npu-debs/*.deb /rootfs/root/pkgs/
		cp /scripts-lib/inner-install-npu-runtime.sh /rootfs/root/inner-install-npu-runtime.sh
		cp /scripts-lib/61-fastrpc-uaccess.rules /rootfs/root/61-fastrpc-uaccess.rules
		chmod +x /rootfs/root/inner-install-npu-runtime.sh

		chroot /rootfs /usr/bin/qemu-aarch64-static /bin/bash /root/inner-install-npu-runtime.sh
		rm -f /rootfs/root/inner-install-npu-runtime.sh /rootfs/root/61-fastrpc-uaccess.rules
	'

echo ">>> Pronto."

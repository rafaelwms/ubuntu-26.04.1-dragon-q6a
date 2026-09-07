#!/usr/bin/env bash
# Gera o rootfs base do Ubuntu 26.04 "resolute" arm64 via debootstrap,
# rodando dentro de um container Docker (root do container, sem precisar
# de sudo no host) já que este host não tem sudo sem senha configurado.
#
# Uso: scripts/01-build-rootfs.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJECT_DIR/output"
SUITE="resolute"
ARCH="arm64"
MIRROR="http://ports.ubuntu.com/ubuntu-ports/"

mkdir -p "$OUT"

echo ">>> Rodando debootstrap (${SUITE}/${ARCH}) dentro de container Docker..."

docker run --rm --privileged \
	-v "$OUT":/output \
	ubuntu:24.04 bash -eux -c "
		apt-get update -qq
		apt-get install -y -qq debootstrap qemu-user-static ca-certificates >/dev/null

		# O debootstrap que vem nos repos do 24.04 ainda não conhece o nome 'resolute'
		# (26.04). No Ubuntu 26.04 real esse arquivo já é um symlink para 'gutsy' --
		# replicamos isso aqui em vez de depender de uma versão de pacote mais nova.
		if [ ! -e /usr/share/debootstrap/scripts/${SUITE} ]; then
			ln -s gutsy /usr/share/debootstrap/scripts/${SUITE}
		fi

		rm -rf /output/rootfs
		debootstrap --arch=${ARCH} --foreign ${SUITE} /output/rootfs ${MIRROR}
		cp /usr/bin/qemu-aarch64-static /output/rootfs/usr/bin/
		chroot /output/rootfs /debootstrap/debootstrap --second-stage
	"

echo ">>> Rootfs gerado em ${OUT}/rootfs"

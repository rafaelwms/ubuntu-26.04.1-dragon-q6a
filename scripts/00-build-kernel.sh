#!/usr/bin/env bash
# Compila o kernel 6.18.2 (branch "current" do Armbian, validado pra essa
# placa -- ver docs/pesquisa.md §4.7/§4.11) usando o Armbian Build
# Framework, e copia os .deb resultantes pra artifacts/kernel-current-qcs6490/.
#
# Só usamos o `./compile.sh kernel` do Armbian (não o build de imagem
# completo dele) -- clona o framework numa pasta local (armbian-build/,
# ignorada pelo git) se ainda não existir, e usa o cache remoto deles
# (ghcr.io/armbian/os/kernel-qcs6490-current), então geralmente termina em
# ~1 minuto em vez de compilar o kernel do zero.
#
# Idempotente: se os .deb já existirem em artifacts/kernel-current-qcs6490/,
# não faz nada.
#
# Uso: scripts/00-build-kernel.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARMBIAN_DIR="$PROJECT_DIR/armbian-build"
OUT_DIR="$PROJECT_DIR/artifacts/kernel-current-qcs6490"

if compgen -G "$OUT_DIR"/linux-image-current-qcs6490_*.deb >/dev/null 2>&1; then
	echo ">>> Kernel já compilado em $OUT_DIR -- nada a fazer."
	exit 0
fi

if [ ! -d "$ARMBIAN_DIR" ]; then
	echo ">>> Clonando armbian/build (rasa, só o necessário)..."
	git clone --depth=1 https://github.com/armbian/build.git "$ARMBIAN_DIR"
fi

echo ">>> Compilando kernel (BOARD=radxa-dragon-q6a BRANCH=current)..."
(
	cd "$ARMBIAN_DIR"
	./compile.sh kernel BOARD=radxa-dragon-q6a BRANCH=current
)

mkdir -p "$OUT_DIR"
FOUND=0
while IFS= read -r -d '' deb; do
	cp "$deb" "$OUT_DIR"/
	FOUND=1
done < <(find "$ARMBIAN_DIR/output" -iname '*-current-qcs6490_*.deb' -print0)

[ "$FOUND" -eq 1 ] || { echo "ERRO: build terminou mas não achei os .deb em $ARMBIAN_DIR/output" >&2; exit 1; }

echo ">>> Pronto:"
ls -la "$OUT_DIR"

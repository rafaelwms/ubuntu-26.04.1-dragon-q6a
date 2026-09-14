#!/usr/bin/env bash
# Orquestrador interativo (EN/PT-BR) da "saga" inteira: constrói a imagem
# Ubuntu 26.04.1 "Resolute Raccoon" pra Radxa Dragon Q6A do zero -- sem
# depender de baixar as imagens prontas da Release -- encadeando os
# scripts numerados na ordem certa. Veja docs/pesquisa.md pra entender
# o "porquê" de cada passo.
#
# Interactive orchestrator (EN/PT-BR) for the whole "saga": builds the
# Ubuntu 26.04.1 "Resolute Raccoon" image for the Radxa Dragon Q6A from
# scratch -- no need to download the pre-built Release images -- chaining
# the numbered scripts in the right order. See docs/pesquisa.md for the
# "why" behind each step.
#
# Requisitos / Requirements: docker, git, ~15GB de espaço livre / free disk space.
#
# Uso / Usage: ./scripts/build.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

LANG_CHOICE=""

msg_en() {
	case "$1" in
	banner) cat <<'EOF'
==============================================================
 Radxa Dragon Q6A -- Ubuntu 26.04.1 LTS "Resolute Raccoon"
 Build-from-source orchestrator
==============================================================
EOF
		;;
	ask_image) echo "Which image do you want to build?" ;;
	opt_server) echo "1) Server (no GUI, prompt only)" ;;
	opt_desktop) echo "2) Desktop (GNOME, minimal -- includes Server as its base)" ;;
	need_docker) echo "ERROR: docker is required and was not found. Install Docker first." ;;
	step) echo ">>> Step" ;;
	building) echo ">>> Building..." ;;
	done_msg) echo ">>> All done." ;;
	image_at) echo "Image:" ;;
	checksum) echo "SHA256:" ;;
	next_steps) cat <<'EOF'

Next steps:
  - To flash it, run ./install.sh and choose "I already downloaded them",
    pointing it at the output/ folder (it also works with a single,
    un-split .img.xz -- verification just gets skipped if the
    SHA256SUMS files aren't there).
  - Or flash it directly yourself:
      xzcat output/<the .img.xz above> | sudo dd of=/dev/YOUR_DEVICE bs=4M status=progress conv=fsync
    Triple-check the device with `lsblk` first -- this erases it completely.
EOF
		;;
	goodbye) echo "Bye!" ;;
	esac
}

msg_pt() {
	case "$1" in
	banner) cat <<'EOF'
==============================================================
 Radxa Dragon Q6A -- Ubuntu 26.04.1 LTS "Resolute Raccoon"
 Orquestrador de build a partir do código-fonte
==============================================================
EOF
		;;
	ask_image) echo "Qual imagem você quer construir?" ;;
	opt_server) echo "1) Server (sem interface gráfica, só prompt)" ;;
	opt_desktop) echo "2) Desktop (GNOME, mínimo -- inclui o Server como base)" ;;
	need_docker) echo "ERRO: docker é necessário e não foi encontrado. Instale o Docker antes." ;;
	step) echo ">>> Passo" ;;
	building) echo ">>> Construindo..." ;;
	done_msg) echo ">>> Tudo pronto." ;;
	image_at) echo "Imagem:" ;;
	checksum) echo "SHA256:" ;;
	next_steps) cat <<'EOF'

Próximos passos:
  - Pra gravar, rode ./install.sh e escolha "já baixei", apontando pra
    pasta output/ (funciona também com um único .img.xz não dividido --
    a verificação só é pulada se os arquivos SHA256SUMS não estiverem lá).
  - Ou grave direto você mesmo:
      xzcat output/<a .img.xz acima> | sudo dd of=/dev/SEU_DISPOSITIVO bs=4M status=progress conv=fsync
    Confira bem o dispositivo com `lsblk` antes -- isso apaga tudo nele.
EOF
		;;
	goodbye) echo "Até mais!" ;;
	esac
}

msg() {
	if [ "$LANG_CHOICE" = "pt" ]; then msg_pt "$1"; else msg_en "$1"; fi
}

command -v docker >/dev/null 2>&1 || {
	echo "$(msg need_docker)" >&2
	exit 1
}

if [ -n "${LANG:-}" ] && [[ "$LANG" == pt* ]]; then LANG_CHOICE="pt"; else LANG_CHOICE="en"; fi
echo "Choose language / Escolha o idioma:"
echo "  1) English"
echo "  2) Português"
read -rp "> " lang_pick
case "$lang_pick" in
2 | pt | PT) LANG_CHOICE="pt" ;;
*) LANG_CHOICE="en" ;;
esac

clear 2>/dev/null || true
msg banner
echo

msg ask_image
msg opt_server
msg opt_desktop
read -rp "> " image_pick
case "$image_pick" in
2) IMAGE_TYPE="desktop" ;;
*) IMAGE_TYPE="server" ;;
esac

run_step() {
	echo
	echo "$(msg step): $*"
	"$@"
}

run_step ./scripts/00-build-kernel.sh
run_step ./scripts/01-build-rootfs.sh
run_step ./scripts/02-install-kernel-firmware.sh
run_step ./scripts/02b-configure-system.sh
run_step ./scripts/02c-install-wifi-audio-tools.sh
run_step ./scripts/02d-fix-initramfs-firmware.sh
run_step ./scripts/02i-install-npu-runtime.sh
run_step ./scripts/02g-firstboot-resize.sh
run_step ./scripts/02h-cleanup-build-tools.sh

if [ "$IMAGE_TYPE" = "desktop" ]; then
	run_step ./scripts/04-install-desktop.sh
	run_step ./scripts/07a-fix-desktop-hostname.sh
	run_step ./scripts/07b-install-firefox.sh
	run_step ./scripts/07c-install-gnome-software.sh
	run_step ./scripts/07d-fix-desktop-audio-soundwire.sh
fi

run_step ./scripts/06a-fix-locale.sh
run_step ./scripts/06b-install-bootentry-dedupe.sh
run_step ./scripts/06c-apt-upgrade.sh
run_step ./scripts/08-clear-machine-id.sh

IMG_NAME="radxa-dragon-q6a_resolute_${IMAGE_TYPE}.img"
run_step ./scripts/03-assemble-image.sh "$IMG_NAME" 8G

echo
msg done_msg
echo "$(msg image_at) output/${IMG_NAME}.xz"
echo "$(msg checksum) $(sha256sum "output/${IMG_NAME}.xz" | cut -d' ' -f1)"
msg next_steps
echo
msg goodbye

#!/usr/bin/env bash
# Instalador interativo (EN/PT-BR) das imagens Ubuntu 26.04 "Resolute
# Raccoon" para a Radxa Dragon Q6A -- versão para macOS.
#
# Baixa (ou usa arquivos já baixados) as partes da release no GitHub,
# confere os checksums SHA256, reconstrói o .img.xz, e grava no
# dispositivo de destino que você escolher -- com confirmação explícita
# antes de qualquer escrita.
#
# Diferenças em relação ao install.sh (Linux):
#   - `diskutil` no lugar de `lsblk`/`findmnt` (macOS não tem essas ferramentas)
#   - `shasum -a 256` no lugar de `sha256sum` (não vem instalado por padrão)
#   - grava no disco "raw" (/dev/rdiskN), bem mais rápido que /dev/diskN no macOS
#   - roda `diskutil unmountDisk` antes de gravar (obrigatório no macOS --
#     gravar num disco ainda montado falha ou corrompe)
#   - sem `mapfile`/`grep -P`: o /bin/bash do macOS é antigo (3.2) e o
#     grep é o BSD (sem suporte a regex Perl), então evitamos os dois
#
# Interactive installer (EN/PT-BR) for the Ubuntu 26.04 "Resolute
# Raccoon" images for the Radxa Dragon Q6A -- macOS version.
#
# Downloads (or uses already-downloaded files) the release parts from
# GitHub, verifies SHA256 checksums, reassembles the .img.xz, and
# flashes the target device you choose -- with an explicit confirmation
# before any write.
#
# Differences from install.sh (Linux):
#   - `diskutil` instead of `lsblk`/`findmnt` (not available on macOS)
#   - `shasum -a 256` instead of `sha256sum` (not installed by default)
#   - flashes the "raw" disk (/dev/rdiskN), much faster than /dev/diskN on macOS
#   - runs `diskutil unmountDisk` before flashing (required on macOS --
#     writing to a still-mounted disk fails or corrupts it)
#   - no `mapfile`/`grep -P`: macOS ships an old /bin/bash (3.2) and BSD
#     grep (no Perl-regex support), so both are avoided
#
# Uso / Usage: ./install_mac.sh
set -euo pipefail

# ------------------------------------------------------------------
# Troque isto pelo repositório real assim que ele existir no GitHub.
# Replace this with the real GitHub repository once it exists.
# ------------------------------------------------------------------
REPO_SLUG="rafaelwms/ubuntu-26.04.1-dragon-q6a"

LANG_CHOICE=""

# ------------------------------------------------------------------
# Mensagens / Messages
# ------------------------------------------------------------------
msg_en() {
	case "$1" in
	banner) cat <<'EOF'
==============================================================
 Radxa Dragon Q6A -- Ubuntu 26.04.1 LTS "Resolute Raccoon"
 Interactive installer (macOS)
==============================================================
EOF
		;;
	ask_lang) echo "Choose language / Escolha o idioma:" ;;
	ask_image) echo "Which image do you want to install?" ;;
	opt_server) echo "1) Server (no GUI, prompt only)" ;;
	opt_desktop) echo "2) Desktop (GNOME, minimal)" ;;
	ask_source) echo "Where are the release files?" ;;
	opt_download) echo "1) Download them now from the latest GitHub release" ;;
	opt_local) echo "2) I already downloaded them -- point me to the folder" ;;
	ask_local_dir) echo "Path to the folder with the .part* and SHA256SUMS* files:" ;;
	dir_not_found) echo "ERROR: folder not found." ;;
	fetching_release) echo ">>> Fetching latest release info from GitHub..." ;;
	release_error) echo "ERROR: couldn't fetch release info. Check your connection or REPO_SLUG at the top of this script." ;;
	no_assets) echo "ERROR: no matching files found in the latest release for that image." ;;
	downloading) echo ">>> Downloading release files..." ;;
	verifying_parts) echo ">>> Verifying downloaded parts (SHA256)..." ;;
	parts_ok) echo ">>> All parts verified OK." ;;
	parts_missing_sums) echo "WARNING: SHA256SUMS-parts.txt not found -- skipping per-part verification." ;;
	parts_fail) echo "ERROR: checksum mismatch on one or more parts. Re-download and try again." ;;
	reassembling) echo ">>> Reassembling the image from parts..." ;;
	verifying_full) echo ">>> Verifying the reassembled image (SHA256)..." ;;
	full_ok) echo ">>> Image verified OK -- matches the published checksum." ;;
	full_missing_sums) echo "WARNING: SHA256SUMS-full.txt not found -- skipping full-image verification." ;;
	full_fail) echo "ERROR: the reassembled image does NOT match the published checksum. Do not flash this file -- delete it and try again." ;;
	listing_devices) echo ">>> Disks currently attached (diskutil list):" ;;
	root_disk_warning) echo "   (^ this is your Mac's own startup disk -- DO NOT pick this one)" ;;
	ask_device) echo "Type the disk identifier to flash (e.g. disk4) or full path (/dev/disk4):" ;;
	device_not_found) echo "ERROR: device not found (check with 'diskutil list')." ;;
	device_is_root_disk) echo "REFUSING: that is the disk macOS is running from. Aborting." ;;
	confirm_header) echo "About to ERASE EVERYTHING on this device:" ;;
	confirm_prompt) echo "Type FLASH (all caps) to confirm, or anything else to cancel:" ;;
	cancelled) echo "Cancelled. Nothing was written." ;;
	unmounting) echo ">>> Unmounting the disk (required on macOS before writing)..." ;;
	unmount_fail) echo "ERROR: could not unmount the disk. Close any Finder window/app using it and try again." ;;
	need_sudo) echo ">>> Writing to the device requires root -- you may be asked for your password." ;;
	flashing) echo ">>> Flashing... this can take a few minutes, do not disconnect the device." ;;
	flashing_progress_hint) echo "    (no 'pv' installed -- no progress bar. Press Ctrl+T at any time to see dd's progress.)" ;;
	flash_done) echo ">>> Done! Wait for this message before disconnecting the device." ;;
	ejecting) echo ">>> Ejecting the disk..." ;;
	next_steps) cat <<'EOF'

Next steps:
  1. Move the device to the Radxa Dragon Q6A and boot it.
  2. Default login: user "radxa", password "radxa" -- change it on first
     login with `passwd`.
  3. The root partition grows automatically to fill the whole disk on
     first boot -- no manual resizing needed.
EOF
		;;
	missing_dep) echo "ERROR: required command not found:" ;;
	missing_dep_xz) echo "ERROR: 'xz' not found. Install it with Homebrew: brew install xz" ;;
	goodbye) echo "Bye!" ;;
	esac
}

msg_pt() {
	case "$1" in
	banner) cat <<'EOF'
==============================================================
 Radxa Dragon Q6A -- Ubuntu 26.04.1 LTS "Resolute Raccoon"
 Instalador interativo (macOS)
==============================================================
EOF
		;;
	ask_lang) echo "Choose language / Escolha o idioma:" ;;
	ask_image) echo "Qual imagem você quer instalar?" ;;
	opt_server) echo "1) Server (sem interface gráfica, só prompt)" ;;
	opt_desktop) echo "2) Desktop (GNOME, mínimo)" ;;
	ask_source) echo "Onde estão os arquivos da release?" ;;
	opt_download) echo "1) Baixar agora da última release do GitHub" ;;
	opt_local) echo "2) Já baixei -- me diga a pasta" ;;
	ask_local_dir) echo "Caminho da pasta com os arquivos .part* e SHA256SUMS*:" ;;
	dir_not_found) echo "ERRO: pasta não encontrada." ;;
	fetching_release) echo ">>> Consultando a última release no GitHub..." ;;
	release_error) echo "ERRO: não consegui consultar a release. Confira sua conexão ou o REPO_SLUG no topo deste script." ;;
	no_assets) echo "ERRO: não achei arquivos correspondentes na última release pra essa imagem." ;;
	downloading) echo ">>> Baixando os arquivos da release..." ;;
	verifying_parts) echo ">>> Verificando as partes baixadas (SHA256)..." ;;
	parts_ok) echo ">>> Todas as partes verificadas com sucesso." ;;
	parts_missing_sums) echo "AVISO: SHA256SUMS-parts.txt não encontrado -- pulando verificação das partes." ;;
	parts_fail) echo "ERRO: checksum não bate em uma ou mais partes. Baixe de novo e tente outra vez." ;;
	reassembling) echo ">>> Reconstruindo a imagem a partir das partes..." ;;
	verifying_full) echo ">>> Verificando a imagem reconstruída (SHA256)..." ;;
	full_ok) echo ">>> Imagem verificada com sucesso -- bate com o checksum publicado." ;;
	full_missing_sums) echo "AVISO: SHA256SUMS-full.txt não encontrado -- pulando verificação da imagem completa." ;;
	full_fail) echo "ERRO: a imagem reconstruída NÃO bate com o checksum publicado. Não grave esse arquivo -- apague e tente de novo." ;;
	listing_devices) echo ">>> Discos conectados agora (diskutil list):" ;;
	root_disk_warning) echo "   (^ esse é o disco de inicialização do seu Mac -- NÃO escolha esse)" ;;
	ask_device) echo "Digite o identificador do disco pra gravar (ex.: disk4) ou o caminho completo (/dev/disk4):" ;;
	device_not_found) echo "ERRO: dispositivo não encontrado (confira com 'diskutil list')." ;;
	device_is_root_disk) echo "RECUSANDO: esse é o disco de onde o macOS está rodando. Abortando." ;;
	confirm_header) echo "Isso vai APAGAR TUDO neste dispositivo:" ;;
	confirm_prompt) echo "Digite GRAVAR (maiúsculas) pra confirmar, ou qualquer outra coisa pra cancelar:" ;;
	cancelled) echo "Cancelado. Nada foi gravado." ;;
	unmounting) echo ">>> Desmontando o disco (obrigatório no macOS antes de gravar)..." ;;
	unmount_fail) echo "ERRO: não consegui desmontar o disco. Feche qualquer janela do Finder/app usando ele e tente de novo." ;;
	need_sudo) echo ">>> Gravar no dispositivo exige root -- pode ser que sua senha seja pedida." ;;
	flashing) echo ">>> Gravando... pode levar alguns minutos, não desconecte o dispositivo." ;;
	flashing_progress_hint) echo "    (sem 'pv' instalado -- sem barra de progresso. Pressione Ctrl+T a qualquer momento pra ver o andamento do dd.)" ;;
	flash_done) echo ">>> Pronto! Espere esta mensagem antes de desconectar o dispositivo." ;;
	ejecting) echo ">>> Ejetando o disco..." ;;
	next_steps) cat <<'EOF'

Próximos passos:
  1. Leve o dispositivo pra Radxa Dragon Q6A e ligue.
  2. Login padrão: usuário "radxa", senha "radxa" -- troque no primeiro
     acesso com `passwd`.
  3. A partição raiz cresce sozinha pra ocupar o disco todo no primeiro
     boot -- não precisa redimensionar na mão.
EOF
		;;
	missing_dep) echo "ERRO: comando necessário não encontrado:" ;;
	missing_dep_xz) echo "ERRO: 'xz' não encontrado. Instale com o Homebrew: brew install xz" ;;
	goodbye) echo "Até mais!" ;;
	esac
}

msg() {
	if [ "$LANG_CHOICE" = "pt" ]; then msg_pt "$1"; else msg_en "$1"; fi
}

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$(msg missing_dep) $1" >&2
		exit 1
	}
}

if [ "$(uname -s)" != "Darwin" ]; then
	echo "This script is for macOS only -- use ./install.sh on Linux." >&2
	echo "Este script é só pra macOS -- use ./install.sh no Linux." >&2
	exit 1
fi

for c in curl shasum xz diskutil dd; do need "$c"; done
command -v xzcat >/dev/null 2>&1 || {
	echo "$(msg missing_dep_xz)" >&2
	exit 1
}

# sha256sum -c --ignore-missing não existe no `shasum` do macOS -- filtramos
# manualmente as linhas do arquivo de somas pros arquivos que existem aqui.
# `sha256sum -c --ignore-missing` doesn't exist in macOS's `shasum` -- we
# manually filter the sums file down to lines for files that exist here.
sha256_check_ignore_missing() {
	sums_file="$1"
	filtered="$(mktemp)"
	while IFS= read -r line; do
		fname="$(echo "$line" | awk '{print $2}')"
		[ -n "$fname" ] && [ -f "$fname" ] && echo "$line" >>"$filtered"
	done <"$sums_file"
	if [ ! -s "$filtered" ]; then
		rm -f "$filtered"
		return 0
	fi
	shasum -a 256 -c "$filtered"
	status=$?
	rm -f "$filtered"
	return $status
}

# ------------------------------------------------------------------
# Idioma / Language
# ------------------------------------------------------------------
if [ -n "${LANG:-}" ] && [[ "$LANG" == pt* ]]; then
	LANG_CHOICE="pt"
else
	LANG_CHOICE="en"
fi

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

# ------------------------------------------------------------------
# Escolha da imagem / Image choice
# ------------------------------------------------------------------
msg ask_image
msg opt_server
msg opt_desktop
read -rp "> " image_pick
case "$image_pick" in
2) IMAGE_TYPE="desktop" ;;
*) IMAGE_TYPE="server" ;;
esac

# ------------------------------------------------------------------
# Origem dos arquivos / Where the files come from
# ------------------------------------------------------------------
echo
msg ask_source
msg opt_download
msg opt_local
read -rp "> " source_pick

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [ "$source_pick" = "2" ]; then
	msg ask_local_dir
	read -rp "> " local_dir
	[ -d "$local_dir" ] || {
		echo "$(msg dir_not_found)" >&2
		exit 1
	}
	cp "$local_dir"/*"${IMAGE_TYPE}"* "$WORKDIR"/ 2>/dev/null || true
	cp "$local_dir"/SHA256SUMS-*.txt "$WORKDIR"/ 2>/dev/null || true
else
	msg fetching_release
	RELEASE_JSON="$(curl -sL "https://api.github.com/repos/${REPO_SLUG}/releases/latest")" || {
		echo "$(msg release_error)" >&2
		exit 1
	}
	# Sem mapfile (bash 3.2 do macOS não tem) e sem grep -P (grep BSD não
	# suporta regex Perl) -- extraímos as URLs com grep -o + sed -E, que
	# funcionam nos dois.
	URLS=()
	while IFS= read -r url; do
		[ -n "$url" ] && URLS+=("$url")
	done < <(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*"' | sed -E 's/.*"(https[^"]+)"$/\1/' | grep -E "${IMAGE_TYPE}|SHA256SUMS")
	[ "${#URLS[@]}" -gt 0 ] || {
		echo "$(msg no_assets)" >&2
		exit 1
	}
	msg downloading
	for url in "${URLS[@]}"; do
		fname="$(basename "$url")"
		echo "  -> $fname"
		curl -sL -o "$WORKDIR/$fname" "$url"
	done
fi

cd "$WORKDIR"

# ------------------------------------------------------------------
# Verifica as partes / Verify parts
# ------------------------------------------------------------------
msg verifying_parts
if [ -f SHA256SUMS-parts.txt ]; then
	if sha256_check_ignore_missing SHA256SUMS-parts.txt; then
		msg parts_ok
	else
		echo "$(msg parts_fail)" >&2
		exit 1
	fi
else
	msg parts_missing_sums
fi

# ------------------------------------------------------------------
# Reconstrói a imagem / Reassemble the image
#
# Aceita tanto uma release dividida em partes (.img.xz.part*, como as
# publicadas no GitHub) quanto um .img.xz único e completo (como o que
# scripts/build.sh gera direto em output/).
# Accepts either a split release (.img.xz.part*, as published on
# GitHub) or a single, already-whole .img.xz (like the one
# scripts/build.sh produces directly in output/).
# ------------------------------------------------------------------
msg reassembling
WHOLE_IMG="$(ls -- *"${IMAGE_TYPE}"*.img.xz 2>/dev/null | head -n1 || true)"
if [ -n "$WHOLE_IMG" ]; then
	IMG_XZ="$WHOLE_IMG"
else
	FIRST_PART="$(ls -- *"${IMAGE_TYPE}"*.img.xz.part* 2>/dev/null | sort | head -n1 || true)"
	[ -n "$FIRST_PART" ] || {
		echo "$(msg no_assets)" >&2
		exit 1
	}
	IMG_XZ="${FIRST_PART%.part*}"
	cat -- *"${IMAGE_TYPE}"*.img.xz.part* >"$IMG_XZ"
fi

msg verifying_full
if [ -f SHA256SUMS-full.txt ]; then
	if sha256_check_ignore_missing SHA256SUMS-full.txt; then
		msg full_ok
	else
		echo "$(msg full_fail)" >&2
		exit 1
	fi
else
	msg full_missing_sums
fi

# ------------------------------------------------------------------
# Escolha do dispositivo / Device choice
# ------------------------------------------------------------------
# "Part of Whole" no `diskutil info /` dá o disco inteiro de onde o
# macOS está rodando (ex.: disk3), mesmo se / estiver num APFS
# container/volume -- é esse que precisamos bloquear.
ROOT_DISK_ID="$(diskutil info / 2>/dev/null | awk -F': +' '/Part of Whole/{print $2}' | tr -d ' ')"
ROOT_DISK="/dev/${ROOT_DISK_ID}"

echo
msg listing_devices
diskutil list
if [ -n "$ROOT_DISK_ID" ]; then
	echo "$(msg root_disk_warning) ($ROOT_DISK)"
fi
echo
msg ask_device
read -rp "> " DEVICE_INPUT

# Aceita "disk4", "/dev/disk4" ou "/dev/rdisk4" -- normaliza pros dois
# caminhos que vamos precisar: /dev/diskN (pra diskutil) e /dev/rdiskN
# (pro dd, bem mais rápido no macOS que o device "buffered").
DISK_ID="$(echo "$DEVICE_INPUT" | sed -E 's#^/dev/r?##')"
DEVICE="/dev/${DISK_ID}"
RAW_DEVICE="/dev/r${DISK_ID}"

diskutil info "$DEVICE" >/dev/null 2>&1 || {
	echo "$(msg device_not_found)" >&2
	exit 1
}
if [ "$DEVICE" = "$ROOT_DISK" ]; then
	echo "$(msg device_is_root_disk)" >&2
	exit 1
fi

echo
msg confirm_header
diskutil list "$DEVICE"
echo
msg confirm_prompt
read -rp "> " confirm
if [ "$confirm" != "FLASH" ] && [ "$confirm" != "GRAVAR" ]; then
	msg cancelled
	exit 0
fi

# ------------------------------------------------------------------
# Grava / Flash
# ------------------------------------------------------------------
msg unmounting
diskutil unmountDisk "$DEVICE" || {
	echo "$(msg unmount_fail)" >&2
	exit 1
}

msg need_sudo
msg flashing
if command -v pv >/dev/null 2>&1; then
	IMG_SIZE="$(stat -f%z "$IMG_XZ")"
	xzcat "$IMG_XZ" | pv -s "$IMG_SIZE" | sudo dd of="$RAW_DEVICE" bs=4m
else
	msg flashing_progress_hint
	xzcat "$IMG_XZ" | sudo dd of="$RAW_DEVICE" bs=4m
fi
sync
msg flash_done
msg ejecting
diskutil eject "$DEVICE" 2>/dev/null || true
msg next_steps
echo
msg goodbye

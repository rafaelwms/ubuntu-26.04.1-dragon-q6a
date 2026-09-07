#!/usr/bin/env bash
# Roda DENTRO do container Docker (root do container).
# Monta a imagem final SEM usar nenhum loop device: constrói cada partição
# como um arquivo separado (mtools pras FAT, `mkfs.ext4 -d` pra rootfs) e
# depois "encaixa" cada uma com dd no offset certo dentro da imagem final.
#
# Motivo: neste ambiente, criar nós de dispositivo de partição num loop
# device (via -P + partx/partprobe, ou até um loop device por partição depois
# de mais de duas chamadas) falha de forma inconsistente -- então evitamos
# precisar de loop device por completo.
#
# Variável de ambiente esperada: IMG (caminho da imagem raw, já do tamanho final).
set -euxo pipefail

: "${IMG:?defina IMG=/work/<arquivo>.img}"
WORK=/work/.partbuild
rm -rf "$WORK"
mkdir -p "$WORK"

# --- 1. tabela GPT igual à real (ver docs/pesquisa.md §3.1), direto no arquivo ---
sgdisk --zap-all "$IMG"
sgdisk \
	--new=1:0:+16M   --typecode=1:0fc63daf-8483-4772-8e79-3d69d8477de4 --change-name=1:config \
	--new=2:0:+1024M --typecode=2:c12a7328-f81f-11d2-ba4b-00a0c93ec93b --change-name=2:efi \
	--new=3:0:0      --typecode=3:0fc63daf-8483-4772-8e79-3d69d8477de4 --change-name=3:rootfs \
	"$IMG"
sgdisk --print "$IMG"

part_offset_size() { # $1 = número da partição -> imprime "offset size" em bytes
	local n="$1" info first last
	info="$(sgdisk -i "$n" "$IMG")"
	first="$(awk -F': ' '/^First sector/{print $2}' <<<"$info" | awk '{print $1}')"
	last="$(awk -F': ' '/^Last sector/{print $2}' <<<"$info" | awk '{print $1}')"
	echo "$((first * 512)) $(((last - first + 1) * 512))"
}

read -r OFF1 SIZE1 <<<"$(part_offset_size 1)"
read -r OFF2 SIZE2 <<<"$(part_offset_size 2)"
read -r OFF3 SIZE3 <<<"$(part_offset_size 3)"
echo "config: offset=$OFF1 size=$SIZE1"
echo "efi:    offset=$OFF2 size=$SIZE2"
echo "rootfs: offset=$OFF3 size=$SIZE3"

# --- 2. UUIDs/IDs pré-determinados (pro fstab e pra entrada de boot baterem certo) ---
ROOTFS_UUID="$(uuidgen)"
EFI_VOLID="$(head -c4 /dev/urandom | xxd -p | tr 'a-f' 'A-F')"    # ex.: A92925B0
CONFIG_VOLID="$(head -c4 /dev/urandom | xxd -p | tr 'a-f' 'A-F')"

KVER="$(cd /rootfs-src/usr/lib/modules && ls -d */ | sed 's#/##' | head -n1)"
[ -n "$KVER" ] || { echo "Não achei versão do kernel em /rootfs-src/usr/lib/modules" >&2; exit 1; }
echo "Kernel: $KVER"

# --- 3. fstab do rootfs (agora que já sabemos os UUIDs) ---
mkdir -p /rootfs-src/boot/efi   # ponto de montagem vazio -- a ESP em si é a partição 2, gravada à parte
cat > /rootfs-src/etc/fstab <<EOF
UUID=${ROOTFS_UUID}  /          ext4  defaults  0 1
UUID=${EFI_VOLID:0:4}-${EFI_VOLID:4:4}   /boot/efi  vfat  umask=0077  0 1
EOF

# --- 4. conteúdo da ESP, como diretório simples (sem montar nada) ---
ESP="$WORK/esp"
mkdir -p "$ESP/EFI/BOOT" "$ESP/EFI/systemd" "$ESP/loader/entries" "$ESP/ubuntu/$KVER"

SDBOOT_SRC="/rootfs-src/usr/lib/systemd/boot/efi/systemd-bootaa64.efi"
[ -f "$SDBOOT_SRC" ] || { echo "Não achei $SDBOOT_SRC -- rode inner-install-bootloader-pkg.sh antes." >&2; exit 1; }
cp "$SDBOOT_SRC" "$ESP/EFI/BOOT/BOOTAA64.EFI"
cp "$SDBOOT_SRC" "$ESP/EFI/systemd/systemd-bootaa64.efi"

cat > "$ESP/loader/loader.conf" <<'EOF'
timeout 3
EOF

cp "/rootfs-src/boot/vmlinuz-${KVER}" "$ESP/ubuntu/$KVER/vmlinuz-${KVER}"
cp "/rootfs-src/boot/initrd.img-${KVER}" "$ESP/ubuntu/$KVER/initrd.img-${KVER}"

cat > "$ESP/loader/entries/ubuntu-${KVER}.conf" <<EOF
title      Ubuntu 26.04 LTS (Resolute Raccoon)
version    ${KVER}
options    root=UUID=${ROOTFS_UUID} rw console=ttyMSM0,115200n8 console=tty1 earlycon consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0
linux      /ubuntu/${KVER}/vmlinuz-${KVER}
initrd     /ubuntu/${KVER}/initrd.img-${KVER}
EOF

echo ">>> Conteúdo da ESP montado (como diretório):"
find "$ESP"

# --- 5. partição config: FAT16 + mtools (sem mount) ---
CONFIG_IMG="$WORK/config.img"
truncate -s "$SIZE1" "$CONFIG_IMG"
mkfs.vfat -F16 -n config -i "$CONFIG_VOLID" "$CONFIG_IMG"
cat > "$WORK/config.txt" <<'EOF'
# reservado para uso futuro (compatível com o layout da Radxa OS)
EOF
mcopy -i "$CONFIG_IMG" "$WORK/config.txt" ::config.txt

# --- 6. partição efi: FAT32 + mtools (sem mount), com o conteúdo montado no passo 4 ---
EFI_IMG="$WORK/efi.img"
truncate -s "$SIZE2" "$EFI_IMG"
mkfs.vfat -F32 -n efi -i "$EFI_VOLID" "$EFI_IMG"
mcopy -i "$EFI_IMG" -s "$ESP"/* ::

# --- 7. partição rootfs: ext4 direto do diretório (mkfs.ext4 -d, sem mount) ---
ROOTFS_IMG="$WORK/rootfs.img"
truncate -s "$SIZE3" "$ROOTFS_IMG"
mkfs.ext4 -F -L rootfs -U "$ROOTFS_UUID" -d /rootfs-src "$ROOTFS_IMG"

# --- 8. encaixa cada partição na imagem final, no offset certo ---
dd if="$CONFIG_IMG" of="$IMG" bs=1M seek=$((OFF1 / 1048576)) conv=notrunc status=progress
dd if="$EFI_IMG"    of="$IMG" bs=1M seek=$((OFF2 / 1048576)) conv=notrunc status=progress
dd if="$ROOTFS_IMG" of="$IMG" bs=1M seek=$((OFF3 / 1048576)) conv=notrunc status=progress

rm -rf "$WORK"
echo ">>> Imagem montada com sucesso (sem loop device)."

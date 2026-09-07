#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Alguns drivers (GPU/DPU, principalmente) pedem firmware muito cedo no boot
# -- antes do rootfs real ser montado -- então só o que está dentro do
# próprio initramfs está disponível nesse momento. Sem isso, msm_dpu não
# acha o a660_sqe.fw (mesmo ele existindo em /lib/firmware no rootfs) e cai
# num modo sem aceleração de GPU -- inaceitável pra Fase 2 (GNOME).
#
# Mesmo hook que o Armbian usa pra essa placa
# (post_family_tweaks_bsp__radxa-dragon-q6a_bsp_firmware_in_initrd em
# config/boards/radxa-dragon-q6a.conf), adaptado pro initramfs-tools puro.
set -euxo pipefail

cat > /etc/initramfs-tools/hooks/zz-qcs6490-firmware <<'EOF'
#!/bin/bash
[ "$1" = "prereqs" ] && exit 0
. /usr/share/initramfs-tools/hook-functions
add_firmware "qcom/qcs6490/a660_zap.mbn"
add_firmware "qcom/a660_sqe.fw"
add_firmware "qcom/a660_gmu.bin"
add_firmware "qcom/qcm6490/qupv3fw.elf"
add_firmware "qcom/qcs6490/radxa/dragon-q6a/adsp.mbn"
add_firmware "qcom/qcs6490/radxa/dragon-q6a/cdsp.mbn"
add_firmware "qcom/qcs6490/QCS6490-Radxa-Dragon-Q6A-tplg.bin"
EOF
chmod +x /etc/initramfs-tools/hooks/zz-qcs6490-firmware

update-initramfs -u -k all

echo "=== firmware incluído no initramfs (conferindo) ==="
KVER="$(cd /usr/lib/modules && ls -d */ | sed 's#/##' | head -n1)"
lsinitramfs "/boot/initrd.img-${KVER}" 2>/dev/null | grep -i "a660\|qupv3\|adsp.mbn\|cdsp.mbn\|tplg.bin" || echo "AVISO: nada encontrado -- hook pode não ter funcionado"

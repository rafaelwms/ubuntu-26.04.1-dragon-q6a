#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Instala o mecanismo de "crescer a partição rootfs no primeiro boot"
# (growpart + resize2fs), igual imagens cloud/Raspberry Pi OS fazem --
# a imagem sai compacta (partição fixa, pequena) mas na primeira vez que
# liga em qualquer disco, a partição rootfs cresce sozinha pra usar o
# disco inteiro. Roda só uma vez (se autodesabilita no final).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y cloud-guest-utils

cat > /usr/local/sbin/q6a-firstboot-resize.sh <<'EOF'
#!/bin/bash
set -euo pipefail

ROOT_SRC="$(findmnt -n -o SOURCE /)"
ROOT_DISK="/dev/$(lsblk -no pkname "$ROOT_SRC")"
PART_NUM="$(echo "$ROOT_SRC" | grep -oE '[0-9]+$')"

echo "Expandindo ${ROOT_DISK} partição ${PART_NUM} (${ROOT_SRC})..."
growpart "$ROOT_DISK" "$PART_NUM" || echo "growpart: nada a fazer (já no tamanho máximo?)"
resize2fs "$ROOT_SRC"

systemctl disable q6a-firstboot-resize.service
EOF
chmod +x /usr/local/sbin/q6a-firstboot-resize.sh

cat > /etc/systemd/system/q6a-firstboot-resize.service <<'EOF'
[Unit]
Description=Q6A: expande a partição rootfs pra usar o disco inteiro (só roda uma vez)
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/q6a-firstboot-resize.sh
RemainAfterExit=no

[Install]
WantedBy=sysinit.target
EOF

systemctl enable q6a-firstboot-resize.service

echo "Mecanismo de auto-resize instalado e habilitado."

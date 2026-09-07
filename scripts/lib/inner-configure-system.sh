#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static).
# Configura o básico que faltava pra dar pra logar: hostname, usuário com
# senha + sudo, e SSH habilitado (útil pra debug sem precisar de teclado/HDMI).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

HOSTNAME="q6a-server"
USERNAME="radxa"
PASSWORD="radxa"

# hostname (o debootstrap tinha herdado o hostname aleatório do container Docker
# usado pra gerar o rootfs -- ver docs/pesquisa.md)
echo "$HOSTNAME" > /etc/hostname
if ! grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
	sed -i "1i 127.0.1.1\t${HOSTNAME}" /etc/hosts
fi

# usuário com senha + sudo (root fica trancado, como o Ubuntu já faz por padrão)
if ! id "$USERNAME" >/dev/null 2>&1; then
	useradd -m -s /bin/bash -G sudo "$USERNAME"
fi
echo "${USERNAME}:${PASSWORD}" | chpasswd

apt-get update
apt-get install -y openssh-server
systemctl enable ssh

echo "Usuário: $USERNAME / Senha: $PASSWORD (com sudo). Hostname: $HOSTNAME. SSH habilitado."

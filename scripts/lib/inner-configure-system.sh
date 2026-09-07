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

# rede: NetworkManager (dá pra usar nmcli pra entrar em qualquer Wi-Fi
# interativamente -- útil enquanto estamos testando/depurando na bancada)
apt-get install -y network-manager
systemctl enable NetworkManager
mkdir -p /etc/netplan
cat > /etc/netplan/01-network-manager-all.yaml <<'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
chmod 600 /etc/netplan/01-network-manager-all.yaml

# journald ecoa mensagens do kernel/serviços no console por um caminho separado do
# console_loglevel do kernel (por isso quiet/loglevel= no cmdline não silenciava
# mensagens como "aic_load_fw ... failed" ou "qcom-apm gprsvc: CMD timeout" -- elas
# são inofensivas mas indistinguíveis de erro real pra quem está logando). Isso NÃO
# afeta as mensagens "[ OK ] Started ..." do próprio systemd (caminho diferente) nem
# o registro completo no log (journalctl -k continua mostrando tudo).
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/10-console-level.conf <<'EOF'
[Journal]
MaxLevelConsole=crit
EOF

echo "Usuário: $USERNAME / Senha: $PASSWORD (com sudo). Hostname: $HOSTNAME. SSH e NetworkManager habilitados."

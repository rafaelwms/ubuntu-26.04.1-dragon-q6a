#!/usr/bin/env bash
# Roda DENTRO do chroot arm64 (via qemu-aarch64-static). $1 = versão do
# kernel (ex.: 6.18.2-current-qcs6490).
#
# Corrige a entrada duplicada no menu do systemd-boot (ver docs/pesquisa.md
# §5.1/§6.1-bis): o `kernel-install` do próprio systemd (via
# systemd-boot-tools, já instalado) cria sua PRÓPRIA entrada BLS
# (nome <machine-id>-<kver>.conf) toda vez que algo dispara a rotina dele
# (normalmente uma trigger do dpkg quando /usr/lib/modules/<kver> é
# tocado, o que acontece num `apt upgrade` normal) -- em paralelo à nossa,
# escrita à mão em provision-partitions.sh (ubuntu-<kver>.conf). As duas
# funcionam, mas ficam duplicadas no menu.
#
# Solução: instala um serviço que, sempre que o diretório de entradas da
# ESP mudar (via um .path unit -- cobre tanto o primeiro boot quanto
# qualquer apt upgrade futuro), verifica se já existe uma entrada "oficial"
# do kernel-install pro NOSSO kernel e, se existir, apaga a nossa --
# sobrando só uma entrada, a "canônica" gerenciada pelo próprio systemd.
set -euxo pipefail

KVER="$1"
[ -n "$KVER" ] || { echo "uso: inner-install-bootentry-dedupe.sh <kver>" >&2; exit 1; }

cat > /usr/local/sbin/q6a-dedupe-boot-entry.sh <<EOF
#!/usr/bin/env bash
# Gerado em build-time por scripts/06b-install-bootentry-dedupe.sh --
# ver docs/pesquisa.md. Idempotente: seguro rodar quantas vezes for.
set -euo pipefail

ENTRIES_DIR="/boot/efi/loader/entries"
OUR_KVER="${KVER}"
OUR_ENTRY="\$ENTRIES_DIR/ubuntu-\${OUR_KVER}.conf"

[ -f "\$OUR_ENTRY" ] || exit 0

for f in "\$ENTRIES_DIR"/*"-\${OUR_KVER}.conf"; do
	[ -f "\$f" ] || continue
	base="\$(basename "\$f")"
	[ "\$base" = "ubuntu-\${OUR_KVER}.conf" ] && continue
	prefix="\${base%-\${OUR_KVER}.conf}"
	if [[ "\$prefix" =~ ^[0-9a-f]{32}\$ ]]; then
		logger -t q6a-dedupe-boot-entry "entrada oficial do kernel-install encontrada (\$base) -- removendo a nossa (\$OUR_ENTRY)"
		rm -f "\$OUR_ENTRY"
		exit 0
	fi
done
exit 0
EOF
chmod 755 /usr/local/sbin/q6a-dedupe-boot-entry.sh

cat > /etc/systemd/system/q6a-dedupe-boot-entry.service <<'EOF'
[Unit]
Description=Remove nossa entrada de boot duplicada assim que o kernel-install criar a dele

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/q6a-dedupe-boot-entry.sh

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/q6a-dedupe-boot-entry.path <<'EOF'
[Unit]
Description=Observa a pasta de entradas do systemd-boot na ESP por mudanças

[Path]
PathChanged=/boot/efi/loader/entries

[Install]
WantedBy=multi-user.target
EOF

systemctl enable q6a-dedupe-boot-entry.service
systemctl enable q6a-dedupe-boot-entry.path

echo "=== unidades instaladas ==="
systemctl is-enabled q6a-dedupe-boot-entry.service q6a-dedupe-boot-entry.path

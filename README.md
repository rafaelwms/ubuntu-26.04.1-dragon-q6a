# Ubuntu 26.04 (Resolute) para Radxa Dragon Q6A

Build customizado do Ubuntu 26.04 LTS "Resolute Raccoon" para a [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490) — Server primeiro, Desktop (GNOME) depois.

Projeto irmão de [kali-radxa-dragon-q6a](https://github.com/rafaelwms/kali-radxa-dragon-q6a), desta vez atacando também os problemas de HDMI (quebra após update) e áudio que ficaram em aberto por lá.

## Status

🚧 Em desenvolvimento — Fase 1 (Server).

Veja [`docs/pesquisa.md`](docs/pesquisa.md) para o levantamento técnico completo (hardware, causa raiz dos bugs de HDMI/áudio, decisão de arquitetura e fontes).

## Arquitetura (resumo)

- **Rootfs:** Ubuntu 26.04 "resolute" arm64 puro, via `debootstrap`.
- **Kernel/DTB/firmware:** mainline (6.18, `radxa/kernel.git`) via [Armbian Build Framework](https://github.com/armbian/build) — que já resolve os bugs de HDMI e áudio desta placa (ver `docs/pesquisa.md` §2).
- **Bootloader:** `systemd-boot` (UEFI, Boot Loader Specification) — não GRUB, não U-Boot. DTB vem do firmware (ABL/UEFI), não do bootloader.
- **NPU (Hexagon/QAIRT):** fora do escopo da Fase 1 (depende de kernel vendor + blobs proprietários).

## Estrutura

```
docs/        pesquisa e decisões técnicas
scripts/     scripts do pipeline de build
artifacts/   artefatos intermediários pequenos (ex.: .deb do kernel)
```

Imagens finais (`.img.xz`) não ficam no git — serão publicadas como Release do GitHub, como no repositório da Kali.

## Créditos

🤖 Parte deste projeto conduzida em par com [Claude Code](https://claude.com/claude-code).

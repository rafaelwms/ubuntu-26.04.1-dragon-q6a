# Pesquisa técnica — Ubuntu 26.04 (Resolute) para Radxa Dragon Q6A

> Registro do levantamento feito antes de começar o build, para não perdermos o contexto entre sessões.

## 1. Hardware

A Dragon Q6A **não é Rockchip** (diferente da maioria das SBCs da Radxa) — é baseada no **Qualcomm QCS6490**:

- CPU: 1x Kryo Gold Plus @2.7GHz + 3x Kryo Gold @2.4GHz + 4x Kryo Silver @1.9GHz (tri-cluster "1+3+4")
- GPU: Adreno 643 (OpenGL ES 3.2, Vulkan 1.3, OpenCL 2.2)
- NPU: Hexagon DSP + Hexagon Tensor Accelerator, até 12 TOPS
- Boot: 32MB QSPI NOR Flash (bootloader Qualcomm — XBL/ABL), botão físico de **EDL** (Emergency Download) para recovery de baixo nível
- Armazenamento: microSD, eMMC (módulo), UFS (módulo), M.2 M-Key 2230 NVMe SSD
- HDMI 2.0 até 4K@30, 1x MIPI DSI, 3x MIPI CSI
- Áudio: P2 4 polos (fone+mic), saída estéreo (aciona fone de 32Ω diretamente) — **sem chip codec dedicado** listado
- Fonte: [docs.radxa.com/en/dragon/q6a](https://docs.radxa.com/en/dragon/q6a)

Boot priority documentada: **USB > microSD > NVMe SSD > eMMC > UFS**.

Fluxo de gravação em NVMe (o que vamos usar com os cases Thunderbolt): SSD no case → grava a imagem raw (`.img` extraído do `.img.xz`) via `dd`/Balena Etcher → SSD no slot M.2 da Q6A → liga. **Sem necessidade de EDL/QDL** no fluxo normal — confirmado em [docs.radxa.com/.../install-system/nvme-system/nvme-reader](https://docs.radxa.com/en/dragon/q6a/getting-started/install-system/nvme-system/nvme-reader). Igual ao fluxo que vocês já usam com a Kali.

## 2. Causa raiz dos dois problemas relatados

### 2.1 HDMI para de funcionar depois do update

Não é bug da placa específica. A própria Radxa avisa na doc oficial ([Quick Start](https://docs.radxa.com/en/dragon/q6a/getting-started/quickly-start)):

> "Upgrading with `sudo apt update && sudo apt upgrade` may result in incomplete updates or unexpected system issues."

Recomendam usar `sudo rsetup` → System → System Update em vez de apt puro. Hipótese: kernel/DTB/firmware precisam ser atualizados como conjunto atômico, e apt normal desalinha essas peças (pacote de kernel novo sem o DTB/firmware correspondente, por exemplo).

**Implicação pro nosso build:** empacotar kernel + DTB + firmware como um conjunto coeso (é exatamente o que os pacotes `linux-image-*` / `linux-dtb-*` do Armbian fazem) e ter cuidado com upgrades futuros — não é algo que resolvemos "de uma vez", é uma prática a manter.

### 2.2 Áudio não funciona (problema que apareceu na imagem Kali)

O link do fórum ([warpme/minimyth2](https://github.com/warpme/minimyth2/tree/master/script/kernel/linux-7.0/files)) está **404 — não existe mais** — e mesmo que existisse, minimyth2 é uma distro para roteadores x86, sem relação com DSP de áudio Qualcomm. **Não é o caminho certo.**

A causa raiz real, confirmada em dois commits recentes do Armbian especificamente para esta placa:

1. **[armbian/firmware#129](https://github.com/armbian/firmware/pull/129)** — os blobs `adsp.mbn`/`cdsp.mbn` (firmware do DSP de áudio/compute da Qualcomm) estavam incorretos e travavam o DSP. Corrigido usando os blobs certos via `linux-firmware`.
2. **[armbian/build#10019](https://github.com/armbian/build/pull/10019)** (merged 22/06/2026) — o `alsa-ucm-conf` de fábrica não tem o "DMI matcher" da Radxa, então o ALSA nunca reconhece a placa de som certa e cai num dummy sink. Corrigido com um backport `alsa-ucm-conf` da Radxa.

Existe até uma topologia de áudio (grafo AudioReach) já pronta para esta placa exata: [`QCS6490-Radxa-Dragon-Q6A.m4`](https://github.com/linux-msm/audioreach-topology/blob/main/QCS6490-Radxa-Dragon-Q6A.m4) e o binário `QCS6490-Radxa-Dragon-Q6A-tplg.bin`.

Arquivos de firmware exatos necessários (confirmado lendo o `config/boards/radxa-dragon-q6a.conf` do Armbian, ver §3):

```
qcom/qcs6490/a660_zap.mbn                              # GPU
qcom/a660_sqe.fw                                       # DPU
qcom/a660_gmu.bin                                      # GPU GMU
qcom/qcm6490/qupv3fw.elf                               # I2C/SPI/UART (QUP serial engines)
qcom/qcs6490/radxa/dragon-q6a/adsp.mbn                 # DSP de áudio (remoteproc0)
qcom/qcs6490/radxa/dragon-q6a/cdsp.mbn                 # DSP de compute (remoteproc1)
qcom/qcs6490/QCS6490-Radxa-Dragon-Q6A-tplg.bin         # topologia de áudio (AudioReach/UCM)
```

Pacote ALSA UCM com o matcher da Radxa (deb direto, sem precisar compilar):
```
https://github.com/radxa-pkg/alsa-ucm-conf/releases/download/1.2.16.1-radxa-1/alsa-ucm-conf_1.2.16.1-radxa-1_all.deb
```

## 3. Decisão de arquitetura: kernel mainline via Armbian

A Radxa só oferece **"Radxa OS"** como imagem oficial (é o Ubuntu customizado deles — o `noble_gnome` que já temos). **Armbian é listado oficialmente como opção "third-party"** endorsada pela própria Radxa para esta placa ([radxa.com/products/dragon/q6a](https://radxa.com/products/dragon/q6a/)).

O Armbian mantém suporte ativo e mainline pra essa placa (maintainer: HeyMeco SuperKali, board "introduced 2025"):

- Kernel fonte real: **`https://github.com/radxa/kernel.git`, branch `linux-6.18.2`** (target "current"; havia uma referência a um repo `nascs/*` vinda de uma busca na web que **não existe / é falsa** — descartada depois de verificar).
- Poucos patches por cima do fork da Radxa (`patch/kernel/archive/qcs6490-6.18/`: só 1 patch de compat glibc + patching_config.yaml) — a maior parte do suporte de hardware já está upstream.
- **Bootloader: GRUB (UEFI arm64) + extensão `grub-with-dtb`**, não U-Boot raw — `BOOTCONFIG="none"` no board config. Isso bate com o fato de a placa rodar Windows 11 IoT (UEFI real) e simplifica MUITO nosso processo de imagem: é o mesmo esquema de boot de uma Ubuntu Server arm64 UEFI "genérica", só com o detalhe do DTB.
- Firmware completo via `linux-firmware` + os blobs específicos listados acima (`BOARD_FIRMWARE_INSTALL="-full"`).
- Config real do board: `config/boards/radxa-dragon-q6a.conf` no repo `armbian/build` (clonado em `armbian-build/` — está no `.gitignore`, não versionado aqui).

**Trade-off aceito:** a NPU Hexagon (aceleração de IA, 12 TOPS) depende de blobs proprietários (QAIRT/FastRPC) que só têm suporte maduro no kernel vendor ~6.8, não no mainline 6.18. Fica de fora da Fase 1 (Server); revisitamos depois se for necessário.

## 3.1 Correção de rota: o bootloader real é systemd-boot, não GRUB (confirmado no hardware)

Inspecionamos ao vivo o SSD de testes (`nvme1n1`, no case USB/Thunderbolt) que tinha a instalação da **Kali** de vocês. Isso revelou o boot chain real usado de fato pela Radxa, e corrigiu uma suposição errada do §3 (que veio só da leitura do `qcs6490.conf` do Armbian, que usa GRUB por ser um framework genérico multi-placa):

**Tabela de partições real (GPT):**

| Partição | FS | Label | Tamanho | GUID de tipo |
|---|---|---|---|---|
| `nvme1n1p1` | FAT16 | `config` | 16MB | Linux filesystem (genérico) — é a área de config do `rsetup` (`config.txt`/`before.txt`/`after.txt`, ver [radxa-pkg/rsetup](https://github.com/radxa-pkg/rsetup)), não é essencial pro boot |
| `nvme1n1p2` | FAT32 | `efi` | 1GB | **ESP real** (`c12a7328-f81f-11d2-ba4b-00a0c93ec93b`) |
| `nvme1n1p3` | ext4 | `rootfs` | resto do disco | Linux filesystem |

**Dentro da ESP:** não tem GRUB — é **systemd-boot** puro (Boot Loader Specification, type #1):

```
/EFI/BOOT/BOOTAA64.EFI              # fallback
/EFI/systemd/systemd-bootaa64.efi   # o bootloader real
/loader/loader.conf                 # "timeout 3"
/loader/entries/RadxaOS-6.18.2-3-qcom.conf
/RadxaOS/6.18.2-3-qcom/linux                       # kernel
/RadxaOS/6.18.2-3-qcom/initrd.img-6.18.2-3-qcom    # initrd
/RadxaOS/6.18.2-3-qcom/dtbo/*.dtbo.disabled        # overlays opcionais (câmeras, displays, PoE HAT...)
```

Entrada BLS real (gerada por `/usr/lib/kernel/install.d/90-loaderentry.install`, ou seja, é o `kernel-install` padrão do systemd — nada customizado):

```
title      Ubuntu 24.04.4 LTS
version    6.18.2-3-qcom
options    root=UUID=a03a5c05-3365-4811-a1dd-f1776983aa76 console=ttyMSM0,115200n8 quiet splash loglevel=4 rw earlycon consoleblank=0 console=tty1 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off
linux      /RadxaOS/6.18.2-3-qcom/linux
initrd     /RadxaOS/6.18.2-3-qcom/initrd.img-6.18.2-3-qcom
```

**Importante — não existe nenhum `.dtb` na ESP nem linha `devicetree=` na entrada.** O firmware (ABL/UEFI da Qualcomm) entrega o device tree direto pro kernel via tabela de configuração EFI (`EFI_DTB_TABLE_GUID`) — o mesmo mecanismo que permite essa placa rodar Windows 11 IoT. O stub EFI do kernel arm64 (`drivers/firmware/efi/libstub`) já sabe usar isso automaticamente. **Ou seja: não precisamos gerenciar DTB no bootloader**, só garantir que o kernel tenha `CONFIG_EFI` + suporte a essa placa (`linux-dtb-*` do Armbian só seria necessário se fôssemos usar GRUB; para systemd-boot/BLS puro nem precisamos instalá-lo).

**Decisão atualizada:** vamos usar `bootctl install` (systemd-boot) + o `kernel-install`/BLS padrão do Ubuntu em vez de GRUB — é mais simples, é o que já funciona de verdade nessa placa, e o Ubuntu 26.04 já traz esse mecanismo de fábrica (basta os pacotes `systemd-boot` + hooks de `/etc/kernel/install.d/` estarem presentes).

## 3.2 Causa raiz do áudio confirmada ao vivo (não é só teoria)

Com a partição rootfs da Kali montada (somente leitura), fomos direto no ponto: `/usr/share/alsa/ucm2/conf.d/qcs6490/QCS6490-Radxa-Dragon-Q6A.conf` é um **symlink quebrado**:

```
QCS6490-Radxa-Dragon-Q6A.conf -> ../../Qualcomm/qcs6490/QCS6490-Radxa-Dragon-Q6A/QCS6490-Radxa-Dragon-Q6A.conf
```

O diretório de destino (`Qualcomm/qcs6490/QCS6490-Radxa-Dragon-Q6A/`, que teria o `HiFi.conf` e a definição de PCM) **não existe** no `alsa-ucm-conf 1.2.15.3-1` (versão stock instalada). Bate 100% com a descrição do fix do Armbian — não é só teoria, é o bug batendo na nossa frente. Vamos instalar o backport da Radxa (`alsa-ucm-conf 1.2.16.1-radxa-1`, ver §2.2) em vez do pacote stock do Ubuntu.

Também confirmamos e copiamos os blobs de firmware reais direto dessa instalação (fonte mais confiável que tentar montar a partir do linux-firmware.git puro) para [`artifacts/firmware-qcs6490-dragon-q6a/`](../artifacts/firmware-qcs6490-dragon-q6a/): `adsp.mbn`, `cdsp.mbn`, `QCS6490-Radxa-Dragon-Q6A-tplg.bin`, `a660_zap.mbn` (GPU), `a660_gmu.bin.zst`/`a660_sqe.fw.zst` (GPU GMU / DPU), `qupv3fw.elf` (QUP serial engines) e o firmware do WiFi6/BT (`ath11k/WCN6750/hw1.0/qcm6490/wpss.mbn.zst` + `board-2.bin.zst` — o chip companion é o **WCN6750** via `ath11k`, já mainline; a extensão `radxa-aic8800` do Armbian é para um dongle USB opcional, não o WiFi onboard).

> Nota de licença: são blobs binários da Qualcomm redistribuídos pela própria Radxa (mesmo termo do `linux-firmware.git`). Ok para nosso pipeline de build; ao publicar a imagem final, incluir o aviso de licença (`WHENCE`/`LICENSE.qcom`) como o `linux-firmware` faz.

## 4. Primeiro resultado concreto

Rodamos (dentro de container Docker, gerenciado automaticamente pelo próprio Armbian Build Framework — nosso host é Ubuntu 26.04 "Resolute", não Debian Trixie nativo):

```bash
./compile.sh kernel BOARD=radxa-dragon-q6a BRANCH=current
```

Isso baixou (via cache remoto do Armbian, `ghcr.io/armbian/os/kernel-qcs6490-current`) os pacotes já compilados do kernel 6.18.2 para esta placa em ~1 minuto. Ficaram em [`artifacts/kernel-current-qcs6490/`](../artifacts/kernel-current-qcs6490/):

- `linux-image-current-qcs6490_*_arm64.deb`
- `linux-dtb-current-qcs6490_*_arm64.deb` (inclui `qcom/qcs6490-radxa-dragon-q6a.dtb`)
- `linux-headers-current-qcs6490_*_arm64.deb`
- `linux-libc-dev-current-qcs6490_*_arm64.deb`

## 5. Próximos passos (Fase 1 — Server)

1. ✅ `debootstrap` do rootfs Ubuntu 26.04 "resolute" arm64 puro — feito, ver [scripts/01-build-rootfs.sh](../scripts/01-build-rootfs.sh).
2. `dpkg -i` dos `.deb` do kernel Armbian (`linux-image`/`linux-dtb`, ver §4) dentro desse rootfs.
3. Instalar firmware: os blobs específicos da Q6A já extraídos em [`artifacts/firmware-qcs6490-dragon-q6a/`](../artifacts/firmware-qcs6490-dragon-q6a/) (§3.2) + `linux-firmware` do Ubuntu pro resto + o `.deb` do `alsa-ucm-conf` da Radxa (§2.2/§3.2).
4. Montar partição GPT igual à real (§3.1: `config` 16MB + `efi` 1GB ESP + `rootfs` ext4), instalar **systemd-boot** (`bootctl install`) com entrada BLS usando o cmdline de referência do §3.1, **sem se preocupar com DTB** (vem do firmware).
5. Empacotar como `.img`, comprimir `.img.xz`, gravar num NVMe via case USB/Thunderbolt e testar na Q6A (HDMI, rede, áudio, NVMe).
6. Só depois disso validado: Fase 2 — instalar `ubuntu-desktop` + GNOME por cima do Server já funcional.

## Fontes consultadas

- [docs.radxa.com/en/dragon/q6a](https://docs.radxa.com/en/dragon/q6a) — specs, getting started, instalação em NVMe, FAQ
- [radxa.com/products/dragon/q6a](https://radxa.com/products/dragon/q6a/) — imagens oficiais/terceiros
- [github.com/armbian/build](https://github.com/armbian/build) — `config/boards/radxa-dragon-q6a.conf`, `config/sources/families/qcs6490.conf`, patches
- [github.com/armbian/build/pull/10019](https://github.com/armbian/build/pull/10019) — fix do UCM de áudio
- [github.com/armbian/firmware/pull/129](https://github.com/armbian/firmware/pull/129) — fix dos blobs adsp/cdsp
- [github.com/linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology/blob/main/QCS6490-Radxa-Dragon-Q6A.m4) — topologia de áudio
- [docs.armbian.com/build-framework/commands/basic](https://docs.armbian.com/build-framework/commands/basic/) — comandos `kernel`/`uboot`/`build`
- [gist.github.com/Foadsf](https://gist.github.com/Foadsf/3cc2e0ed357c3ac7180589701bf83284) — relato de experiência (NPU/FastRPC é o ponto mais espinhoso)

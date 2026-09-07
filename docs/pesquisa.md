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

## 4.1 Kernel + firmware + fix de áudio instalados no rootfs (verificado)

Rodando [scripts/02-install-kernel-firmware.sh](../scripts/02-install-kernel-firmware.sh) (mesmo esquema Docker + `qemu-aarch64-static` do script anterior): instalamos `linux-image`/`linux-dtb` current-qcs6490, o `linux-firmware` completo do Ubuntu, sobrepusemos com os blobs verificados da Q6A (§3.2), e instalamos o `alsa-ucm-conf` da Radxa.

Duas pedras no caminho, ambas resolvidas:
- O rootfs mínimo não tinha `wget`/`ca-certificates` — adicionado ao script.
- `alsa-ucm-conf` ficou "half-installed" por faltar `libasound2t64` (rootfs mínimo não tem libs de ALSA) — resolvido com `apt-get install -f`.

**Verificação final — o symlink que estava quebrado na Kali agora resolve de verdade:**

```
usr/share/alsa/ucm2/conf.d/qcs6490/QCS6490-Radxa-Dragon-Q6A.conf
  -> ../../Qualcomm/qcs6490/QCS6490-Radxa-Dragon-Q6A/QCS6490-Radxa-Dragon-Q6A.conf   ✅ existe
```

Kernel instalado: `6.18.2-current-qcs6490` (`/usr/lib/modules/`, `/boot/vmlinuz` e `/boot/initrd.img` com os symlinks certos, gerados automaticamente pelo `postinst` do pacote). Tamanho do rootfs agora: ~2,3GB (a maior parte é o `linux-firmware` completo, ~740MB).

## 4.3 Primeiro boot real na placa — funcionou, com dois ajustes

Gravamos a imagem no SSD de testes (`nvme1n1`, via case USB/Thunderbolt) e testamos na Dragon Q6A de verdade, com saída HDMI numa placa de captura. **Resultado: bootou até o prompt de login, pela HDMI.** Kernel, systemd-boot, DTB via firmware, tudo funcionou de primeira.

Dois problemas apareceram:

**1. Sem usuário/senha.** O `debootstrap` não cria usuário nenhum, e nunca configuramos isso — `root` fica com senha trancada (`*` no shadow) por padrão no Ubuntu. Corrigido em [scripts/02b-configure-system.sh](../scripts/02b-configure-system.sh): cria usuário `radxa`/`radxa` com sudo, define hostname (`q6a-server` — o hostname anterior, uma string hex aleatória, vinha do próprio container Docker usado pra rodar o `debootstrap`/chroot, não do sistema em si), e habilita SSH.

**2. `qcom-apm gprsvc: CMD timeout for [...] opcode` no dmesg — o áudio quebrado de novo, numa camada mais baixa.** Essa é a mesma família de bug do §2.2/§3.2, só que mais fundo: os blobs `adsp.mbn`/`cdsp.mbn` que extraímos do install real (vendor, antigo) falam uma versão do protocolo GPR/AudioReach que **não bate** com o driver `q6apm` do kernel mainline 6.18 que estamos usando. O APM do DSP simplesmente para de responder aos comandos GPR. Confirmado por relatos idênticos ("qcom-apm gprsvc: CMD timeout" + "q6apm-dai: Error queuing playback buffer -16") resolvidos exatamente da mesma forma que o `armbian/firmware#129` já tinha feito: **usar os blobs do `linux-firmware` puro, não os extraídos do vendor**.

Ironia: meu passo de "reforçar com o firmware verificado" (§3.2/§4.1) fazia exatamente o oposto do que devia — sobrescrevia a versão certa (que o `apt install linux-firmware` já tinha instalado, como `.zst`) com a versão vendor errada (sem `.zst`, sobrepondo por nome de arquivo diferente, por isso os dois coexistiam sem conflito de pacote).

**Correção aplicada:** removido o passo de reaplicar `artifacts/firmware-qcs6490-dragon-q6a/` por cima em [scripts/lib/provision-kernel-firmware.sh](../scripts/lib/provision-kernel-firmware.sh) e em [scripts/02-install-kernel-firmware.sh](../scripts/02-install-kernel-firmware.sh), reconstruída a imagem e regravada no SSD.

### ⚠️ Atualização: o teste real mostrou que essa hipótese estava ERRADA

Depois de regravar e testar de novo na placa, **o mesmo `qcom-apm gprsvc: CMD timeout for [1001021] opcode` apareceu de novo**, no mesmíssimo instante do boot (~8.16s). Comparei byte a byte o `adsp.mbn` que eu tinha extraído do vendor com o `adsp.mbn.zst` do pacote `linux-firmware` (`cmp`/`md5sum`) — **são idênticos** (`c2af746280ea70f8407f4d813389ae5e` nos dois). Ou seja: nunca houve incompatibilidade de firmware nesse arquivo — minha hipótese (baseada em buscas na web que, percebi depois, ficaram repetindo a mesma narrativa da PR do Armbian sem trazer nada novo) estava errada.

**Causa real ainda não identificada.** O que sabemos até agora:
- Não trava o boot — o sistema sobe normal, HDMI/login funcionam.
- É bem provável que seja um problema genuíno (ainda em aberto) do driver `q6apm` mainline nessa combinação específica de placa+firmware+kernel 6.18 — a comunidade Armbian/Radxa parece estar iterando ativamente nisso ([fórum "HDMI Audio support Fix"](https://forum.armbian.com/topic/57121-latest-armbian-build-hdmi-audio-support-fix/) menciona múltiplos ajustes distintos: UCM, módulo de codec, e até um script rodando `amixer` manualmente pra configurar o roteamento DISPLAY_PORT_RX_0 — nenhum bate exatamente com o nosso sintoma).
- Só vamos conseguir depurar isso de verdade com acesso interativo (SSH) na placa — `dmesg` completo, `cat /sys/class/remoteproc/remoteproc*/state`, `aplay -l`, etc. — em vez de regravar o SSD a cada palpite.

**Prioridade agora:** deixar a rede (Wi-Fi + SSH) funcionando primeiro — é infraestrutura que vamos precisar de qualquer forma pra depurar tudo o resto com mais velocidade. Áudio fica como item em aberto, não bloqueante pra Fase 1.

## 5. Próximos passos (Fase 1 — Server)

1. ✅ `debootstrap` do rootfs Ubuntu 26.04 "resolute" arm64 puro — feito, ver [scripts/01-build-rootfs.sh](../scripts/01-build-rootfs.sh).
2. ✅ Kernel + firmware + fix de áudio instalados e verificados — feito, ver §4.1 e [scripts/02-install-kernel-firmware.sh](../scripts/02-install-kernel-firmware.sh).
3. ✅ Imagem montada e comprimida — feito, ver §4.2 e [scripts/03-assemble-image.sh](../scripts/03-assemble-image.sh).
4. Gravar num NVMe via case USB/Thunderbolt e testar na Q6A (HDMI, rede, áudio, NVMe).
5. Só depois disso validado: Fase 2 — instalar `ubuntu-desktop` + GNOME por cima do Server já funcional.

## 4.2 Imagem montada (sem loop device)

**Problema encontrado:** neste ambiente (sandboxed), criar nós de dispositivo de partição num loop device falha de forma inconsistente — tanto `-P` + `partprobe`/`partx` (silenciosamente não recriam os nós) quanto múltiplos loop devices simultâneos via `--offset`/`--sizelimit` (o 3º attach falha com "No such file or directory", mesmo com `--privileged`). Provável restrição do próprio sandbox do ambiente, não do kernel.

**Solução:** eliminar loop device do processo de montagem por completo:
- `sgdisk` particiona o arquivo `.img` bruto diretamente (não precisa de loop device pra isso).
- Partição `rootfs` (ext4): `mkfs.ext4 -d output/rootfs -U <uuid>` — popula o filesystem direto do diretório, sem montar nada.
- Partições `config`/`efi` (FAT16/32): `mtools` (`mcopy`) escreve os arquivos direto na imagem da partição, sem montar nada.
- Cada partição vira um arquivo separado, depois `dd ... seek=<offset/1MiB> conv=notrunc` encaixa cada uma no lugar certo dentro da imagem final (todos os offsets caem em múltiplos exatos de 1MiB, graças ao alinhamento padrão do `sgdisk` + nossos tamanhos redondos).
- UUIDs (rootfs ext4 e volume ID das FAT) são pré-gerados (`uuidgen`/aleatório) *antes* de criar os filesystems, pra poderem ser usados tanto no `/etc/fstab` quanto na entrada BLS do systemd-boot sem depender de montar nada primeiro.
- O binário do systemd-boot (`systemd-bootaa64.efi`) e o conteúdo da ESP (`EFI/BOOT/`, `EFI/systemd/`, `loader/`, kernel+initrd) são montados como um diretório comum antes de virar imagem FAT — sem precisar rodar `bootctl install` (que exigiria uma ESP de verdade montada); construímos a estrutura manualmente, replicando exatamente o que vimos no hardware real (§3.1).

Verificado montando cada partição (uma de cada vez, via loop, só para checagem) na imagem final: `/etc/os-release` = Ubuntu 26.04 Resolute, `/etc/fstab` com os UUIDs certos, kernel `6.18.2-current-qcs6490`, symlink de áudio resolvendo, firmware da Q6A no lugar, e a ESP com a estrutura idêntica à do hardware real (`EFI/BOOT/BOOTAA64.EFI`, `loader/entries/ubuntu-*.conf`, `ubuntu/<kver>/{vmlinuz,initrd.img}`).

Resultado: [`output/radxa-dragon-q6a_resolute_server_dev.img.xz`](../output/) — 8GB raw → **1,71GB comprimido**.

## Fontes consultadas

- [docs.radxa.com/en/dragon/q6a](https://docs.radxa.com/en/dragon/q6a) — specs, getting started, instalação em NVMe, FAQ
- [radxa.com/products/dragon/q6a](https://radxa.com/products/dragon/q6a/) — imagens oficiais/terceiros
- [github.com/armbian/build](https://github.com/armbian/build) — `config/boards/radxa-dragon-q6a.conf`, `config/sources/families/qcs6490.conf`, patches
- [github.com/armbian/build/pull/10019](https://github.com/armbian/build/pull/10019) — fix do UCM de áudio
- [github.com/armbian/firmware/pull/129](https://github.com/armbian/firmware/pull/129) — fix dos blobs adsp/cdsp
- [github.com/linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology/blob/main/QCS6490-Radxa-Dragon-Q6A.m4) — topologia de áudio
- [docs.armbian.com/build-framework/commands/basic](https://docs.armbian.com/build-framework/commands/basic/) — comandos `kernel`/`uboot`/`build`
- [gist.github.com/Foadsf](https://gist.github.com/Foadsf/3cc2e0ed357c3ac7180589701bf83284) — relato de experiência (NPU/FastRPC é o ponto mais espinhoso)

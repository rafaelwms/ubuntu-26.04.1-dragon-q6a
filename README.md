# Ubuntu 26.04.1 "Resolute Raccoon" for the Radxa Dragon Q6A

<!-- ![Radxa Dragon Q6A running Ubuntu Desktop](docs/images/hero.jpg) -->

Custom Ubuntu 26.04.1 LTS build for the [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490) — **Server** and **Desktop (GNOME)** images, both fixing the HDMI-breaks-after-update and audio bugs of the stock Radxa image.

Sibling project of [kali-radxa-dragon-q6a](https://github.com/rafaelwms/kali-radxa-dragon-q6a).

🇧🇷 **[Leia em português mais abaixo](#português)**

---

## English

### What you get

| | Server | Desktop |
|---|---|---|
| Base | Ubuntu 26.04.1 LTS arm64, kernel 6.18.2 (mainline, via Armbian) | Same base + `ubuntu-desktop-minimal` (GNOME, no office suite/games) |
| HDMI | ✅ hardware-accelerated (Adreno GPU) | ✅ same |
| Wi-Fi + Bluetooth | ✅ onboard, native driver | ✅ same |
| Audio | ✅ works (headphone + HDMI) | ✅ same (needed an extra fix, see below) |
| `apt upgrade` | ✅ confirmed does **not** break HDMI | ✅ same |
| Browser | — | Firefox (native `.deb`, official Mozilla repo — no snap) |
| Software center | — | `gnome-software` (native, no snap) |
| Default login | `radxa` / `radxa` — change it on first boot (`passwd`) | same |

Root partition grows automatically to fill the whole disk on first boot. Each device gets its own unique `machine-id`, generated on first boot.

### Known limitations

- The NPU (Hexagon DSP, AI acceleration) is out of scope — it depends on proprietary vendor blobs not available for the mainline kernel we use.

### Install a pre-built image

1. Go to [Releases](../../releases) and download every `.part*` file for the image you want (Server **or** Desktop — don't mix them), plus the two `SHA256SUMS-*.txt` files.
2. Run the interactive installer for your OS — it verifies checksums, reassembles the image, and flashes it, asking you to confirm the exact target device before writing anything:

   ```bash
   ./install.sh       # Linux
   ./install_mac.sh   # macOS
   ```

   (Both available in English and Portuguese — they ask which one at startup. The macOS version uses `diskutil`/raw-disk writes instead of `lsblk`/`dd` directly, since that's how flashing works there.)

Or do it by hand:

```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > image.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat image.img.xz | sudo dd of=/dev/YOUR_DEVICE bs=4M status=progress conv=fsync
```

### Build it yourself from source

No need to download anything from Releases — this reproduces the whole pipeline (kernel build, rootfs, firmware, all the fixes below) from scratch:

```bash
./scripts/build.sh
```

Needs Docker and about 15GB of free disk space. Takes a while (kernel build is fast thanks to Armbian's remote cache; `debootstrap` + package installs are the bulk of the time). Also bilingual, interactive.

### The journey (short version)

The stock Radxa OS image for this board has two known problems: **HDMI stops working after `apt upgrade`**, and **audio never worked at all** (Radxa's own docs warn against plain `apt upgrade` for the first one; the second was reported against our sibling Kali project too). Instead of patching the stock image, we built Ubuntu from scratch on top of a validated, mainline-adjacent foundation:

- **Bootloader, corrected by inspecting the real hardware.** Generic Armbian docs suggested GRUB; mounting the actual Kali installation's ESP showed it's plain **systemd-boot** (Boot Loader Specification), with the device tree delivered by the UEFI firmware itself — no bootloader-side DTB management needed. This shaped the whole image layout.
- **Audio root-caused for real, not guessed.** Live inspection of the working Kali install found a broken symlink in `alsa-ucm-conf` pointing at a directory that doesn't exist in the stock package version — confirmed against two upstream Armbian fixes for this exact board. A Radxa backport of `alsa-ucm-conf` plus the correct UCM activation sequence (`alsaucm ... set _verb HiFi set _enadev Headphones`) got real, audible sound working on the Server image.
- **Wrong assumption caught and corrected mid-project.** Wi-Fi was initially assumed to need an external USB dongle (missing device-tree node for the PCIe path). Testing without one showed it worked anyway — the onboard module uses the same AIC8800-family chip over an internal USB path, confirmed by matching the exact device-tree node. No dongle needed after all.
- **`apt upgrade` resilience validated on real hardware** — the exact problem that motivated this whole project, tested directly: full package upgrade, reboot, HDMI and everything else still working. (A harmless cosmetic side effect — a duplicate boot-menu entry from systemd's own `kernel-install` — was root-caused and fixed with a small self-healing service.)
- **A newer kernel was tested and rejected, on purpose.** When the Desktop image's SoundWire/audio bug turned up, we first built and tested kernel 7.2.3 to see if it fixed it. It didn't (a different bug appeared instead), and it broke HDMI outright on this board — a regression the Radxa team itself has confirmed and advises against. We reverted rather than ship a worse trade-off.
- **Desktop audio: root cause found for real, fixed.** What looked like an unfixable upstream kernel race turned out to be simpler: on the Desktop image, the SoundWire controller, the LPASS codec-macro clocks, and the WCD938x codec driver never get autoloaded at boot, so the ALSA card never registers (confirmed live: manually `modprobe`-ing them in the right order made the card appear immediately, no kernel patch needed). Fixed by explicitly loading those modules via `systemd-modules-load.service` (see [scripts/07d-fix-desktop-audio-soundwire.sh](scripts/07d-fix-desktop-audio-soundwire.sh)) — confirmed working on real hardware, both headphone and HDMI output, after a clean reboot. Details in [docs/pesquisa.md, section 6.1](docs/pesquisa.md).
- **A quieter bug found by accident:** every device flashed from the same image was getting the *exact same* `machine-id` (baked in by `systemd` during the build's `apt install`, never reset) — fixed by clearing it as the last build step, so each device generates its own on first boot.

The full, warts-and-included technical log — every dead end, every root cause, every command — is in [`docs/pesquisa.md`](docs/pesquisa.md) (in Portuguese). The commit history tells the same story chronologically if you'd rather read it that way.

### Repository structure

```
install.sh          interactive installer, Linux (flash a pre-built release)
install_mac.sh       interactive installer, macOS
scripts/build.sh     interactive orchestrator (build from source)
scripts/             the actual build pipeline, one numbered script per step
scripts/experiments/ things we tried and rejected (kept for the record)
docs/pesquisa.md     the full technical research log (Portuguese)
```

### Credits

🤖 Part of this project was built pair-programming with [Claude Code](https://claude.com/claude-code).

### License

[MIT](LICENSE).

---

## Português

### O que você tem aqui

| | Server | Desktop |
|---|---|---|
| Base | Ubuntu 26.04.1 LTS arm64, kernel 6.18.2 (mainline, via Armbian) | Mesma base + `ubuntu-desktop-minimal` (GNOME, sem suíte de escritório/jogos) |
| HDMI | ✅ com aceleração de GPU (Adreno) | ✅ igual |
| Wi-Fi + Bluetooth | ✅ onboard, driver nativo | ✅ igual |
| Áudio | ✅ funciona (fone + HDMI) | ✅ igual (precisou de um fix extra, ver abaixo) |
| `apt upgrade` | ✅ confirmado que não quebra o HDMI | ✅ igual |
| Navegador | — | Firefox (`.deb` nativo, repo oficial da Mozilla — sem snap) |
| Central de software | — | `gnome-software` (nativo, sem snap) |
| Login padrão | `radxa` / `radxa` — troque no primeiro boot (`passwd`) | igual |

A partição raiz cresce sozinha pra ocupar o disco todo no primeiro boot. Cada aparelho gera seu próprio `machine-id` único no primeiro boot.

### Limitações conhecidas

- A NPU (Hexagon DSP, aceleração de IA) está fora do escopo — depende de blobs proprietários do fabricante que não têm suporte maduro no kernel mainline que usamos.

### Instalar uma imagem pronta

1. Vá em [Releases](../../releases) e baixe todas as partes (`.part*`) da imagem que você quer (Server **ou** Desktop — não misture), mais os dois arquivos `SHA256SUMS-*.txt`.
2. Rode o instalador interativo do seu sistema — ele confere os checksums, reconstrói a imagem, e grava, pedindo pra você confirmar o dispositivo de destino antes de escrever qualquer coisa:

   ```bash
   ./install.sh       # Linux
   ./install_mac.sh   # macOS
   ```

   (Os dois em português e inglês — perguntam qual no início. A versão de macOS usa `diskutil`/gravação no disco raw em vez de `lsblk`/`dd` direto, que é como funciona por lá.)

Ou na mão:

```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > imagem.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat imagem.img.xz | sudo dd of=/dev/SEU_DISPOSITIVO bs=4M status=progress conv=fsync
```

### Construir você mesmo, a partir do código-fonte

Sem precisar baixar nada das Releases — isso reproduz o pipeline inteiro (build do kernel, rootfs, firmware, todos os fixes abaixo) do zero:

```bash
./scripts/build.sh
```

Precisa de Docker e uns 15GB de espaço livre. Demora um tempo (o build do kernel é rápido graças ao cache remoto do Armbian; o `debootstrap` + instalação de pacotes é que consome a maior parte do tempo). Também bilíngue, interativo.

### A jornada (versão resumida)

A imagem stock da Radxa OS pra essa placa tem dois problemas conhecidos: **o HDMI para de funcionar depois de um `apt upgrade`**, e **o áudio nunca funcionou** (a própria documentação da Radxa avisa contra `apt upgrade` puro por causa do primeiro; o segundo já tinha sido relatado no nosso projeto irmão, o Kali). Em vez de remendar a imagem stock, construímos o Ubuntu do zero em cima de uma base validada, próxima do mainline:

- **Bootloader, corrigido inspecionando o hardware de verdade.** A documentação genérica do Armbian sugeria GRUB; montar a ESP da instalação Kali real mostrou que é **systemd-boot** puro (Boot Loader Specification), com o device tree entregue pelo próprio firmware UEFI — sem precisar gerenciar DTB no bootloader. Isso moldou toda a arquitetura da imagem.
- **Áudio com causa raiz confirmada de verdade, não só suposição.** Inspecionar ao vivo a instalação Kali funcionando achou um symlink quebrado no `alsa-ucm-conf`, apontando pra um diretório que não existe na versão stock do pacote — confirmado contra dois fixes do Armbian pra essa placa exata. Um backport da Radxa do `alsa-ucm-conf`, mais a sequência certa de ativação do UCM (`alsaucm ... set _verb HiFi set _enadev Headphones`), fez o som sair de verdade, audível, no Server.
- **Suposição errada, pega e corrigida no meio do projeto.** Achávamos que o Wi-Fi precisava de um dongle USB externo (faltava o nó de device-tree do caminho PCIe). Testando sem dongle nenhum, funcionou do mesmo jeito — o módulo onboard usa o mesmo chip da família AIC8800, só que por um caminho USB interno, confirmado batendo o nó exato do device-tree. No fim, dongle nenhum era necessário.
- **Resiliência do `apt upgrade` validada no hardware real** — exatamente o problema que motivou o projeto inteiro, testado direto: upgrade completo de pacotes, reinício, HDMI e tudo mais continuando normal. (Um efeito colateral cosmético e inofensivo — uma entrada duplicada no menu de boot, criada pelo próprio `kernel-install` do systemd — teve a causa raiz encontrada e corrigida com um pequeno serviço que se autocorrige.)
- **Um kernel mais novo foi testado e rejeitado, de propósito.** Quando o bug de áudio (SoundWire) do Desktop apareceu, primeiro construímos e testamos o kernel 7.2.3 pra ver se resolvia. Não resolveu (apareceu um bug diferente no lugar), e ainda quebrou o HDMI de vez nessa placa — uma regressão que a própria equipe da Radxa já confirma e recomenda evitar. Revertemos em vez de entregar uma troca pior.
- **Áudio do Desktop: causa raiz encontrada de verdade, corrigida.** O que parecia ser uma corrida (race condition) irrecuperável do kernel mainline era, na real, mais simples: na imagem Desktop, o controlador SoundWire, os clocks das "macros" de codec do LPASS e o driver do codec WCD938x nunca são carregados sozinhos no boot, então o card ALSA nunca termina de se registrar (confirmado ao vivo: dar `modprobe` manual neles na ordem certa fez o card aparecer na hora, sem precisar de nenhum patch de kernel). Corrigido carregando esses módulos explicitamente via `systemd-modules-load.service` (ver [scripts/07d-fix-desktop-audio-soundwire.sh](scripts/07d-fix-desktop-audio-soundwire.sh)) — confirmado funcionando no hardware real, fone e HDMI, depois de um reboot limpo. Detalhes em [docs/pesquisa.md, seção 6.1](docs/pesquisa.md).
- **Um bug mais discreto, achado por acaso:** todo aparelho gravado com a mesma imagem estava saindo com o **mesmo `machine-id`** (gerado pelo `systemd` durante o `apt install` do build, nunca zerado depois) — corrigido zerando ele como último passo do build, cada aparelho gera o seu no primeiro boot.

O log técnico completo, sem cortes — cada beco sem saída, cada causa raiz, cada comando — está em [`docs/pesquisa.md`](docs/pesquisa.md). O histórico de commits conta a mesma história em ordem cronológica, se preferir ler assim.

### Estrutura do repositório

```
install.sh          instalador interativo, Linux (grava uma release pronta)
install_mac.sh       instalador interativo, macOS
scripts/build.sh     orquestrador interativo (constrói a partir do código-fonte)
scripts/             o pipeline de build de verdade, um script numerado por etapa
scripts/experiments/ coisas que tentamos e descartamos (mantidas pro registro)
docs/pesquisa.md     o log técnico completo de pesquisa
```

### Créditos

🤖 Parte deste projeto foi construída em par com [Claude Code](https://claude.com/claude-code).

### Licença

[MIT](LICENSE).

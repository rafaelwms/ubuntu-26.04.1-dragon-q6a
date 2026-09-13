## Ubuntu 26.04.1 LTS "Resolute Raccoon" for the Radxa Dragon Q6A — v1.1.0 (Desktop audio fix)

Custom Ubuntu 26.04.1 LTS images for the [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), fixing the problems the stock Radxa OS image has on this board: **HDMI breaking after `apt upgrade`**, and **audio never working at all**.

Full story, technical root causes, and every dead end we hit along the way: see the [README](../../blob/main/README.md) and [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### What's new in v1.1.0

**Desktop audio now works.** [v1.0.0](../../releases/tag/v1.0.0) shipped with a known limitation: audio didn't work on the Desktop (GNOME) image, believed at the time to be an unfixable upstream kernel race condition in the SoundWire bus. Live debugging on real hardware found the actual cause: the SoundWire controller, the LPASS codec-macro clocks, and the WCD938x codec driver simply never got autoloaded at boot on the Desktop image — no kernel bug, no patch needed. Fixed by explicitly loading those modules via `systemd-modules-load.service`. Confirmed working on real hardware after a clean reboot — audible on both the headphone jack and HDMI. Full writeup in [docs/pesquisa.md, section 9](../../blob/main/docs/pesquisa.md).

Only the **Desktop** image changed in this release. The **Server** image is unchanged from v1.0.0 (audio already worked there) — its files here are identical to v1.0.0's, re-published so both images stay together in one place.

### What's in this release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | same |
| HDMI | ✅ hardware-accelerated | ✅ same |
| Wi-Fi + Bluetooth | ✅ onboard, native | ✅ same |
| Audio | ✅ works (headphone + HDMI) | ✅ **now works too** (headphone + HDMI) |
| `apt upgrade` | ✅ confirmed does not break HDMI | ✅ same |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (native, no snap), `gnome-software` |

Default login: `radxa` / `radxa` — **change the password on first boot** (`passwd`). Root partition and machine identity are generated fresh on each device's first boot.

### Known limitation

The NPU (Hexagon DSP, AI acceleration) is out of scope — it depends on proprietary vendor blobs not available for the mainline kernel we use. Everything else (HDMI, Wi-Fi, Bluetooth, audio, `apt upgrade` resilience) is confirmed working on both images.

### How to install

Each image is split into parts (~1.4GB each) to fit GitHub's release asset limits — download **all parts of the image you want** (don't mix Server and Desktop parts), plus both `SHA256SUMS-*.txt` files, then either:

**Use the interactive installer** (recommended — verifies checksums, reassembles, and flashes for you, asking you to confirm the target device first):
```bash
git clone https://github.com/rafaelwms/ubuntu-26.04.1-dragon-q6a.git
cd ubuntu-26.04.1-dragon-q6a
./install.sh
```

**Or do it by hand:**
```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > image.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat image.img.xz | sudo dd of=/dev/YOUR_DEVICE bs=4M status=progress conv=fsync
```

⚠️ Triple-check the target device with `lsblk` first — this erases it completely.

---

## Ubuntu 26.04.1 LTS "Resolute Raccoon" para a Radxa Dragon Q6A — v1.1.0 (correção de áudio do Desktop)

Imagens customizadas de Ubuntu 26.04.1 LTS pra [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), corrigindo os problemas que a imagem stock da Radxa tem nessa placa: **o HDMI para de funcionar depois de um `apt upgrade`**, e **o áudio nunca funcionou**.

História completa, causas raiz técnicas e cada beco sem saída pelo caminho: ver o [README](../../blob/main/README.md) e [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### O que mudou na v1.1.0

**O áudio do Desktop agora funciona.** A [v1.0.0](../../releases/tag/v1.0.0) saiu com uma limitação conhecida: o áudio não funcionava na imagem Desktop (GNOME), que na época acreditávamos ser um bug de corrida do kernel sem solução no nosso escopo. Depurando ao vivo no hardware real, encontramos a causa de verdade: o controlador SoundWire, os clocks das "macros" de codec do LPASS e o driver do codec WCD938x simplesmente nunca eram carregados sozinhos no boot da imagem Desktop — nenhum bug de kernel, nenhum patch necessário. Corrigido carregando esses módulos explicitamente via `systemd-modules-load.service`. Confirmado funcionando no hardware real depois de um reboot limpo — audível tanto no fone de ouvido quanto no HDMI. Relato completo em [docs/pesquisa.md, seção 9](../../blob/main/docs/pesquisa.md).

Só a imagem **Desktop** mudou nesta release. A imagem **Server** continua idêntica à v1.0.0 (o áudio já funcionava nela) — os arquivos dela aqui são os mesmos da v1.0.0, republicados só pra manter as duas imagens juntas num único lugar.

### O que tem nesta release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | igual |
| HDMI | ✅ com aceleração de GPU | ✅ igual |
| Wi-Fi + Bluetooth | ✅ onboard, driver nativo | ✅ igual |
| Áudio | ✅ funciona (fone + HDMI) | ✅ **agora também funciona** (fone + HDMI) |
| `apt upgrade` | ✅ confirmado que não quebra o HDMI | ✅ igual |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (nativo, sem snap), `gnome-software` |

Login padrão: `radxa` / `radxa` — **troque a senha no primeiro boot** (`passwd`). A partição raiz e a identidade da máquina são geradas do zero no primeiro boot de cada aparelho.

### Limitação conhecida

A NPU (Hexagon DSP, aceleração de IA) está fora do escopo — depende de blobs proprietários do fabricante que não têm suporte maduro no kernel mainline que usamos. Todo o resto (HDMI, Wi-Fi, Bluetooth, áudio, resiliência do `apt upgrade`) está confirmado funcionando nas duas imagens.

### Como instalar

Cada imagem é dividida em partes (~1,4GB cada) pra caber no limite de tamanho de asset do GitHub — baixe **todas as partes da imagem que você quer** (não misture partes do Server com as do Desktop), mais os dois arquivos `SHA256SUMS-*.txt`, e então:

**Use o instalador interativo** (recomendado — confere os checksums, reconstrói a imagem, e grava, pedindo pra você confirmar o dispositivo de destino antes):
```bash
git clone https://github.com/rafaelwms/ubuntu-26.04.1-dragon-q6a.git
cd ubuntu-26.04.1-dragon-q6a
./install.sh
```

**Ou na mão:**
```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > imagem.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat imagem.img.xz | sudo dd of=/dev/SEU_DISPOSITIVO bs=4M status=progress conv=fsync
```

⚠️ Confira bem o dispositivo de destino com `lsblk` antes — isso apaga tudo nele.

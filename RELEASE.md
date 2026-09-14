## Ubuntu 26.04.1 LTS "Resolute Raccoon" for the Radxa Dragon Q6A — v1.2.0 (NPU runtime)

Custom Ubuntu 26.04.1 LTS images for the [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), fixing the problems the stock Radxa OS image has on this board: **HDMI breaking after `apt upgrade`**, and **audio never working at all**.

Full story, technical root causes, and every dead end we hit along the way: see the [README](../../blob/main/README.md) and [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### What's new in v1.2.0

**The NPU (Hexagon DSP, up to 12 TOPS) now has a working runtime out of the box** — both images. Previously undocumented territory, assumed out of scope due to "proprietary vendor blobs." Turned out the kernel-side integration (remoteproc, FastRPC, IOMMU) was already fully working in the mainline kernel we ship — nothing to fix there. What was actually missing was purely userspace: the FastRPC transport library (`libcdsprpc.so` — open source, [`quic/fastrpc`](https://github.com/quic/fastrpc), Qualcomm's own BSD-licensed release) and the DSP-side firmware, both now installed automatically via [`radxa-pkg`](https://github.com/radxa-pkg) packages.

**Confirmed live on real hardware**, not just theory: a Llama 3.2 1B model running actual text generation on the NPU (not falling back to CPU), via Qualcomm's Genie runtime. Full writeup, including the exact bugs found and fixed along the way, in [docs/pesquisa.md, section 10](../../blob/main/docs/pesquisa.md).

What ships in the image is the *runtime foundation* — kernel support, FastRPC, DSP firmware, permissions, all pre-configured. What doesn't ship (by design): Qualcomm's QAIRT SDK itself (~2GB of model-conversion tooling, free but requires a Qualcomm account) — that's a developer tool, not part of the OS, same reason phones don't ship the Android NDK. Grab it from [Qualcomm Software Center](https://softwarecenter.qualcomm.com) when you want to convert or run your own models.

Both **Server** and **Desktop** images were rebuilt for this release (unlike v1.1.0, which only touched Desktop) — the NPU runtime applies to both.

### What's in this release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | same |
| HDMI | ✅ hardware-accelerated | ✅ same |
| Wi-Fi + Bluetooth | ✅ onboard, native | ✅ same |
| Audio | ✅ works (headphone + HDMI) | ✅ same |
| NPU (Hexagon DSP, AI) | ✅ **runtime ready out of the box** (new) | ✅ same |
| `apt upgrade` | ✅ confirmed does not break HDMI | ✅ same |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (native, no snap), `gnome-software` |

Default login: `radxa` / `radxa` — **change the password on first boot** (`passwd`). Root partition and machine identity are generated fresh on each device's first boot.

### Known limitation

None outstanding. HDMI, Wi-Fi, Bluetooth, audio, NPU runtime, and `apt upgrade` resilience are all confirmed working on both images. Converting/running a *custom* AI model still requires downloading the QAIRT SDK separately (see above) — that's expected, not a bug.

### How to install

Each image is split into parts (~1.4GB each) to fit GitHub's release asset limits — download **all parts of the image you want** (don't mix Server and Desktop parts), plus both `SHA256SUMS-*.txt` files, then either:

**Use the interactive installer for your OS** (recommended — verifies checksums, reassembles, and flashes for you, asking you to confirm the target device first):
```bash
git clone https://github.com/rafaelwms/ubuntu-26.04.1-dragon-q6a.git
cd ubuntu-26.04.1-dragon-q6a
./install.sh       # Linux
./install_mac.sh   # macOS
```

**Or do it by hand (Linux):**
```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > image.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat image.img.xz | sudo dd of=/dev/YOUR_DEVICE bs=4M status=progress conv=fsync
```

⚠️ Triple-check the target device with `lsblk` first — this erases it completely.

---

## Ubuntu 26.04.1 LTS "Resolute Raccoon" para a Radxa Dragon Q6A — v1.2.0 (runtime da NPU)

Imagens customizadas de Ubuntu 26.04.1 LTS pra [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), corrigindo os problemas que a imagem stock da Radxa tem nessa placa: **o HDMI para de funcionar depois de um `apt upgrade`**, e **o áudio nunca funcionou**.

História completa, causas raiz técnicas e cada beco sem saída pelo caminho: ver o [README](../../blob/main/README.md) e [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### O que mudou na v1.2.0

**A NPU (Hexagon DSP, até 12 TOPS) agora tem runtime funcionando de fábrica** — nas duas imagens. Território antes tratado como fora de escopo, por supostamente depender de "blobs proprietários do fabricante". Na prática, a integração de kernel (remoteproc, FastRPC, IOMMU) já vinha funcionando de verdade no kernel mainline que já usávamos — nada pra corrigir ali. O que faltava de verdade era só userspace: a biblioteca de transporte FastRPC (`libcdsprpc.so` — open source, [`quic/fastrpc`](https://github.com/quic/fastrpc), publicada como BSD pela própria Qualcomm) e o firmware do lado do DSP, ambos agora instalados automaticamente via pacotes da [`radxa-pkg`](https://github.com/radxa-pkg).

**Confirmado ao vivo no hardware real**, não só na teoria: um modelo Llama 3.2 1B rodando geração de texto de verdade na NPU (não caindo pra CPU), via runtime Genie da Qualcomm. Relato completo, incluindo os bugs reais encontrados e corrigidos pelo caminho, em [docs/pesquisa.md, seção 10](../../blob/main/docs/pesquisa.md).

O que vem na imagem é a *fundação* do runtime — suporte de kernel, FastRPC, firmware do DSP, permissões, tudo pré-configurado. O que **não** vem (de propósito): o QAIRT SDK da Qualcomm em si (~2GB de ferramentas de conversão de modelo, grátis mas exige conta Qualcomm) — é ferramenta de desenvolvedor, não faz parte do SO, pelo mesmo motivo que celulares não vêm com o Android NDK embutido. Baixe em [Qualcomm Software Center](https://softwarecenter.qualcomm.com) quando quiser converter ou rodar seus próprios modelos.

As imagens **Server** e **Desktop** foram as duas reconstruídas nesta release (diferente da v1.1.0, que só mexeu no Desktop) — o runtime da NPU vale pras duas.

### O que tem nesta release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | igual |
| HDMI | ✅ com aceleração de GPU | ✅ igual |
| Wi-Fi + Bluetooth | ✅ onboard, driver nativo | ✅ igual |
| Áudio | ✅ funciona (fone + HDMI) | ✅ igual |
| NPU (Hexagon DSP, IA) | ✅ **runtime pronto de fábrica** (novo) | ✅ igual |
| `apt upgrade` | ✅ confirmado que não quebra o HDMI | ✅ igual |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (nativo, sem snap), `gnome-software` |

Login padrão: `radxa` / `radxa` — **troque a senha no primeiro boot** (`passwd`). A partição raiz e a identidade da máquina são geradas do zero no primeiro boot de cada aparelho.

### Limitação conhecida

Nenhuma pendente. HDMI, Wi-Fi, Bluetooth, áudio, runtime da NPU e resiliência do `apt upgrade` — tudo confirmado funcionando nas duas imagens. Converter/rodar um modelo de IA *customizado* ainda exige baixar o QAIRT SDK à parte (ver acima) — isso é esperado, não é bug.

### Como instalar

Cada imagem é dividida em partes (~1,4GB cada) pra caber no limite de tamanho de asset do GitHub — baixe **todas as partes da imagem que você quer** (não misture partes do Server com as do Desktop), mais os dois arquivos `SHA256SUMS-*.txt`, e então:

**Use o instalador interativo do seu sistema** (recomendado — confere os checksums, reconstrói a imagem, e grava, pedindo pra você confirmar o dispositivo de destino antes):
```bash
git clone https://github.com/rafaelwms/ubuntu-26.04.1-dragon-q6a.git
cd ubuntu-26.04.1-dragon-q6a
./install.sh       # Linux
./install_mac.sh   # macOS
```

**Ou na mão (Linux):**
```bash
sha256sum -c SHA256SUMS-parts.txt --ignore-missing
cat radxa-dragon-q6a_resolute_<server|desktop>_final.img.xz.part* > imagem.img.xz
sha256sum -c SHA256SUMS-full.txt --ignore-missing
xzcat imagem.img.xz | sudo dd of=/dev/SEU_DISPOSITIVO bs=4M status=progress conv=fsync
```

⚠️ Confira bem o dispositivo de destino com `lsblk` antes — isso apaga tudo nele.

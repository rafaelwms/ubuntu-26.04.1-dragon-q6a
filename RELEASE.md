## Ubuntu 26.04.1 LTS "Resolute Raccoon" for the Radxa Dragon Q6A — v1.2.1 (NPU access fix)

Custom Ubuntu 26.04.1 LTS images for the [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), fixing the problems the stock Radxa OS image has on this board: **HDMI breaking after `apt upgrade`**, and **audio never working at all**.

Full story, technical root causes, and every dead end we hit along the way: see the [README](../../blob/main/README.md) and [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### What's new in v1.2.1

**Patch release — fixes an NPU access gap found while using v1.2.0 on real hardware.** The NPU runtime itself (shipped in v1.2.0) was working correctly, but access to `/dev/fastrpc-*` was only granted to the default `radxa` user (via static group membership). Anyone who creates their own account and removes the default `radxa` user — a common setup step — was left without NPU access until manually running `usermod -aG fastrpc <user>`.

Fixed properly, not just patched around: a dedicated udev rule now grants dynamic access via `systemd-logind`'s `uaccess` mechanism — the same one that hands you the webcam, sound card, or a USB drive when you're logged in. **Whoever is logged into the console gets NPU access automatically, regardless of how or when their account was created.** No group membership, no manual step. See [docs/pesquisa.md, section 10.7](../../blob/main/docs/pesquisa.md).

Both **Server** and **Desktop** images were rebuilt for this release — the fix applies to both.

### What's in this release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | same |
| HDMI | ✅ hardware-accelerated | ✅ same |
| Wi-Fi + Bluetooth | ✅ onboard, native | ✅ same |
| Audio | ✅ works (headphone + HDMI) | ✅ same |
| NPU (Hexagon DSP, AI) | ✅ runtime ready out of the box, **access now works for any user** (fixed) | ✅ same |
| `apt upgrade` | ✅ confirmed does not break HDMI | ✅ same |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (native, no snap), `gnome-software` |

Default login: `radxa` / `radxa` — **change the password on first boot** (`passwd`). Root partition and machine identity are generated fresh on each device's first boot.

### Already on v1.2.0?

You only need this update if you plan to create your own user and remove the default `radxa` account. If so, apply the fix live instead of reflashing:
```bash
sudo curl -o /etc/udev/rules.d/61-fastrpc-uaccess.rules \
  https://raw.githubusercontent.com/rafaelwms/ubuntu-26.04.1-dragon-q6a/main/scripts/lib/61-fastrpc-uaccess.rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=misc --action=add
```

### Known limitation

None outstanding. HDMI, Wi-Fi, Bluetooth, audio, NPU runtime (and now access), and `apt upgrade` resilience are all confirmed working on both images. Converting/running a *custom* AI model still requires downloading the QAIRT SDK separately (free, Qualcomm account required) — that's expected, not a bug.

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

## Ubuntu 26.04.1 LTS "Resolute Raccoon" para a Radxa Dragon Q6A — v1.2.1 (correção de acesso à NPU)

Imagens customizadas de Ubuntu 26.04.1 LTS pra [Radxa Dragon Q6A](https://radxa.com/products/dragon/q6a/) (Qualcomm QCS6490), corrigindo os problemas que a imagem stock da Radxa tem nessa placa: **o HDMI para de funcionar depois de um `apt upgrade`**, e **o áudio nunca funcionou**.

História completa, causas raiz técnicas e cada beco sem saída pelo caminho: ver o [README](../../blob/main/README.md) e [docs/pesquisa.md](../../blob/main/docs/pesquisa.md).

### O que mudou na v1.2.1

**Release de correção — fecha um gap de acesso à NPU encontrado usando a v1.2.0 no hardware real.** O runtime da NPU em si (entregue na v1.2.0) funcionava certinho, mas o acesso a `/dev/fastrpc-*` só era concedido ao usuário `radxa` de fábrica (via grupo estático). Quem cria a própria conta e remove o `radxa` — passo comum de configuração — ficava sem acesso à NPU até rodar `usermod -aG fastrpc <user>` manualmente.

Corrigido de verdade, não só contornado: uma regra udev própria agora concede acesso dinâmico via o mecanismo `uaccess` do `systemd-logind` — o mesmo que libera webcam, placa de som ou um pendrive USB pra quem está logado. **Quem estiver logado no console ganha acesso à NPU automaticamente, não importa como ou quando a conta foi criada.** Sem grupo, sem passo manual. Ver [docs/pesquisa.md, seção 10.7](../../blob/main/docs/pesquisa.md).

As imagens **Server** e **Desktop** foram as duas reconstruídas nesta release — a correção vale pras duas.

### O que tem nesta release

| | Server | Desktop |
|---|---|---|
| Kernel | 6.18.2 (mainline, via Armbian) | igual |
| HDMI | ✅ com aceleração de GPU | ✅ igual |
| Wi-Fi + Bluetooth | ✅ onboard, driver nativo | ✅ igual |
| Áudio | ✅ funciona (fone + HDMI) | ✅ igual |
| NPU (Hexagon DSP, IA) | ✅ runtime pronto de fábrica, **acesso agora funciona pra qualquer usuário** (corrigido) | ✅ igual |
| `apt upgrade` | ✅ confirmado que não quebra o HDMI | ✅ igual |
| Extras | — | GNOME (`ubuntu-desktop-minimal`), Firefox (nativo, sem snap), `gnome-software` |

Login padrão: `radxa` / `radxa` — **troque a senha no primeiro boot** (`passwd`). A partição raiz e a identidade da máquina são geradas do zero no primeiro boot de cada aparelho.

### Já está na v1.2.0?

Você só precisa desta atualização se pretende criar seu próprio usuário e remover a conta `radxa` padrão. Se for o caso, aplique a correção ao vivo em vez de regravar a imagem:
```bash
sudo curl -o /etc/udev/rules.d/61-fastrpc-uaccess.rules \
  https://raw.githubusercontent.com/rafaelwms/ubuntu-26.04.1-dragon-q6a/main/scripts/lib/61-fastrpc-uaccess.rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=misc --action=add
```

### Limitação conhecida

Nenhuma pendente. HDMI, Wi-Fi, Bluetooth, áudio, runtime da NPU (e agora o acesso) e resiliência do `apt upgrade` — tudo confirmado funcionando nas duas imagens. Converter/rodar um modelo de IA *customizado* ainda exige baixar o QAIRT SDK à parte (grátis, exige conta Qualcomm) — isso é esperado, não é bug.

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

#!/bin/bash
# ============================================================
# Script de Pós-instalação Ubuntu 24.04 - Ambiente GiuSoft
# Autor: Ornan S. C. Matos
# Descrição:
#   - Atualiza repositórios e instala pacotes essenciais
#   - Configura repositório Google Chrome
#   - Instala ferramentas multimídia e LibreOffice em pt-BR
#   - Cria grupo 'powerusers' com permissões especiais via polkit
#   - Instala e configura RustDesk com bloqueio de preferências
#   - Copia configs padrão para novos usuários via /etc/profile.d
#   - Instala e habilita Tailscale
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft ==="

# ------------------------------------------------------------
# 1. Atualiza sistema e garante conectividade
# ------------------------------------------------------------
echo "[INFO] Atualizando pacotes base..."
apt update -y
apt install -y wget curl gpg software-properties-common apt-transport-https ca-certificates

# ------------------------------------------------------------
# 2. Habilita repositórios adicionais
# ------------------------------------------------------------
echo "[INFO] Habilitando repositórios universe/multiverse/restricted..."
add-apt-repository -y universe
add-apt-repository -y multiverse
add-apt-repository -y restricted
apt update -y

# ------------------------------------------------------------
# 3. Configura repositório Google Chrome
# ------------------------------------------------------------
echo "[INFO] Configurando repositório do Google Chrome..."
mkdir -p /etc/apt/keyrings
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt update -y

# ------------------------------------------------------------
# 4. Aceita EULA das fontes Microsoft
# ------------------------------------------------------------
echo "[INFO] Aceitando EULA das fontes Microsoft..."
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

# ------------------------------------------------------------
# 5. Instala pacotes principais
# ------------------------------------------------------------
echo "[INFO] Instalando pacotes essenciais..."
apt install -y \
    google-chrome-stable \
    git \
    vim \
    openssh-server \
    freeipa-client \
    oddjob-mkhomedir \
    ubuntu-restricted-extras \
    ffmpeg \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    gstreamer1.0-x \
    gstreamer1.0-alsa \
    gstreamer1.0-pulseaudio \
    flatpak \
    libreoffice-l10n-pt-br \
    libreoffice-help-pt-br \
    hunspell-pt-br

# ------------------------------------------------------------
# 6. Instala RustDesk
# ------------------------------------------------------------
echo "[INFO] Instalando RustDesk..."
RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.4.3/rustdesk-1.4.3-x86_64.deb"
wget -q "$RUSTDESK_URL" -O /tmp/rustdesk.deb
apt install -y /tmp/rustdesk.deb
rm -f /tmp/rustdesk.deb

# ------------------------------------------------------------
# 7. Configuração do RustDesk (bloqueio e template)
# ------------------------------------------------------------
echo "[INFO] Criando configuração padrão e bloqueio do RustDesk..."

RUSTDESK_DIR="/etc/skel/.config/rustdesk"
mkdir -p "$RUSTDESK_DIR"

cat > "$RUSTDESK_DIR/RustDesk2.toml" <<'EOF'
[options]
relay-server = "block.ornan.duckdns.org"
enable-clipboard = true
enable-audio = true
start-with-system = true
minimize-to-tray = true
EOF

# Bloqueia alterações no arquivo global
chmod 444 "$RUSTDESK_DIR/RustDesk2.toml"

# Copia configs para usuários existentes
for userhome in /home/*; do
    if [ -d "$userhome" ]; then
        mkdir -p "$userhome/.config/rustdesk"
        cp -n "$RUSTDESK_DIR/RustDesk2.toml" "$userhome/.config/rustdesk/"
        chown -R "$(basename "$userhome"):$(basename "$userhome")" "$userhome/.config/rustdesk"
    fi
done

# ------------------------------------------------------------
# 8. Cria script /etc/profile.d para novos usuários
# ------------------------------------------------------------
echo "[INFO] Criando script para copiar configs RustDesk no primeiro login..."

cat > /etc/profile.d/copy-rustdesk-config.sh <<'EOF'
#!/bin/bash
CONFIG_DIR="$HOME/.config/rustdesk"
TEMPLATE_DIR="/etc/skel/.config/rustdesk"
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    cp -n "$TEMPLATE_DIR/"* "$CONFIG_DIR/" 2>/dev/null || true
    echo "[INFO] Configuração do RustDesk copiada para $CONFIG_DIR"
fi
EOF
chmod 755 /etc/profile.d/copy-rustdesk-config.sh

# ------------------------------------------------------------
# 9. Cria grupo powerusers e regra polkit
# ------------------------------------------------------------
echo "[INFO] Criando grupo powerusers e regra polkit..."
groupadd -f powerusers
cat > /etc/polkit-1/rules.d/40-regras-personalizadas.rules <<'EOF'
/* Permite que usuários no grupo 'powerusers' desliguem/reiniciem sem senha */
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.reboot") &&
        subject.isInGroup("powerusers")) {
        return polkit.Result.YES;
    }
});
EOF
chmod 644 /etc/polkit-1/rules.d/40-regras-personalizadas.rules

# ------------------------------------------------------------
# 10. Instala e habilita Tailscale
# ------------------------------------------------------------
echo "[INFO] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | bash
systemctl enable --now tailscaled

# ------------------------------------------------------------
# 11. Habilita SSH
# ------------------------------------------------------------
echo "[INFO] Habilitando SSH..."
systemctl enable --now ssh

# ------------------------------------------------------------
# Finalização
# ------------------------------------------------------------
echo "=== Pós-instalação concluída com sucesso ==="
echo "Log salvo em: $LOGFILE"

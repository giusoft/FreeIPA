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
    hunspell-pt-br \
    sssd \
    oddjob \
    oddjob-mkhomedir \
    adcli \
    realmd \
    libnss-sss \
    libpam-sss \
    sssd-tools \
    netcat-openbsd \
    iputils-ping \
    fio \
    iperf3 \
    stress \
    stress-ng \
    glmark2-es2-drm \
    glmark2 \
    mesa-utils \
    mesa-utils-extra \
    libdrm-dev \
    lm-sensors \
    htop \
    dconf-cli
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

# Detecta o IP local automaticamente (ignora loopback e docker)
LOCAL_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127/ && $i !~ /^172\.17/ && $i !~ /^172\.18/) {print $i; exit}}')
RUSTDESK_DIR="/etc/skel/.config/rustdesk"
GLOBAL_RUSTDESK_DIR="/etc/rustdesk"
mkdir -p "$RUSTDESK_DIR" "$GLOBAL_RUSTDESK_DIR"

cat > "$RUSTDESK_DIR/RustDesk2.toml" <<EOF
[options]
relay-server = "block.ornan.duckdns.org"
enable-clipboard = true
enable-audio = true
start-with-system = true
minimize-to-tray = true
enable-nat-traversal = false
direct-ips = ["${LOCAL_IP}/24"]
direct-server = "${LOCAL_IP}"
direct-port = 21118
ask-for-authorization = true
one-click-approve = true
one-click-mode = true
use-public-server = false
api-server = ""
key = ""
show-tray-icon = true
EOF

chmod 444 "$RUSTDESK_DIR/RustDesk2.toml"
cp -f "$RUSTDESK_DIR/RustDesk2.toml" "$GLOBAL_RUSTDESK_DIR/RustDesk2.toml"
chmod 444 "$GLOBAL_RUSTDESK_DIR/RustDesk2.toml"

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
# 12. Configura Repositório e Wallpaper Corporativo
# ------------------------------------------------------------
echo "[INFO] Clonando repositório GiuSoft..."
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
WALLPAPER_FILE="$GIT_REPO_DIR/Wallpaper.png"
mkdir -p /opt/giusoft

# Clona o repositório se não existir, ou atualiza se já existir
if [ -d "$GIT_REPO_DIR/.git" ]; then
    echo "[INFO] Repositório existente. Atualizando..."
    (cd "$GIT_REPO_DIR" && git pull)
else
    echo "[INFO] Repositório não encontrado. Clonando..."
    git clone https://github.com/giusoft/FreeIPA.git "$GIT_REPO_DIR"
fi

# ------------------------------------------------------------
# 13. Cria script de atualização e agendamento (Cron)
# ------------------------------------------------------------
echo "[INFO] Criando script de atualização mensal do repositório..."
UPDATE_SCRIPT="/usr/local/bin/update-giusoft-repo.sh"

cat > "$UPDATE_SCRIPT" <<'EOF'
#!/bin/bash
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
LOGFILE="/var/log/update-giusoft-repo.log"

echo "=== $(date): Iniciando atualização do repositório ===" >> "$LOGFILE"
if [ -d "$GIT_REPO_DIR/.git" ]; then
    (cd "$GIT_REPO_DIR" && git pull) >> "$LOGFILE" 2>&1
    echo "=== Atualização concluída ===" >> "$LOGFILE"
else
    echo "ERRO: Diretório $GIT_REPO_DIR não parece ser um repositório git." >> "$LOGFILE"
    exit 1
fi
EOF

chmod +x "$UPDATE_SCRIPT"

echo "[INFO] Criando agendamento via cron (todo dia 01 às 10:00)..."
cat > /etc/cron.d/giusoft-repo-update <<'EOF'
# Atualiza o repositório GiuSoft mensalmente
0 10 1 * * root /usr/local/bin/update-giusoft-repo.sh
EOF

# ------------------------------------------------------------
# 14. Define e Bloqueia o Papel de Parede (dconf)
# ------------------------------------------------------------
echo "[INFO] Configurando e bloqueando o papel de parede padrão..."

# Cria o perfil 'local' do dconf para aplicar a todos os usuários
DCONF_DB_DIR="/etc/dconf/db/local.d"
DCONF_LOCK_DIR="/etc/dconf/db/local.d/locks"
mkdir -p "$DCONF_DB_DIR"
mkdir -p "$DCONF_LOCK_DIR"

# Define o papel de parede padrão (modos claro e escuro)
cat > "$DCONF_DB_DIR/01-giusoft-wallpaper" <<EOF
[org/gnome/desktop/background]
picture-uri='file://$WALLPAPER_FILE'
picture-uri-dark='file://$WALLPAPER_FILE'
picture-options='zoom'
EOF

# Bloqueia a alteração do papel de parede
cat > "$DCONF_LOCK_DIR/01-giusoft-wallpaper" <<EOF
# Impede que usuários alterem o papel de parede
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/background/picture-options
EOF

# Aplica as alterações no banco de dados do dconf
echo "[INFO] Atualizando banco de dados dconf..."
dconf update

# ------------------------------------------------------------
# 15. Garante permissões corretas no Wallpaper
# ------------------------------------------------------------
echo "[INFO] Ajustando permissões do arquivo de wallpaper..."
if [ -f "$WALLPAPER_FILE" ]; then
    chmod 644 "$WALLPAPER_FILE"
else
    echo "[WARN] Arquivo $WALLPAPER_FILE não encontrado! O wallpaper não será aplicado."
fi

# (Aqui vem a seção de Finalização que já existe no seu script)

# ------------------------------------------------------------
# Finalização
# ------------------------------------------------------------
echo "[FINALIZADO] Script concluído com sucesso."
echo "------------------------------------------------------------"
echo "Próximos passos manuais recomendados:"
echo ""
echo "1. Fazer o join no FreeIPA (ipa.gs.internal):"
echo "   =========================================="
echo "   # Se caso exista, desinstale restos da tentativa anterior:"
echo "   sudo ipa-client-install --uninstall -U"
echo ""
echo "   # Agora rode o join diretamente:"
echo "   sudo ipa-client-install \\"
echo "     --mkhomedir \\"
echo "     --no-ntp \\"
echo "     --server=ipa.gs.internal \\"
echo "     --domain=gs.internal \\"
echo "     --principal=admin"
echo ""
echo "2. Autentique o Tailscale:"
echo "   sudo tailscale up"
echo ""
echo "3. Adicione usuários ao grupo 'powerusers' (se necessário):"
echo "   sudo usermod -aG powerusers nome_do_usuario"
echo "------------------------------------------------------------"
echo "=== Pós-instalação concluída com sucesso ==="
echo "Log salvo em: $LOGFILE"

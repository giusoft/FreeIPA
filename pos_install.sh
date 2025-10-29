#!/bin/bash
# ============================================================
# Script de Pós-instalação Ubuntu 24.04 - Ambiente GiuSoft
# Autor: Ornan S. C. Matos
#
# Descrição Unificada (v2):
#   - Atualiza repositórios e instala pacotes essenciais
#   - Configura repositórios (Google Chrome, ownCloud Client)
#   - Clona repositório GiuSoft e instala pacotes (Zoiper, RustDesk)
#   - Instala e ativa a extensão GNOME 'activate_gnome' system-wide
#   - Cria script de info (IP/Hostname) para a extensão
#   - Cria grupo 'powerusers' com permissões especiais via polkit
#   - Configura RustDesk com bloqueio de preferências
#   - Configura e bloqueia o wallpaper corporativo via dconf
#   - Cria cron job para atualizar o wallpaper mensalmente
#   - Oculta aplicações desnecessárias do menu
#   - Instala e habilita Tailscale e SSH
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft ==="
echo "Log será salvo em: $LOGFILE"

# ------------------------------------------------------------
# 1. Atualiza sistema e garante conectividade
# ------------------------------------------------------------
echo "[INFO] Atualizando pacotes base..."
apt update -y
apt install -y wget curl gpg software-properties-common apt-transport-https ca-certificates git

# ------------------------------------------------------------
# 2. Habilita repositórios adicionais
# ------------------------------------------------------------
echo "[INFO] Habilitando repositórios universe/multiverse/restricted..."
add-apt-repository -y universe
add-apt-repository -y multiverse
add-apt-repository -y restricted

# ------------------------------------------------------------
# 3. Configura repositório Google Chrome
# ------------------------------------------------------------
echo "[INFO] Configurando repositório do Google Chrome..."
mkdir -p /etc/apt/keyrings
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# ------------------------------------------------------------
# 4. Configura repositório ownCloud Client
# ------------------------------------------------------------
echo "[INFO] Configurando repositório do ownCloud Client..."
wget -nv https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Ubuntu_24.04/Release.key -O - | gpg --dearmor | tee /etc/apt/trusted.gpg.d/owncloud-client.gpg > /dev/null
echo 'deb https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Ubuntu_24.04/ /' | tee -a /etc/apt/sources.list.d/owncloud-client.list

# ------------------------------------------------------------
# 5. Aceita EULA das fontes Microsoft
# ------------------------------------------------------------
echo "[INFO] Aceitando EULA das fontes Microsoft..."
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

# ------------------------------------------------------------
# 6. Atualiza APT após adicionar novos repos
# ------------------------------------------------------------
echo "[INFO] Atualizando lista de pacotes..."
apt update -y

# ------------------------------------------------------------
# 7. Clona Repositório GiuSoft (Necessário para Zoiper e Wallpaper)
# ------------------------------------------------------------
echo "[INFO] Clonando repositório GiuSoft..."
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
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
# 8. Instala Zoiper 5 (do Repositório GiuSoft)
# ------------------------------------------------------------
echo "[INFO] Instalando Zoiper 5 do repositório GiuSoft..."
ZOIPER_DEB_PATH="$GIT_REPO_DIR/Zoiper.deb"

if [ -f "$ZOIPER_DEB_PATH" ]; then
    echo "[INFO] Arquivo Zoiper.deb encontrado. Instalando..."
    apt install -y "$ZOIPER_DEB_PATH"
else
    echo "[AVISO] $ZOIPER_DEB_PATH não encontrado no repositório."
    echo "[AVISO] Pulei a instalação do Zoiper."
fi

# ------------------------------------------------------------
# 9. Instala RustDesk
# ------------------------------------------------------------
echo "[INFO] Instalando RustDesk..."
RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.4.3/rustdesk-1.4.3-x86_64.deb"
wget -q "$RUSTDESK_URL" -O /tmp/rustdesk.deb
apt install -y /tmp/rustdesk.deb
rm -f /tmp/rustdesk.deb

# ------------------------------------------------------------
# 10. Instala Extensão GNOME 'activate_gnome'
# ------------------------------------------------------------
echo "[INFO] Instalando extensão GNOME 'activate_gnome' system-wide..."
EXTENSION_UUID="activate_gnome@r-pr"
EXTENSION_DIR="/usr/share/gnome-shell/extensions/$EXTENSION_UUID"
EXTENSION_REPO="https://github.com/PR-l/activate_gnome.git"
TMP_REPO_DIR="/tmp/activate_gnome"

if [ -d "$EXTENSION_DIR" ]; then
    echo "[INFO] Extensão 'activate_gnome' já parece estar instalada. Pulando."
else
    git clone "$EXTENSION_REPO" "$TMP_REPO_DIR"
    mkdir -p "$EXTENSION_DIR"
    cp -r "$TMP_REPO_DIR/." "$EXTENSION_DIR/"
    chmod -R 755 "$EXTENSION_DIR"
    
    # Compila os schemas (crucial para a extensão ser reconhecida)
    if [ -f "$EXTENSION_DIR/schemas/org.gnome.shell.extensions.activate_gnome.gschema.xml" ]; then
        echo "[INFO] Compilando schemas da extensão..."
        glib-compile-schemas "$EXTENSION_DIR/schemas/"
    else
        echo "[WARN] Arquivo de schema não encontrado. A extensão pode não funcionar."
    fi
    rm -rf "$TMP_REPO_DIR"
    echo "[INFO] Extensão 'activate_gnome' instalada."
fi

# ------------------------------------------------------------
# 11. Cria script de info para a extensão 'activate_gnome'
# ------------------------------------------------------------
echo "[INFO] Criando script de informações em /usr/local/bin/activate_gnome_script.sh"
cat > /usr/local/bin/activate_gnome_script.sh <<'EOF'
#!/bin/bash
HOST=$(hostname)
IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127/ && $i !~ /^172\.17/ && $i !~ /^172\.18/) {print $i; exit}}')

# Fallback se o IP estiver vazio (ex: sem rede, só loopback)
if [ -z "$IP" ]; then
    IP=$(hostname -I | awk '{print $1}') # Pega o primeiro IP que encontrar
fi
if [ -z "$IP" ]; then
    IP="N/A" # Caso extremo
fi

# Gera o JSON que a extensão espera
echo "{\"text\": \"$HOST ($IP)\", \"tooltip\": \"Hostname: $HOST\nIP: $IP\", \"class\": \"activate_gnome_class\"}"
EOF
chmod +x /usr/local/bin/activate_gnome_script.sh

# ------------------------------------------------------------
# 12. Instala pacotes principais (ownCloud, Chrome e outros)
# ------------------------------------------------------------
echo "[INFO] Instalando pacotes essenciais..."
apt install -y \
    google-chrome-stable \
    owncloud-client \
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
    libreoffice \
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
    dconf-cli \
    gnome-shell-extension-prefs \
    thunderbird

# ------------------------------------------------------------
# 13. Configuração do RustDesk (bloqueio e template)
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
# 14. Cria script /etc/profile.d para novos usuários
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
# 15. Cria grupo powerusers e regra polkit
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
# 16. Instala e habilita Tailscale
# ------------------------------------------------------------
echo "[INFO] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | bash
systemctl enable --now tailscaled

# ------------------------------------------------------------
# 17. Habilita SSH
# ------------------------------------------------------------
echo "[INFO] Habilitando SSH..."
systemctl enable --now ssh

# ============================================================
# INÍCIO DA SEÇÃO DE WALLPAPER E EXTENSÕES (DCONF)
# ============================================================

# ------------------------------------------------------------
# 18. Cria script de atualização e agendamento (Cron)
# ------------------------------------------------------------
echo "[INFO] Criando script de atualização mensal do wallpaper..."
UPDATE_SCRIPT="/usr/local/bin/update-giusoft-wallpaper.sh"
UPDATE_LOGFILE="/var/log/update-giusoft-wallpaper.log"

# Define o arquivo de origem e destino do wallpaper
WALLPAPER_SRC_FILE="$GIT_REPO_DIR/Wallpaper.png"
WALLPAPER_DEST_FILE="/usr/share/backgrounds/giusoft/Wallpaper.png"

cat > "$UPDATE_SCRIPT" <<EOF
#!/bin/bash
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
LOGFILE="$UPDATE_LOGFILE"

echo "=== \$(date): Iniciando atualização do repositório/wallpaper ===" >> "\$LOGFILE"
if [ -d "\$GIT_REPO_DIR/.git" ]; then
    (cd "\$GIT_REPO_DIR" && git pull) >> "\$LOGFILE" 2>&1
    
    # Atualiza a cópia do wallpaper se ele mudou
    WALLPAPER_SRC_FILE="\$GIT_REPO_DIR/Wallpaper.png"
    WALLPAPER_DEST_FILE="/usr/share/backgrounds/giusoft/Wallpaper.png"
    if [ -f "\$WALLPAPER_SRC_FILE" ]; then
        cp -f "\$WALLPAPER_SRC_FILE" "\$WALLPAPER_DEST_FILE"
        chmod 644 "\$WALLPAPER_DEST_FILE"
    fi
    
    echo "=== Atualização concluída ===" >> "\$LOGFILE"
else
    echo "ERRO: Diretório \$GIT_REPO_DIR não parece ser um repositório git." >> "\$LOGFILE"
    exit 1
fi
EOF

chmod +x "$UPDATE_SCRIPT"

echo "[INFO] Criando agendamento via cron (todo dia 01 às 10:00)..."
cat > /etc/cron.d/giusoft-wallpaper-update <<'EOF'
# Atualiza o repositório e wallpaper GiuSoft mensalmente
0 10 1 * * root /usr/local/bin/update-giusoft-wallpaper.sh
EOF

# ------------------------------------------------------------
# 19. Define e Bloqueia o Papel de Parede e Extensões (dconf)
# ------------------------------------------------------------
echo "[INFO] Configurando e bloqueando o papel de parede e extensões padrão..."

# Cria os diretórios para as regras e travas
DCONF_DB_DIR="/etc/dconf/db/local.d"
DCONF_LOCK_DIR="/etc/dconf/db/local.d/locks"
mkdir -p "$DCONF_DB_DIR"
mkdir -p "$DCONF_LOCK_DIR"

# --- Perfil de Wallpaper ---
cat > "$DCONF_DB_DIR/01-giusoft-wallpaper" <<EOF
[org/gnome/desktop/background]
picture-uri='file://$WALLPAPER_DEST_FILE'
picture-uri-dark='file://$WALLPAPER_DEST_FILE'
picture-options='zoom'
EOF

# --- Trava do Wallpaper ---
cat > "$DCONF_LOCK_DIR/01-giusoft-wallpaper" <<EOF
# Impede que usuários alterem o papel de parede
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/background/picture-options
EOF

# --- Perfil de Extensão (NOVO) ---
cat > "$DCONF_DB_DIR/02-giusoft-extensions" <<EOF
[org/gnome/shell]
# Ativa a extensão 'activate_gnome' para todos os usuários
enabled-extensions=['activate_gnome@r-pr']
EOF

# --- Trava da Extensão (NOVO) ---
cat > "$DCONF_LOCK_DIR/02-giusoft-extensions" <<EOF
# Impede que usuários modifiquem a lista de extensões ativadas
/org/gnome/shell/enabled-extensions
EOF

# --- INÍCIO DA CORREÇÃO DE PERFIL DCONF ---
echo "[INFO] Garantindo a existência do perfil dconf 'user'..."
mkdir -p /etc/dconf/profile/
tee /etc/dconf/profile/user > /dev/null <<'EOF'
user-db:user
system-db:local
system-db:site
EOF
# --- FIM DA CORREÇÃO ---

# Aplica as alterações no banco de dados do dconf
echo "[INFO] Atualizando banco de dados dconf..."
dconf update

# ------------------------------------------------------------
# 20. Garante permissões corretas no Wallpaper
# ------------------------------------------------------------
echo "[INFO] Copiando e ajustando permissões do arquivo de wallpaper..."
mkdir -p "$(dirname "$WALLPAPER_DEST_FILE")"
if [ -f "$WALLPAPER_SRC_FILE" ]; then
    cp -f "$WALLPAPER_SRC_FILE" "$WALLPAPER_DEST_FILE"
    chmod 644 "$WALLPAPER_DEST_FILE"
else
    echo "[WARN] Arquivo fonte $WALLPAPER_SRC_FILE não encontrado! O wallpaper não será aplicado."
fi

# ============================================================
# FIM DA SEÇÃO DE WALLPAPER E EXTENSÕES
# ============================================================


# ------------------------------------------------------------
# 21. Oculta Aplicações do Menu (NoDisplay)
# ------------------------------------------------------------
echo "[INFO] Ocultando aplicações desnecessárias do menu..."

# Lista de arquivos .desktop que serão ocultados
HIDDEN_APPS=(
    "apport-gtk.desktop"
    "bluetooth-sendto.desktop"
    "gcr-prompter.desktop"
    "gcr-viewer.desktop"
    "geoclue-demo-agent.desktop"
    "gkbd-keyboard-display.desktop"
    "gnome-about-panel.desktop"
    "gnome-applications-panel.desktop"
    "gnome-background-panel.desktop"
    "gnome-bluetooth-panel.desktop"
    "gnome-color-panel.desktop"
    "gnome-datetime-panel.desktop"
    "gnome-disk-image-mounter.desktop"
    "gnome-disk-image-writer.desktop"
    "gnome-display-panel.desktop"
    "gnome-initial-setup.desktop"
    "gnome-keyboard-panel.desktop"
    "gnome-language-selector.desktop"
    "gnome-mouse-panel.desktop"
    "gnome-multitasking-panel.desktop"
    "gnome-network-panel.desktop"
    "gnome-notifications-panel.desktop"
    "gnome-online-accounts-panel.desktop"
    "gnome-power-panel.desktop"
    "gnome-printers-panel.desktop"
    "gnome-privacy-panel.desktop"
    "gnome-region-panel.desktop"
    "gnome-search-panel.desktop"
    "gnome-session-properties.desktop"
    "gnome-sharing-panel.desktop"
    "gnome-sound-panel.desktop"
    "gnome-system-monitor-kde.desktop"
    "gnome-system-panel.desktop"
    "gnome-ubuntu-panel.desktop"
    "gnome-universal-access-panel.desktop"
    "gnome-users-panel.desktop"
    "gnome-wacom-panel.desktop"
    "gnome-wifi-panel.desktop"
    "gnome-wwan-panel.desktop"
    "hplj1020.desktop"
    "htop.desktop"
    "ibus-setup-chewing.desktop"
    "ibus-setup-libbopomofo.desktop"
    "ibus-setup-libpinyin.desktop"
    "ibus-setup-m17n.desktop"
    "ibus-setup-table.desktop"
    "im-config.desktop"
    "info.desktop"
    "io.snapcraft.SessionAgent.desktop"
    "libreoffice-startcenter.desktop"
    "libreoffice-xsltfilter.desktop"
    "nautilus-autorun-software.desktop"
    "nm-applet.desktop"
    "nm-connection-editor.desktop"
    "nvim.desktop"
    "org.freedesktop.IBus.Panel.Emojier.desktop"
    "org.freedesktop.IBus.Panel.Extension.Gtk3.desktop"
    "org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop"
    "org.freedesktop.IBus.Setup.desktop"
    "org.freedesktop.Xwayland.desktop"
    "org.gnome.Characters.desktop"
    "org.gnome.DiskUtility.desktop"
    "org.gnome.Evince-previewer.desktop"
    "org.gnome.Evince.desktop"
    "org.gnome.Evolution-alarm-notify.desktop"
    "org.gnome.Logs.desktop"
    "org.gnome.OnlineAccounts.OAuth2.desktop"
    "org.gnome.PowerStats.desktop"
    "org.gnome.RemoteDesktop.Handover.desktop"
    "org.gnome.Shell.Extensions.desktop"
    "org.gnome.Shell.desktop"
    "org.gnome.SystemMonitor.desktop"
    "org.gnome.Tecla.desktop"
    "org.gnome.Terminal.Preferences.desktop"
    "org.gnome.Zenity.desktop"
    "org.gnome.baobab.desktop"
    "org.gnome.eog.desktop"
    "org.gnome.evolution-data-server.OAuth2-handler.desktop"
    "org.gnome.font-viewer.desktop"
    "org.gnome.seahorse.Application.desktop"
    "python3.12.desktop"
    "rygel.desktop"
    "snap-handle-link.desktop"
    "software-properties-drivers.desktop"
    "software-properties-gtk.desktop"
    "software-properties-livepatch.desktop"
    "update-manager.desktop"
    "vim.desktop"
    "xdg-desktop-portal-gnome.desktop"
    "xdg-desktop-portal-gtk.desktop"
    "yelp.desktop"
)

# 1. Prepara o /etc/skel para futuros usuários
SKEL_APP_DIR="/etc/skel/.local/share/applications"
mkdir -p "$SKEL_APP_DIR"

for app in "${HIDDEN_APPS[@]}"; do
    echo "[Desktop Entry]" > "$SKEL_APP_DIR/$app"
    echo "NoDisplay=true" >> "$SKEL_APP_DIR/$app"
done

# 2. Aplica aos usuários existentes em /home
echo "[INFO] Aplicando ocultação de apps aos usuários existentes em /home..."
for userhome in /home/*; do
    if [ -d "$userhome" ]; then
        USER_APP_DIR="$userhome/.local/share/applications"
        mkdir -p "$USER_APP_DIR"
        
        # Copia todos os arquivos de override
        cp -f "$SKEL_APP_DIR/"*.desktop "$USER_APP_DIR/"
        
        # Corrige as permissões da pasta
        chown -R "$(basename "$userhome"):$(basename "$userhome")" "$userhome/.local"
    fi
done


# ------------------------------------------------------------
# Finalização
#

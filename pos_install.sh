#!/bin/bash
# ============================================================
# Script de Pós-instalação Ubuntu 24.04 - Ambiente GiuSoft
# Autor: Ornan S. Matos
#
# Descrição Unificada (v11 - Correção de typo):
#   - (v10) Altera a fonte da extensão para o repositório
#     'ornan-matos/gnome-shell-extension-hostnameIP'.
#   - (v11) Corrige erro de digitação na variável 
#     'WALLPAYPER_DEST_FILE' (agora 'WALLPAPER_DEST_FILE')
#     na Seção 20 (dconf wallpaper).
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft ==="
echo "Log será salvo em: $LOGFILE"

# ------------------------------------------------------------
# 1. Atualiza sistema e garante conectividade (Dependências do ext.sh adicionadas)
# ------------------------------------------------------------
echo "[INFO] Atualizando pacotes base e instalando dependências..."
apt update -y
# Adicionado 'jq' (para ext.sh) e 'libglib2.0-dev-bin' (para glib-compile-schemas)
apt install -y wget curl gpg software-properties-common apt-transport-https \
    ca-certificates git unzip gnome-shell-extensions jq libglib2.0-dev-bin

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
# 7. Clona Repositório GiuSoft (Necessário para Zoiper, Wallpaper e Logo GDM)
# ------------------------------------------------------------
echo "[INFO] Clonando repositório GiuSoft (Zoiper, Wallpaper, Logo)..."
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
mkdir -p /opt/giusoft

# Clona o repositório se não existir, ou atualiza se já existir
if [ -d "$GIT_REPO_DIR/.git" ]; then
    echo "[INFO] Repositório GiuSoft existente. Atualizando..."
    (cd "$GIT_REPO_DIR" && git pull)
else
    echo "[INFO] Repositório GiuSoft não encontrado. Clonando..."
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
# 10. Instala Extensão GNOME 'hostnameIP' (Lógica ATUALIZADA)
# ------------------------------------------------------------
echo "[INFO] Clonando e instalando extensão GNOME 'hostnameIP' system-wide..."

# --- 10a. Clonar o repositório da extensão ---
EXT_REPO_URL="https://github.com/ornan-matos/gnome-shell-extension-hostnameIP.git"
EXT_REPO_DIR="/opt/hostnameIP-ext" # Novo diretório de clone

if [ -d "$EXT_REPO_DIR/.git" ]; then
    echo "[INFO] Repositório da extensão existente. Atualizando..."
    (cd "$EXT_REPO_DIR" && git pull) || echo "[AVISO] Falha ao atualizar repo da extensão."
else
    echo "[INFO] Repositório da extensão não encontrado. Clonando..."
    git clone "$EXT_REPO_URL" "$EXT_REPO_DIR"
fi

# --- 10b. Definir UUID e caminhos ---
EXT_UUID="hostnameIP@ornan" # NOVO UUID (do metadata.json do novo repo)
EXT_SRC_DIR="$EXT_REPO_DIR" # Fonte agora é a raiz do repo (não usa 'make')
EXT_DEST_SYSLOC="/usr/share/gnome-shell/extensions"
EXT_DEST_DIR="$EXT_DEST_SYSLOC/$EXT_UUID"

if [ -d "$EXT_SRC_DIR" ] && [ -f "$EXT_SRC_DIR/metadata.json" ]; then
    echo "[INFO] Copiando arquivos da extensão de $EXT_SRC_DIR para $EXT_DEST_DIR"
    rm -rf "$EXT_DEST_DIR" # Remove instalação antiga
    mkdir -p "$EXT_DEST_DIR"
    
    # Copia o *conteúdo* do diretório de origem para o destino
    cp -rT "$EXT_SRC_DIR" "$EXT_DEST_DIR" 
    chmod -R go-w "${EXT_DEST_DIR}" # Permissões (de ext.sh)
    
    # --- 10c. Ajustando metadata.json (Lógica do ext.sh) ---
    echo "[INFO] Ajustando metadata.json para a versão do GNOME atual..."
    GNOME_VER="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)" || GNOME_VER="46"
    META="${EXT_DEST_DIR}/metadata.json"
    if [ -f "${META}" ]; then
      if command -v jq >/dev/null 2>&1; then
        tmpmeta="$(mktemp)"
        jq --arg v "${GNOME_VER}" '
          .["shell-version"] =
            ((.["shell-version"] // []) + [$v]) | unique
        ' "${META}" > "${tmpmeta}" && mv "${tmpmeta}" "${META}"
        echo "[INFO] metadata.json atualizado com a versão $GNOME_VER via jq."
      else
        sed -i "s/\"shell-version\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\]/\"shell-version\": [\1, \"${GNOME_VER}\"]/" "${META}" || true
        echo "[INFO] metadata.json atualizado com a versão $GNOME_VER via sed (fallback)."
      fi
    fi
    
    # --- 10d. Registrar o Schema (ATUALIZADO) ---
    SCHEMA_FILE="$EXT_DEST_DIR/schemas/org.gnome.shell.extensions.hostnameIP.gschema.xml" # NOVO NOME DO SCHEMA
    SCHEMA_DEST_DIR="/usr/share/glib-2.0/schemas/"
    
    if [ -f "$SCHEMA_FILE" ]; then
        echo "[INFO] Copiando schema ($SCHEMA_FILE) para $SCHEMA_DEST_DIR"
        cp "$SCHEMA_FILE" "$SCHEMA_DEST_DIR"
        
        echo "[INFO] Recompilando schemas do sistema..."
        glib-compile-schemas "$SCHEMA_DEST_DIR"
        echo "[INFO] Schema da extensão registrado com sucesso."
    else
        echo "[AVISO] Não foi possível encontrar o arquivo de schema em $SCHEMA_FILE"
    fi
    
else
    echo "[ERRO] Diretório fonte da extensão $EXT_SRC_DIR ou metadata.json não encontrado. Pulando."
fi


# ------------------------------------------------------------
# 11. Instala pacotes principais (ownCloud, Chrome e outros)
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
    net-tools \
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
    thunderbird \
    iproute2 \
    net-tools \
    iputils-ping \
    traceroute \
    mtr \
    dnsutils \
    netcat-openbsd \
    nmap \
    tcpdump \
    ethtool \
    iftop \
    bmon \
    arp-scan \
    speedtest-cli

# ------------------------------------------------------------
# 12. Configuração do /etc/skel (Lógica do ext.sh - CORRIGIDA)
# ------------------------------------------------------------
echo "[INFO] Configurando /etc/skel para novos usuários (lógica ext.sh corrigida)..."
SKEL_RUSTDESK_DIR="/etc/skel/.config/rustdesk"
mkdir -p "$SKEL_RUSTDESK_DIR"

# Criando RustDesk.toml
cat <<'EOF' > "$SKEL_RUSTDESK_DIR/RustDesk.toml"
enc_id = '00nAPJRv40Kdl+RleWnncpKi6uY8jRfMCxe5Y='
password = ''
salt = '7cbs8z'
key_pair = [
    [
    144,
    46,
    146,
    10,
    183,
    14,
    186,
    12,
    185,
    204,
    145,
    217,
    49,
    76,
    25,
    136,
    177,
    187,
    5,
    231,
    251,
    100,
    14,
    23,
    17,
    204,
    220,
    96,
    202,
    143,
    173,
    179,
    137,
    105,
    243,
    0,
    128,
    122,
    177,
    83,
    107,
    59,
    38,
    172,
    27,
    98,
    185,
    74,
    114,
    156,
    12,
    196,
    51,
    122,
    223,
    95,
    247,
    216,
    131,
    28,
    125,
    7,
    251,
    99,
],
    [
    137,
    105,
    243,
    0,
    128,
    122,
    177,
    83,
    107,
    59,
    38,
    172,
    27,
    98,
    185,
    74,
    114,
    156,
    12,
    196,
    51,
    122,
    223,
    95,
    247,
    216,
    131,
    28,
    125,
    7,
    251,
    99,
],
]
key_confirmed = true

[keys_confirmed]
rs-ny = true
EOF

# Criando RustDesk_local.toml (COM OPÇÕES INTEGRADAS)
cat <<'EOF' > "$SKEL_RUSTDESK_DIR/RustDesk_local.toml"
remote_id = ''
kb_layout_type = ''
size = [
    0,
    0,
    0,
    0,
]
fav = []

[options]
rendezvous_server = 'rs-ny.rustdesk.com:21116'
nat_type = 1
serial = 0
unlock_pin = ''
trusted_devices = ''
direct-server = 'Y'
approve-mode = 'click'
av1-test = 'Y'
local-ip-addr = '__CURRENT_IP__'

[ui_flutter]
peer-sorting = 'Remote ID'
wm_Main = '{"width":800.0,"height":600.0,"offsetWidth":0.0,"offsetHeight":0.0,"isMaximized":false,"isFullscreen":false}'
EOF

echo "[INFO] Arquivos do RustDesk criados em /etc/skel/.config/rustdesk/"

# ------------------------------------------------------------
# 13. Criação do Script de Login (ATUALIZADO)
# ------------------------------------------------------------
echo "[INFO] Criando script de atualização /usr/local/bin/update-user-info.sh..."
cat <<'EOF' > "/usr/local/bin/update-user-info.sh"
#!/bin/bash
# Este script é executado no login do usuário para atualizar informações dinâmicas.

# Aguarda um pouco para garantir que a sessão do GNOME esteja pronta
sleep 8

# --- Configuração de Ambiente para gsettings ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# --- 1. Obter Hostname e IP ---
# Obtém o primeiro IP não-localhost (confiável para a maioria das conexões LAN)
CURRENT_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if ($i !~ /^127/ && $i !~ /^172\.17/ && $i !~ /^172\.18/) {print $i; exit}}')
# Fallback se o IP estiver vazio (ex: sem rede, só loopback)
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(hostname -I | awk '{print $1}') # Pega o primeiro IP que encontrar
fi
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="N/A" # Caso extremo
fi
CURRENT_HOSTNAME=$(hostname)

# --- 2. Atualizar a Extensão GNOME (ATUALIZADO) ---
if command -v gsettings &> /dev/null; then
    # ATUALIZADO: Novo nome do Schema
    SCHEMA="org.gnome.shell.extensions.hostnameIP"
    
    # Tenta definir as chaves. Falha silenciosamente se a extensão não estiver carregada.
    # O schema DEVE estar registrado via glib-compile-schemas (feito na Seção 10)
    gsettings set $SCHEMA "label-text" "$CURRENT_HOSTNAME" 2> /dev/null
    gsettings set $SCHEMA "label-text-2" "$CURRENT_IP" 2> /dev/null
    
    # A ativação da extensão é feita via dconf (Seção 20)
fi

# --- 3. Atualizar Configuração do RustDesk (CORRIGIDO) ---
RUSTDESK_DIR="$HOME/.config/rustdesk"
CONFIG_FILE="$RUSTDESK_DIR/RustDesk_local.toml"

# Verifica se o arquivo de configuração local existe
if [ -f "$CONFIG_FILE" ]; then
    # Substitui o placeholder __CURRENT_IP__ pelo IP real, IN-PLACE
    # Isso garante que as opções sejam preservadas e apenas o IP seja atualizado.
    sed -i "s|local-ip-addr = '.*'|local-ip-addr = '$CURRENT_IP'|" "$CONFIG_FILE"
fi
EOF

# Tornar o script de login executável
chmod +x /usr/local/bin/update-user-info.sh

# ------------------------------------------------------------
# 14. Criação do Arquivo Autostart (Lógica do ext.sh)
# ------------------------------------------------------------
echo "[INFO] Criando gatilho de login em /etc/xdg/autostart/..."
cat <<'EOF' > "/etc/xdg/autostart/update-user-info.desktop"
[Desktop Entry]
Type=Application
Name=Update User Info
Comment=Atualiza o IP e Hostname no login
Exec=/usr/local/bin/update-user-info.sh
OnlyShowIn=GNOME;
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# ------------------------------------------------------------
# 15. Aplicar aos Usuários EXISTENTES (Lógica do ext.sh - CORRIGIDA)
# ------------------------------------------------------------
echo "[INFO] Aplicando configurações do RustDesk para usuários existentes em /home/..."
for D in /home/*; do
  if [ -d "$D" ]; then
    USER=$(basename "$D")
    USER_RUSTDESK_DIR="$D/.config/rustdesk"
    
    echo "Configurando para o usuário: $USER"
    mkdir -p "$USER_RUSTDESK_DIR"
    
    # Copia os arquivos do skel, -n (noclobber) não sobrescreve se já existirem
    # Isso irá copiar o novo RustDesk.toml e o RustDesk_local.toml (com opções)
    cp -n /etc/skel/.config/rustdesk/* "$USER_RUSTDESK_DIR/"
    
    # Garante que o usuário seja o dono dos seus arquivos de configuração
    chown -R "$USER:$USER" "$D/.config"
  fi
done

# ------------------------------------------------------------
# 16. Cria grupo powerusers e regra polkit
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
# 17. Instala e habilita Tailscale
# ------------------------------------------------------------
echo "[INFO] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | bash
systemctl enable --now tailscaled

# ------------------------------------------------------------
# 18. Habilita SSH
# ------------------------------------------------------------
echo "[INFO] Habilitando SSH..."
systemctl enable --now ssh

# ============================================================
# INÍCIO DA SEÇÃO DE WALLPAPER E EXTENSÕES (DCONF)
# ============================================================

# ------------------------------------------------------------
# 19. Cria script de atualização e agendamento (Cron)
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
# 20. Define e Bloqueia o Papel de Parede e Extensões (dconf)
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

# --- Perfil de Extensão (ATUALIZADO) ---
# A variável $EXT_UUID foi definida na Seção 10 como "hostnameIP@ornan"
cat > "$DCONF_DB_DIR/02-giusoft-extensions" <<EOF
[org/gnome/shell]
# Ativa a extensão 'hostnameIP@ornan' para todos os usuários
enabled-extensions=['$EXT_UUID']
EOF

# --- Trava da Extensão ---
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
# 21. Garante permissões corretas no Wallpaper
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
# 22. Oculta Aplicações do Menu (NoDisplay)
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
# 23. Configura Logo do GDM (Tela de Login) - MÉTODO DCONF (ext.sh)
# ------------------------------------------------------------
echo "[INFO] Configurando logo personalizado do GDM (tela de login) via dconf..."

# Fonte: Arquivo 'logo-full.png' na raiz do repositório GiuSoft
GDM_LOGO_SRC_FILE="$GIT_REPO_DIR/logo-full.png"
LOGO_DST_DIR="/usr/share/pixmaps"
LOGO_DST="${LOGO_DST_DIR}/giusoft-gdm-logo.png"

if [ -f "$GDM_LOGO_SRC_FILE" ]; then
    echo "[INFO] Copiando logo de $GDM_LOGO_SRC_FILE para $LOGO_DST..."
    install -d -m 0755 "${LOGO_DST_DIR}"
    cp -f "$GDM_LOGO_SRC_FILE" "$LOGO_DST"
    chmod 0644 "${LOGO_DST}"

    echo "[INFO] Aplicando configuração do logo GDM via dconf..."
    # Perfil/DB do GDM para definir o logo do greeter (suportado oficialmente)
    install -d -m 0755 /etc/dconf/profile
    cat >/etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

    install -d -m 0755 /etc/dconf/db/gdm.d
    # Usa a variável $LOGO_DST no EOF
    cat >/etc/dconf/db/gdm.d/01-logo <<EOF
[org/gnome/login-screen]
logo='${LOGO_DST}'
EOF

    # Atualiza bases do dconf (vai aplicar no próximo ciclo do GDM)
    dconf update
    echo "[INFO] Logo do GDM configurado via dconf."

else
    echo "[AVISO] Arquivo do logo GDM não encontrado em $GDM_LOGO_SRC_FILE. Pulando..."
fi


# ------------------------------------------------------------
# 24. Finalização
# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "[FINALIZADO] Script de pós-instalação GiuSoft concluído."
echo "Log salvo em: $LOGFILE"
echo "IMPORTANTE: REINICIE O COMPUTADOR para que todas as alterações (dconf, autostart, skel, logo GDM) tenham efeito."
echo "============================================================"
echo ""
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
echo "   sudo usmod -aG powerusers nome_do_usuario"
echo "------------------------------------------------------------"

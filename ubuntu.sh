#!/bin/bash
# ============================================================
# Ubuntu 24.04 - Ambiente GiuSoft
# Autor: Ornan Matos
# Versão 1.3
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft (Versão 12.2) ==="
echo "Log será salvo em: $LOGFILE"

# ------------------------------------------------------------
# 1. Preparação do Sistema
# ------------------------------------------------------------
echo "[INFO] Atualizando sistema e instalando dependências..."
apt update -y && apt full-upgrade -y && apt autoremove -y
apt install -y wget curl gpg software-properties-common apt-transport-https \
    ca-certificates git unzip gnome-shell-extensions jq libglib2.0-dev-bin \
    network-manager gnome-remote-desktop desktop-file-utils coreutils

# ------------------------------------------------------------
# 2. Repositórios e Softwares
# ------------------------------------------------------------
add-apt-repository -y universe
add-apt-repository -y multiverse
add-apt-repository -y restricted

# Chrome
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# OwnCloud
wget -nv https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Ubuntu_24.04/Release.key -O - | gpg --dearmor | tee /etc/apt/trusted.gpg.d/owncloud-client.gpg > /dev/null
echo 'deb https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Ubuntu_24.04/ /' | tee -a /etc/apt/sources.list.d/owncloud-client.list

# Fontes MS
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

apt update -y

# Clone Repo GiuSoft
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
mkdir -p /opt/giusoft
if [ -d "$GIT_REPO_DIR/.git" ]; then
    (cd "$GIT_REPO_DIR" && git pull)
else
    git clone https://github.com/giusoft/FreeIPA.git "$GIT_REPO_DIR"
fi

# Instalação Pacotes
apt install -y \
    google-chrome-stable \
    owncloud-client \
    vim \
    openssh-server \
    freeipa-client \
    oddjob \
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
    traceroute \
    mtr \
    dnsutils \
    nmap \
    tcpdump \
    ethtool \
    iftop \
    bmon \
    arp-scan \
    speedtest-cli \
    inxi 

[ -f "$GIT_REPO_DIR/Zoiper.deb" ] && apt install -y "$GIT_REPO_DIR/Zoiper.deb"

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ------------------------------------------------------------
# 3. Instalação da Extensão HostnameIP
# ------------------------------------------------------------
echo "[INFO] Instalando extensão GNOME 'hostnameIP'..."

rm -rf /tmp/hostnameIP-build
git clone -b dev "https://github.com/ornan-matos/gnome-shell-extension-hostnameIP.git" /tmp/hostnameIP-build

EXT_SRC="/tmp/hostnameIP-build/hostnameIP@ornan-matos"

if [ -d "$EXT_SRC" ] && [ -f "$EXT_SRC/metadata.json" ]; then
    EXT_UUID=$(jq -r .uuid < "$EXT_SRC/metadata.json")
    EXT_SYS_DIR="/usr/share/gnome-shell/extensions/$EXT_UUID"

    rm -rf "$EXT_SYS_DIR"
    mkdir -p "$EXT_SYS_DIR"
    cp -rT "$EXT_SRC" "$EXT_SYS_DIR"
    
    # Patches
    if [ -f "$EXT_SYS_DIR/extension.js" ]; then
        sed -i "s|return addr.to_string();|const ipStr = addr.to_string(); if (ipStr !== '127.0.0.1' \&\& ipStr !== '127.0.1.1') return ipStr;|" "$EXT_SYS_DIR/extension.js"
    fi
    
    META="$EXT_SYS_DIR/metadata.json"
    jq --arg v "46" '.["shell-version"] |= (. + [$v] | unique)' "$META" > "${META}.tmp" && mv "${META}.tmp" "$META"
    
    find "$EXT_SYS_DIR" -type d -exec chmod 755 {} +
    find "$EXT_SYS_DIR" -type f -exec chmod 644 {} +
    
    if [ -d "$EXT_SYS_DIR/schemas" ]; then
        glib-compile-schemas "$EXT_SYS_DIR/schemas"
        cp "$EXT_SYS_DIR/schemas/"*.xml /usr/share/glib-2.0/schemas/ 2>/dev/null || true
        glib-compile-schemas /usr/share/glib-2.0/schemas/
    fi
else
    echo "[ERRO] Extensão não encontrada."
fi

# ------------------------------------------------------------
# 4. Ocultar Aplicações
# ------------------------------------------------------------
echo "[INFO] Ocultando aplicações..."
HIDDEN_APPS=(
    "evince.desktop" "org.gnome.evince.desktop" "org.gnome.evince-previewer.desktop" 
    "org.gnome.Evince.desktop" "org.gnome.Evince-previewer.desktop" "simple-scan.desktop"
    "apport-gtk.desktop" "bluetooth-sendto.desktop" "gcr-prompter.desktop" "gcr-viewer.desktop"
    "geoclue-demo-agent.desktop" "gkbd-keyboard-display.desktop" "gnome-about-panel.desktop"
    "gnome-applications-panel.desktop" "gnome-background-panel.desktop" "gnome-bluetooth-panel.desktop"
    "gnome-color-panel.desktop" "gnome-datetime-panel.desktop" "gnome-disk-image-mounter.desktop"
    "gnome-disk-image-writer.desktop" "gnome-display-panel.desktop" "gnome-initial-setup.desktop"
    "gnome-keyboard-panel.desktop" "gnome-language-selector.desktop" "gnome-mouse-panel.desktop"
    "gnome-multitasking-panel.desktop" "gnome-network-panel.desktop" "gnome-notifications-panel.desktop"
    "gnome-online-accounts-panel.desktop" "gnome-power-panel.desktop" "gnome-printers-panel.desktop"
    "gnome-privacy-panel.desktop" "gnome-region-panel.desktop" "gnome-search-panel.desktop"
    "gnome-session-properties.desktop" "gnome-sharing-panel.desktop" "gnome-sound-panel.desktop"
    "gnome-system-monitor-kde.desktop" "gnome-system-panel.desktop" "gnome-ubuntu-panel.desktop"
    "gnome-universal-access-panel.desktop" "gnome-users-panel.desktop" "gnome-wacom-panel.desktop"
    "gnome-wifi-panel.desktop" "gnome-wwan-panel.desktop" "hplj1020.desktop" "htop.desktop"
    "ibus-setup-chewing.desktop" "ibus-setup-libbopomofo.desktop" "ibus-setup-libpinyin.desktop"
    "ibus-setup-m17n.desktop" "ibus-setup-table.desktop" "im-config.desktop" "info.desktop"
    "io.snapcraft.SessionAgent.desktop" "libreoffice-startcenter.desktop" "libreoffice-xsltfilter.desktop"
    "nautilus-autorun-software.desktop" "nm-applet.desktop" "nm-connection-editor.desktop" "nvim.desktop"
    "org.freedesktop.IBus.Panel.Emojier.desktop" "org.freedesktop.IBus.Panel.Extension.Gtk3.desktop"
    "org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop" "org.freedesktop.IBus.Setup.desktop"
    "org.freedesktop.Xwayland.desktop" "org.gnome.Characters.desktop" "org.gnome.DiskUtility.desktop"
    "org.gnome.Evolution-alarm-notify.desktop" "org.gnome.Logs.desktop" "org.gnome.OnlineAccounts.OAuth2.desktop"
    "org.gnome.PowerStats.desktop" "org.gnome.RemoteDesktop.Handover.desktop" "org.gnome.Shell.Extensions.desktop"
    "org.gnome.Shell.desktop" "org.gnome.SystemMonitor.desktop" "org.gnome.Tecla.desktop"
    "org.gnome.Terminal.Preferences.desktop" "org.gnome.Zenity.desktop" "org.gnome.baobab.desktop"
    "org.gnome.eog.desktop" "org.gnome.evolution-data-server.OAuth2-handler.desktop" "org.gnome.font-viewer.desktop"
    "org.gnome.seahorse.Application.desktop" "python3.12.desktop" "rygel.desktop" "snap-handle-link.desktop"
    "software-properties-drivers.desktop" "software-properties-gtk.desktop" "software-properties-livepatch.desktop"
    "update-manager.desktop" "vim.desktop" "xdg-desktop-portal-gnome.desktop" "xdg-desktop-portal-gtk.desktop"
    "yelp.desktop"     "apport-gtk.desktop"
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
GLOBAL_OVERRIDE_DIR="/usr/local/share/applications"
mkdir -p "$GLOBAL_OVERRIDE_DIR"
for app in "${HIDDEN_APPS[@]}"; do
    SRC=""
    [ -f "/usr/share/applications/$app" ] && SRC="/usr/share/applications/$app"
    [ -f "/var/lib/snapd/desktop/applications/$app" ] && SRC="/var/lib/snapd/desktop/applications/$app"
    if [ -n "$SRC" ]; then
        cp -f "$SRC" "$GLOBAL_OVERRIDE_DIR/$app"
        if grep -q "^NoDisplay=" "$GLOBAL_OVERRIDE_DIR/$app"; then
            sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$GLOBAL_OVERRIDE_DIR/$app"
        else
            echo "NoDisplay=true" >> "$GLOBAL_OVERRIDE_DIR/$app"
        fi
    fi
done
update-desktop-database "$GLOBAL_OVERRIDE_DIR"

# ------------------------------------------------------------
# 5. Script de Login
# ------------------------------------------------------------

cat <<EOF > "/usr/local/bin/update-user-info.sh"
#!/bin/bash

# Variáveis
EXT_UUID="$EXT_UUID"

# --- ALGORITMO DE SENHA BASEADO EM HOST E DATA ---
# 1. Limpa o hostname
HOST_CLEAN=\$(hostname | tr '[:upper:]' '[:lower:]' | tr -d ' ')

# 2. Cria uma semente única baseada no checksum do hostname
HOST_SEED=\$(echo -n "\$HOST_CLEAN" | cksum | cut -f1 -d" ")

# 3. Define os Modelos de Senha (O Hostname faz parte da string)
# CORREÇÃO: Escapamos \${HOST_CLEAN} para que seja expandido apenas na execução
SENHAS=(
    "User@\${HOST_CLEAN}#78"
    "Access#\${HOST_CLEAN}!04"
    "Desk\\$\${HOST_CLEAN}&92"
    "Remote@\${HOST_CLEAN}#11"
    "Rdp#\${HOST_CLEAN}!33"
    "Client\\$\${HOST_CLEAN}&56"
    "Session@\${HOST_CLEAN}#88"
    "Net#\${HOST_CLEAN}!21"
    "Link\\$\${HOST_CLEAN}&43"
    "Gate@\${HOST_CLEAN}#67"
)

# 4. Cálculo de Rotação (Modulo 10)
DIA_DO_ANO=\$(date +%-j)
# Usa o tamanho do array para o modulo
INDICE=\$(( (DIA_DO_ANO + HOST_SEED) % 10 ))
SENHA_DO_DIA="\${SENHAS[\$INDICE]}"

# Aguarda sessão
sleep 5

# --- Ativações ---
gnome-extensions enable "\$EXT_UUID" 2>/dev/null || true

CURRENT_IP=\$(hostname -I | awk '{for(i=1;i<=NF;i++) if (\$i !~ /^127/ && \$i !~ /^172\.17/ && \$i !~ /^172\.18/) {print \$i; exit}}')
[ -z "\$CURRENT_IP" ] && CURRENT_IP=\$(hostname -I | awk '{print \$1}')

# Aplica a Senha Gerada ao RDP
if command -v grdctl >/dev/null 2>&1; then
    grdctl rdp set-credentials "\$USER" "\$SENHA_DO_DIA" || true
    grdctl rdp set-view-only false || true
    gsettings set org.gnome.desktop.remote-desktop.rdp view-only false || true
    grdctl rdp enable || true
    systemctl --user restart gnome-remote-desktop.service || true
fi
EOF
chmod +x /usr/local/bin/update-user-info.sh

mkdir -p /etc/xdg/autostart
cat <<'EOF' > "/etc/xdg/autostart/update-user-info.desktop"
[Desktop Entry]
Type=Application
Name=Setup User Session
Exec=/usr/local/bin/update-user-info.sh
OnlyShowIn=GNOME;
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# ------------------------------------------------------------
# 5.1 Configuração 'admings'
# ------------------------------------------------------------

echo "[INFO] Configurando rotação de senha separada para admings..."

if ! id "admings" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo admings
fi

cat <<'EOF' > "/usr/local/bin/rotate-admin-pass.sh"
#!/bin/bash

HOST_CLEAN=$(hostname | tr '[:upper:]' '[:lower:]' | tr -d ' ')
HOST_SEED=$(echo -n "$HOST_CLEAN" | cksum | cut -f1 -d" ")

# Lista B: Exclusiva para o Administrador (Diferente do RDP)
SENHAS_ADMIN=(
    "Root@${HOST_CLEAN}#Master"
    "Secure#${HOST_CLEAN}!One"
    "Power\$${HOST_CLEAN}&Adm"
    "Prime@${HOST_CLEAN}#Sys"
    "Boss#${HOST_CLEAN}!Mode"
    "Super\$${HOST_CLEAN}&User"
    "Key@${HOST_CLEAN}#Admin"
    "Ultra#${HOST_CLEAN}!Core"
    "Mega\$${HOST_CLEAN}&Root"
    "Alpha@${HOST_CLEAN}#Access"
)

DIA_DO_ANO=$(date +%-j)
# Correção: Módulo 10 para usar todas as senhas do array
INDICE=$(( (DIA_DO_ANO + HOST_SEED) % 10 ))
SENHA_ADMIN_DIA="${SENHAS_ADMIN[$INDICE]}"

# Aplica senha ao usuário admings
echo "admings:$SENHA_ADMIN_DIA" | chpasswd
EOF
chmod 700 /usr/local/bin/rotate-admin-pass.sh

/usr/local/bin/rotate-admin-pass.sh
cat <<'EOF' > /etc/cron.d/giusoft-admin-rotation
1 0 * * * root /usr/local/bin/rotate-admin-pass.sh
EOF


# ------------------------------------------------------------
# 6. DNS e Rede
# ------------------------------------------------------------
ACTIVE_ETH=$(nmcli -t -f UUID,TYPE connection show | grep "802-3-ethernet" | cut -d: -f1 | head -n1 || true)
if [ -n "$ACTIVE_ETH" ]; then
    echo "[INFO] Configurando DNS ETH: $ACTIVE_ETH"
    nmcli connection modify "$ACTIVE_ETH" ipv4.dns "192.168.1.199 1.1.1.1" ipv4.ignore-auto-dns yes ipv4.dns-search "gs.internal"
    nmcli connection up "$ACTIVE_ETH" || true
fi

# ------------------------------------------------------------
# 7. Wallpapers e GDM Logo 
# ------------------------------------------------------------
echo "[INFO] Configurando e BLOQUEANDO Wallpaper..."


DCONF_DB="/etc/dconf/db/local.d"
LOCK_DIR="/etc/dconf/db/local.d/locks"
mkdir -p "$DCONF_DB" "$LOCK_DIR"
mkdir -p /etc/dconf/profile/


echo -e "user-db:user\nsystem-db:local\nsystem-db:site" > /etc/dconf/profile/user


WALL_FILE="/usr/share/backgrounds/giusoft/Wallpaper.png"
mkdir -p "$(dirname "$WALL_FILE")"

if [ -f "$GIT_REPO_DIR/Wallpaper.png" ]; then
    cp -f "$GIT_REPO_DIR/Wallpaper.png" "$WALL_FILE"
else

    cp /usr/share/backgrounds/warty-final-ubuntu.png "$WALL_FILE" 2>/dev/null || true
fi


cat <<EOF > "$DCONF_DB/01-giusoft-wallpaper"
[org/gnome/desktop/background]
picture-uri='file://$WALL_FILE'
picture-uri-dark='file://$WALL_FILE'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file://$WALL_FILE'
EOF


cat <<EOF > "$LOCK_DIR/00-wallpaper-lock"
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/background/picture-options
/org/gnome/desktop/screensaver/picture-uri
EOF


echo "0 10 1 * * root cp -f $GIT_REPO_DIR/Wallpaper.png $WALL_FILE" > /etc/cron.d/giusoft-wallpaper-update


GDM_LOGO_SRC="$GIT_REPO_DIR/logo-full.png"
LOGO_DST="/usr/share/pixmaps/giusoft-gdm-logo.png"

if [ -f "$GDM_LOGO_SRC" ]; then
    cp -f "$GDM_LOGO_SRC" "$LOGO_DST"
    chmod 644 "$LOGO_DST"
    

    mkdir -p /etc/dconf/db/gdm.d
    echo -e "user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults" > /etc/dconf/profile/gdm
    

    echo -e "[org/gnome/login-screen]\nlogo='$LOGO_DST'" > /etc/dconf/db/gdm.d/01-logo
    

    [ -d "/usr/share/plymouth/themes/spinner" ] && cp -f "$GDM_LOGO_SRC" /usr/share/plymouth/themes/spinner/watermark.png
fi

dconf update

# ------------------------------------------------------------
# 8. Finalização
# ------------------------------------------------------------

cat <<EOF > /etc/polkit-1/rules.d/61-restrict-remote-desktop.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.gnome.RemoteDesktop.configure") { return polkit.Result.AUTH_ADMIN; }
});
EOF
systemctl restart polkit || true


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
echo "     --principal=admin \\"
echo "     --enable-dns-updates"
echo ""
echo "2. Adicione usuários ao grupo 'powerusers' (se necessário):"
echo "   sudo usermod -aG powerusers nome_do_usuario"
echo "------------------------------------------------------------"
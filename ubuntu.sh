#!/bin/bash
# ============================================================
# Ubuntu 24.04 - Ambiente GiuSoft
# Autor: Ornan S. Matos
# Versão 1.8 (Nextcloud, Linphone, Regras USB, Polkit e RustDesk Local)
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft-ubuntu.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft (Ubuntu - Padrão Versão 12.5) ==="
echo "Log será salvo em: $LOGFILE"

# ------------------------------------------------------------
# 1. Preparação do Sistema e Repositórios
# ------------------------------------------------------------
echo "[INFO] Atualizando sistema e repositórios..."
export DEBIAN_FRONTEND=noninteractive

add-apt-repository -y universe
add-apt-repository -y multiverse
add-apt-repository -y restricted

apt-get update -y && apt-get full-upgrade -y && apt-get autoremove -y

# ------------------------------------------------------------
# 2. Utilitários Básicos e Google Chrome
# ------------------------------------------------------------
echo "[INFO] Instalando utilitários base e Google Chrome..."
apt-get install -y wget curl gnupg ca-certificates git unzip jq libglib2.0-dev-bin \
    software-properties-common apt-transport-https make sassc gettext

# Chrome Repo
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Fontes MS (Aceitação automática)
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

apt-get update -y

# ------------------------------------------------------------
# 3. Pacotes Adicionais (Paridade com Fedora)
# ------------------------------------------------------------
echo "[INFO] Instalando pacotes do sistema, multimídia e redes..."
apt-get install -y \
    google-chrome-stable vim nano htop tmux zsh bash-completion \
    net-tools telnet traceroute nmap dnsutils iperf3 \
    rsync tree zip p7zip-full unrar \
    fonts-dejavu fonts-liberation ttf-mscorefonts-installer \
    ubuntu-restricted-extras ffmpeg \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools \
    flatpak libreoffice libreoffice-l10n-pt-br libreoffice-help-pt-br hunspell-pt-br \
    sssd oddjob oddjob-mkhomedir adcli realmd sssd-tools \
    samba cifs-utils freeipa-client krb5-user \
    gnome-remote-desktop \
    cockpit cockpit-machines cockpit-storaged cockpit-networkmanager cockpit-packagekit cockpit-pcp \
    gdm3 file-roller nautilus cron \
    inxi glmark2-es2-drm glmark2 fio stress-ng lm-sensors firewalld

# ------------------------------------------------------------
# 4. Clona repositório GiuSoft
# ------------------------------------------------------------
echo "[INFO] Configurando repositório GiuSoft..."
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
mkdir -p /opt/giusoft

git config --global --add safe.directory "$GIT_REPO_DIR"

if [ -d "$GIT_REPO_DIR/.git" ]; then
    (cd "$GIT_REPO_DIR" && git pull)
else
    git clone https://github.com/giusoft/FreeIPA.git "$GIT_REPO_DIR"
fi

# ------------------------------------------------------------
# 5. Instala Linphone (AppImage)
# ------------------------------------------------------------
echo "[INFO] Instalando Linphone..."
LINPHONE_APPIMAGE="/opt/giusoft/Linphone-5.3.3.AppImage"
LINPHONE_ICON="/opt/giusoft/linphone_icon.png"

wget -qO "$LINPHONE_APPIMAGE" "https://download.linphone.org/releases/linux/app/Linphone-5.3.3.AppImage"
chmod +x "$LINPHONE_APPIMAGE"
wget -qO "$LINPHONE_ICON" "https://images.icon-icons.com/1381/PNG/512/linphone_94743.png"

cat > /usr/share/applications/linphone.desktop <<EOF
[Desktop Entry]
Name=Linphone
Comment=Cliente SIP e VoIP
Exec=$LINPHONE_APPIMAGE
Icon=$LINPHONE_ICON
Terminal=false
Type=Application
Categories=Network;Telephony;
EOF

# ------------------------------------------------------------
# 6. Instalação de Extensões GNOME
# ------------------------------------------------------------
echo "[INFO] Instalando Extensões GNOME..."
EXT_DEST_SYSLOC="/usr/share/gnome-shell/extensions"
mkdir -p "$EXT_DEST_SYSLOC"

# --- HostnameIP ---
rm -rf /tmp/hostnameIP-build
git clone -b dev "https://github.com/ornan-matos/gnome-shell-extension-hostnameIP.git" /tmp/hostnameIP-build

EXT_SRC="/tmp/hostnameIP-build/hostnameIP@ornan-matos"
if [ -d "$EXT_SRC" ] && [ -f "$EXT_SRC/metadata.json" ]; then
    EXT_UUID=$(jq -r .uuid < "$EXT_SRC/metadata.json")
    EXT_SYS_DIR="$EXT_DEST_SYSLOC/$EXT_UUID"

    rm -rf "$EXT_SYS_DIR"
    mkdir -p "$EXT_SYS_DIR"
    cp -r "$EXT_SRC"/* "$EXT_SYS_DIR/"
    
    TARGET_FILE="$EXT_SYS_DIR/extension.js"
    if [ -f "$TARGET_FILE" ]; then
        sed -i "s|return addr.to_string();|if(addr.to_string().substring(0,3)!='127')return addr.to_string();|" "$TARGET_FILE"
    fi
    
    META="$EXT_SYS_DIR/metadata.json"
    if [ -f "$META" ]; then
        jq --arg v "46" '.["shell-version"] |= (. + [$v] | unique)' "$META" > "${META}.tmp" && mv "${META}.tmp" "$META"
    fi
    
    chmod -R 755 "$EXT_SYS_DIR"
    if [ -d "$EXT_SYS_DIR/schemas" ]; then
        glib-compile-schemas "$EXT_SYS_DIR/schemas"
    fi
fi

# --- Dash-to-Dock ---
EXT_D2D_REPO_DIR="/opt/dash-to-dock-ext"
EXT_UUID_D2D="dash-to-dock@micxgx.gmail.com"
EXT_D2D_DEST_DIR="$EXT_DEST_SYSLOC/$EXT_UUID_D2D"

if [ -d "$EXT_D2D_REPO_DIR/.git" ]; then
    (cd "$EXT_D2D_REPO_DIR" && git pull)
else
    git clone "https://github.com/micheleg/dash-to-dock.git" "$EXT_D2D_REPO_DIR"
fi

if [ -d "$EXT_D2D_REPO_DIR" ]; then
    (cd "$EXT_D2D_REPO_DIR" && make)
    rm -rf "$EXT_D2D_DEST_DIR"
    mkdir -p "$EXT_D2D_DEST_DIR"
    cp -r "$EXT_D2D_REPO_DIR/"* "$EXT_D2D_DEST_DIR/"
    rm -rf "$EXT_D2D_DEST_DIR/.git" "$EXT_D2D_DEST_DIR/.github"
    chown -R root:root "$EXT_D2D_DEST_DIR"
    chmod -R 755 "$EXT_D2D_DEST_DIR"
fi

# --- Dash-to-Panel ---
EXT_D2P_REPO_DIR="/opt/dash-to-panel-ext"
EXT_UUID_D2P="dash-to-panel@jderose9.github.com"
EXT_D2P_DEST_DIR="$EXT_DEST_SYSLOC/$EXT_UUID_D2P"

if [ -d "$EXT_D2P_REPO_DIR/.git" ]; then
    (cd "$EXT_D2P_REPO_DIR" && git pull)
else
    git clone "https://github.com/home-sweet-gnome/dash-to-panel.git" "$EXT_D2P_REPO_DIR"
fi

if [ -d "$EXT_D2P_REPO_DIR" ]; then
    (cd "$EXT_D2P_REPO_DIR" && make)
    rm -rf "$EXT_D2P_DEST_DIR"
    mkdir -p "$EXT_D2P_DEST_DIR"
    cp -r "$EXT_D2P_REPO_DIR/"* "$EXT_D2P_DEST_DIR/"
    rm -rf "$EXT_D2P_DEST_DIR/.git" "$EXT_D2P_DEST_DIR/.github"
    chown -R root:root "$EXT_D2P_DEST_DIR"
    chmod -R 755 "$EXT_D2P_DEST_DIR"
fi

# --- Pip-on-Top ---
EXT_PIP_REPO_URL="https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git"
EXT_PIP_REPO_DIR="/opt/pip-on-top-ext"
EXT_UUID_PIP_ON_TOP="pip-on-top@rafostar.github.com"
EXT_PIP_DEST_DIR="$EXT_DEST_SYSLOC/$EXT_UUID_PIP_ON_TOP"

if [ ! -d "$EXT_PIP_REPO_DIR/.git" ]; then
    git clone "$EXT_PIP_REPO_URL" "$EXT_PIP_REPO_DIR"
fi

if [ -d "$EXT_PIP_REPO_DIR" ]; then
    rm -rf "$EXT_PIP_DEST_DIR"
    mkdir -p "$EXT_PIP_DEST_DIR"
    cp -r "$EXT_PIP_REPO_DIR/"* "$EXT_PIP_DEST_DIR/"
    rm -rf "$EXT_PIP_DEST_DIR/.git"
    chown -R root:root "$EXT_PIP_DEST_DIR"
    if [ -d "$EXT_PIP_DEST_DIR/schemas" ]; then
        glib-compile-schemas "$EXT_PIP_DEST_DIR/schemas"
    fi
fi

# ------------------------------------------------------------
# 7. Instala Nextcloud Desktop Client (Flatpak)
# ------------------------------------------------------------
echo "[INFO] Instalando Nextcloud via Flatpak..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.nextcloud.desktopclient.nextcloud

# ------------------------------------------------------------
# 8. Ocultar Aplicações 
# ------------------------------------------------------------
echo "[INFO] Ocultando aplicações..."
HIDDEN_APPS=(
    "gcr-prompter.desktop" "gcr-viewer.desktop" "geoclue-demo-agent.desktop"
    "gkbd-keyboard-display.desktop" "gnome-about-panel.desktop" "gnome-applications-panel.desktop"
    "gnome-background-panel.desktop" "gnome-bluetooth-panel.desktop" "gnome-color-panel.desktop"
    "gnome-datetime-panel.desktop" "gnome-disk-image-mounter.desktop" "gnome-disk-image-writer.desktop"
    "gnome-display-panel.desktop" "gnome-initial-setup.desktop" "gnome-keyboard-panel.desktop"
    "gnome-language-selector.desktop" "gnome-mouse-panel.desktop" "gnome-multitasking-panel.desktop"
    "gnome-network-panel.desktop" "gnome-notifications-panel.desktop" "gnome-online-accounts-panel.desktop"
    "gnome-power-panel.desktop" "gnome-printers-panel.desktop" "gnome-privacy-panel.desktop"
    "gnome-region-panel.desktop" "gnome-search-panel.desktop" "gnome-session-properties.desktop"
    "gnome-sharing-panel.desktop" "gnome-sound-panel.desktop" "gnome-system-monitor-kde.desktop"
    "gnome-system-panel.desktop" "gnome-universal-access-panel.desktop" "gnome-users-panel.desktop"
    "gnome-wacom-panel.desktop" "gnome-wifi-panel.desktop" "gnome-wwan-panel.desktop"
    "hplj1020.desktop" "htop.desktop" "im-config.desktop" "info.desktop"
    "libreoffice-xsltfilter.desktop" "nautilus-autorun-software.desktop" "nm-applet.desktop"
    "nm-connection-editor.desktop" "nvim.desktop" "org.freedesktop.IBus.Panel.Emojier.desktop"
    "org.freedesktop.IBus.Panel.Extension.Gtk3.desktop" "org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop"
    "org.freedesktop.IBus.Setup.desktop" "org.freedesktop.Xwayland.desktop" "org.gnome.Evolution-alarm-notify.desktop"
    "org.gnome.OnlineAccounts.OAuth2.desktop" "org.gnome.PowerStats.desktop" "org.gnome.RemoteDesktop.Handover.desktop"
    "org.gnome.Shell.Extensions.desktop" "org.gnome.Shell.desktop" "org.gnome.Terminal.Preferences.desktop"
    "org.gnome.Zenity.desktop" "org.gnome.evolution-data-server.OAuth2-handler.desktop" "python3.12.desktop"
    "rygel.desktop" "vim.desktop" "xdg-desktop-portal-gnome.desktop" "xdg-desktop-portal-gtk.desktop" "vncviewer.desktop"
    "yelp.desktop" "gnome-tweaks.desktop" "file-roller.desktop" "bluetooth-sendto.desktop"
    "ibus-setup-chewing.desktop" "ibus-setup-libbopomofo.desktop" "ibus-setup-libpinyin.desktop"
    "ibus-setup-m17n.desktop" "ibus-setup-table.desktop" "libreoffice-startcenter.desktop"
    "org.gnome.Characters.desktop" "org.gnome.DiskUtility.desktop" "org.gnome.Evince-previewer.desktop"
    "org.gnome.Evince.desktop" "org.gnome.Logs.desktop" "org.gnome.SystemMonitor.desktop"
    "org.gnome.Tecla.desktop" "org.gnome.baobab.desktop" "org.gnome.eog.desktop"
    "org.gnome.font-viewer.desktop" "org.gnome.seahorse.Application.desktop" "org.gnome.Contacts.desktop"
    "org.gnome.Weather.desktop" "org.gnome.Cheese.desktop" "org.gnome.Snapshot.desktop"
    "org.gnome.Boxes.desktop" "org.fedoraproject.MediaWriter.desktop" "glmark2.desktop"
    "glmark2-es2-wayland.desktop" "glmark2-es2-x11.desktop" "glmark2-wayland.desktop"
    "glmark2-x11.desktop" "org.gnome.clocks.desktop" "org.gnome.Maps.desktop"
    "org.gnome.SimpleScan.desktop" "org.gnome.DocumentScanner.desktop" "org.gnome.bug-report-tool.desktop"
    "org.gnome.Tour.desktop" "org.gnome.Music.desktop" "org.gnome.Decibels.desktop"
    "malcontent-control.desktop" "glmark2-es2.desktop" "org.gnome.Loupe.desktop"
    "com.github.ADBeveridge.Papers.desktop" "io.bina.Showtime.desktop" "apport-gtk.desktop"
    "software-properties-drivers.desktop" "software-properties-gtk.desktop" "software-properties-livepatch.desktop"
    "update-manager.desktop"
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
# 9. Configuração da Rotação de Senhas e Extensões (GNOME RDP)
# ------------------------------------------------------------
echo "[INFO] Configurando scripts de rotação de senhas e RDP..."

cat <<EOF > "/usr/local/bin/update-user-info.sh"
#!/bin/bash
EXT_UUID="hostnameIP@ornan-matos"
EXT_BG_LOGO="background-logo@fedorahosted.org"

SENHAS=( "SolLua27" "MarVento84" "PedraRio15" "FogoTerra62" "CactoAreia39" "NuvemCeo48" "MonteVale73" "FolhaTronco21" "LagoIlha56" "RosaJardim90" )
DIA_DO_ANO=\$(date +%-j)
INDICE=\$(( DIA_DO_ANO % \${#SENHAS[@]} ))
SENHA_DO_DIA="\${SENHAS[\$INDICE]}"

sleep 5

gnome-extensions disable "\$EXT_BG_LOGO" 2>/dev/null || true
gnome-extensions enable "\$EXT_UUID" 2>/dev/null || true

if command -v grdctl >/dev/null 2>&1; then
    mkdir -p ~/.local/share/gnome-remote-desktop
    if [ ! -f ~/.local/share/gnome-remote-desktop/rdp-tls.key ]; then
        openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=BR/O=GiuSoft/CN=giusoft-rdp" -keyout ~/.local/share/gnome-remote-desktop/rdp-tls.key -out ~/.local/share/gnome-remote-desktop/rdp-tls.crt
        gsettings set org.gnome.desktop.remote-desktop.rdp tls-key "\$HOME/.local/share/gnome-remote-desktop/rdp-tls.key"
        gsettings set org.gnome.desktop.remote-desktop.rdp tls-cert "\$HOME/.local/share/gnome-remote-desktop/rdp-tls.crt"
    fi

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

if ! id "admings" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo admings
fi

cat <<'EOF' > "/usr/local/bin/rotate-admin-pass.sh"
#!/bin/bash
SENHAS_ADMIN=( "LeaoTigre14" "FerroAco67" "CobrePrata52" "LivroPapel31" "MesaCadeira88" "MotorRoda46" "JanelaPorta79" "TeclaMouse23" "TelaCabo64" "BalaFoguete95" )
DIA_DO_ANO=$(date +%-j)
INDICE=$(( DIA_DO_ANO % ${#SENHAS_ADMIN[@]} ))
SENHA_ADMIN_DIA="${SENHAS_ADMIN[$INDICE]}"
echo "admings:$SENHA_ADMIN_DIA" | chpasswd
EOF
chmod 700 /usr/local/bin/rotate-admin-pass.sh
/usr/local/bin/rotate-admin-pass.sh

cat <<'EOF' > /etc/cron.d/giusoft-admin-rotation
@reboot root /usr/local/bin/rotate-admin-pass.sh
EOF

# ------------------------------------------------------------
# 10. Firewalld e Cockpit (Substituindo UFW)
# ------------------------------------------------------------
echo "[INFO] Configurando Firewalld e Cockpit..."
systemctl disable --now ufw || true

systemctl enable --now cockpit.socket
systemctl enable --now firewalld

firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=cockpit
firewall-cmd --permanent --add-port=3389/tcp 
firewall-cmd --permanent --add-port=3389/udp
firewall-cmd --reload
systemctl enable --now ssh

# ------------------------------------------------------------
# 11. Wallpaper e Dconf (Script Universal)
# ------------------------------------------------------------
echo "[INFO] Configurando Wallpaper e Dconf..."
WALLPAPER_DST="/usr/share/backgrounds/giusoft/giusoft-wallpaper.png"
install -d -m 0755 "$(dirname "$WALLPAPER_DST")"

cat <<EOF > /usr/local/bin/giusoft-update-wallpaper.sh
#!/bin/bash
cd /opt/giusoft/FreeIPA || exit 1
git checkout . >/dev/null 2>&1
CURRENT_BRANCH=\$(git rev-parse --abbrev-ref HEAD)
git pull origin "\$CURRENT_BRANCH"
if [ -f "Wallpaper.png" ]; then
    DEST="/usr/share/backgrounds/giusoft/giusoft-wallpaper.png"
    mkdir -p "\$(dirname "\$DEST")"
    cp -f Wallpaper.png "\$DEST"
    chmod 644 "\$DEST"
fi
EOF
chmod +x /usr/local/bin/giusoft-update-wallpaper.sh
/usr/local/bin/giusoft-update-wallpaper.sh

install -d -m 0755 /etc/dconf/db/local.d
install -d -m 0755 /etc/dconf/profile

cat >/etc/dconf/db/local.d/01-giusoft-wallpaper <<EOF
[org/gnome/desktop/background]
picture-uri='file://${WALLPAPER_DST}'
picture-uri-dark='file://${WALLPAPER_DST}'
picture-options='zoom'
[org/gnome/desktop/screensaver]
picture-uri='file://${WALLPAPER_DST}'
EOF

echo "0 15 2,16 * * root /usr/local/bin/giusoft-update-wallpaper.sh" > /etc/cron.d/giusoft-wallpaper-update

if ! grep -q '^user-db:local' /etc/dconf/profile/user 2>/dev/null; then
    cat >/etc/dconf/profile/user <<'EOF'
user-db:user
user-db:local
system-db:local
EOF
fi

cat >/etc/dconf/db/local.d/02-giusoft-power <<EOF
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=0
sleep-inactive-battery-type='nothing'
EOF

# Logo GDM
GDM_LOGO_SRC_FILE="$GIT_REPO_DIR/logo-full.png"
[ ! -f "$GDM_LOGO_SRC_FILE" ] && GDM_LOGO_SRC_FILE="$GIT_REPO_DIR/logo-gdm.png"
LOGO_DST="/usr/share/pixmaps/giusoft-gdm-logo.png"

if [ -f "$GDM_LOGO_SRC_FILE" ]; then
    cp -f "$GDM_LOGO_SRC_FILE" "$LOGO_DST"
    chmod 0644 "$LOGO_DST"
    
    cat >/etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
    mkdir -p /etc/dconf/db/gdm.d
    cat >/etc/dconf/db/gdm.d/01-logo <<EOF
[org/gnome/login-screen]
logo='${LOGO_DST}'
EOF
fi

# Ajustes de UI e Locks
cat >/etc/dconf/db/local.d/03-giusoft-app-sort <<EOF
[org/gnome/shell]
app-picker-sort-order='name'
EOF

cat >/etc/dconf/db/local.d/04-giusoft-window-buttons <<EOF
[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'
EOF

mkdir -p /etc/dconf/db/local.d/locks
cat >/etc/dconf/db/local.d/locks/00-giusoft-locks <<EOF
/org/gnome/desktop/background/picture-uri
/org/gnome/desktop/background/picture-uri-dark
/org/gnome/desktop/background/picture-options
/org/gnome/desktop/screensaver/picture-uri
/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-timeout
/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type
/org/gnome/shell/app-picker-sort-order
/org/gnome/desktop/wm/preferences/button-layout
EOF

dconf update

# ------------------------------------------------------------
# 12. DNS e Rede
# ------------------------------------------------------------
echo "[INFO] Configurando DNS e Domínio para TODAS as conexões..."

for conn in $(nmcli -t -f UUID connection show); do
    nmcli connection modify "$conn" \
        ipv4.dns "192.168.1.199 1.1.1.1" \
        ipv4.ignore-auto-dns yes \
        ipv4.dns-search "gs.internal"
    
    nmcli connection up "$conn" >/dev/null 2>&1 || true
done

RESOLVED_CONF="/etc/systemd/resolved.conf"
if [ -f "$RESOLVED_CONF" ]; then
    sed -i 's/^[#]*DNS=.*/DNS=192.168.1.199 1.1.1.1/' "$RESOLVED_CONF"
    sed -i 's/^[#]*FallbackDNS=.*/FallbackDNS=8.8.8.8/' "$RESOLVED_CONF"
    sed -i 's/^[#]*Domains=.*/Domains=gs.internal/' "$RESOLVED_CONF"
    systemctl restart systemd-resolved || true
fi

# ------------------------------------------------------------
# 13. Permissões de USB e Polkit (Grupo Implant/Powerusers)
# ------------------------------------------------------------
echo "[INFO] Configurando permissões USB e regras Polkit..."

groupadd -f implant
groupadd -f powerusers
groupadd -f admins

cat <<EOF > /etc/udev/rules.d/99-implant-usb.rules
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", GROUP="implant", MODE="0664"
SUBSYSTEM=="tty", KERNEL=="ttyUSB*|ttyACM*", GROUP="implant", MODE="0660"
EOF
udevadm control --reload-rules || true
udevadm trigger || true

flatpak override --system --device=all || true

cat <<'EOF' > /etc/polkit-1/rules.d/10-giusoft-powerusers.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("admins") || subject.isInGroup("powerusers") || subject.isInGroup("implant")) {
        if (action.id.indexOf("org.opensuse.cupspkhelper.mechanism.") == 0 ||
            action.id == "org.fedoraproject.config.printer.configure") {
            return polkit.Result.YES;
        }
        if (action.id.indexOf("org.freedesktop.udisks2.") == 0) {
            return polkit.Result.YES;
        }
        if (action.id.indexOf("org.kde.kpmcore.") == 0) {
            return polkit.Result.YES;
        }
        if (action.id.indexOf("com.raspberrypi.rpi-imager.") == 0 || 
            action.id.indexOf("org.raspberrypi.rpi-imager.") == 0) {
            return polkit.Result.YES;
        }
    }
});
EOF

cat <<EOF > /etc/polkit-1/rules.d/61-restrict-remote-desktop.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.gnome.RemoteDesktop.configure") { return polkit.Result.AUTH_ADMIN; }
});
EOF
systemctl restart polkit || true

# ------------------------------------------------------------
# 14. Instalação e Configuração do RustDesk (Acesso Remoto TI)
# ------------------------------------------------------------
echo "[INFO] Verificando/Instalando RustDesk para Suporte Remoto Local..."
RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.4.6/rustdesk-1.4.6-x86_64.deb"
RUSTDESK_TMP="/tmp/rustdesk.deb"

if ! command -v rustdesk >/dev/null 2>&1; then
    echo "[INFO] Aguardando a rede estabilizar antes do download..."
    for i in {1..15}; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 1.1.1.1 >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    echo "[INFO] Baixando RustDesk (.deb)..."
    wget --tries=5 --timeout=15 --waitretry=3 -qO "$RUSTDESK_TMP" "$RUSTDESK_URL" || true
    
    if [ -s "$RUSTDESK_TMP" ]; then
        dpkg -i "$RUSTDESK_TMP" || apt-get install -f -y || true
        rm -f "$RUSTDESK_TMP"
    else
        echo "[ERRO] Falha ao baixar o arquivo do RustDesk."
    fi
else
    echo "[INFO] RustDesk já instalado. Pulando etapa de instalação."
fi

if command -v rustdesk >/dev/null 2>&1; then
    echo "[INFO] Aplicando configurações do RustDesk..."
    
    firewall-cmd --permanent --add-port=21118-21119/tcp || true
    firewall-cmd --reload || true
    
    RUSTDESK_CONF="/etc/rustdesk/RustDesk2.toml"
    mkdir -p /etc/rustdesk
    touch "$RUSTDESK_CONF"
    if ! grep -q "direct-server" "$RUSTDESK_CONF"; then
        echo "direct-server = 'Y'" >> "$RUSTDESK_CONF"
    else
        sed -i "s/direct-server.*/direct-server = 'Y'/g" "$RUSTDESK_CONF"
    fi
    
    systemctl enable --now rustdesk || true
    systemctl restart rustdesk || true
    sleep 3
    
    rustdesk --password "GiuSoft@Admin" || echo "[AVISO] Definição de senha via CLI retornou erro não fatal. Prosseguindo..."

    echo "[INFO] Sincronizando configurações do RustDesk para todos os perfis..."
    for USER_HOME in /home/* /etc/skel; do
        if [ -d "$USER_HOME" ]; then
            USER_RUST_DIR="$USER_HOME/.config/rustdesk"
            mkdir -p "$USER_RUST_DIR"
            
            cp -f "$RUSTDESK_CONF" "$USER_RUST_DIR/RustDesk2.toml" || true
            
            if [ -d "/root/.config/rustdesk" ]; then
                cp -f /root/.config/rustdesk/*.toml "$USER_RUST_DIR/" 2>/dev/null || true
            fi
            
            if [[ "$USER_HOME" != "/etc/skel" ]]; then
                OWNER=$(basename "$USER_HOME")
                chown -R "$OWNER":"$OWNER" "$USER_RUST_DIR" || true
            fi
        fi
    done
    echo "[SUCESSO] RustDesk configurado para IP Local em todos os usuários!"
fi

echo ""
echo "============================================================"
echo "[FINALIZADO] Script de pós-instalação GiuSoft concluído."
echo "IMPORTANTE: REINICIE O COMPUTADOR para aplicar tudo."
echo "============================================================"
echo ""
echo "Próximos passos manuais recomendados:"
echo ""
echo "1. Fazer o join no FreeIPA (ipa.gs.internal):"
echo "   =========================================="
echo "   sudo ipa-client-install --uninstall -U"
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
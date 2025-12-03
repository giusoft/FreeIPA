#!/bin/bash
# ============================================================
# Fedora - Ambiente GiuSoft
# Autor: Ornan S. Matos 
# Versão 1.4 
# ============================================================

set -euo pipefail
LOGFILE="/var/log/pos-instalacao-giusoft-fedora.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Iniciando pós-instalação GiuSoft (Fedora - Versão 12.3) ==="
echo "Log será salvo em: $LOGFILE"

# Flag padrão para DNF
DNF_INSTALL_FLAGS="--skip-unavailable"

# ------------------------------------------------------------
# 1. Otimiza a configuração do DNF
# ------------------------------------------------------------
echo "[INFO] Otimizando DNF..."
grep -q '^fastestmirror=' /etc/dnf/dnf.conf 2>/dev/null || echo "fastestmirror=True" | tee -a /etc/dnf/dnf.conf
grep -q '^max_parallel_downloads=' /etc/dnf/dnf.conf 2>/dev/null || echo "max_parallel_downloads=10" | tee -a /etc/dnf/dnf.conf
grep -q '^defaultyes=' /etc/dnf/dnf.conf 2>/dev/null || echo "defaultyes=True" | tee -a /etc/dnf/dnf.conf

# ------------------------------------------------------------
# 2. Atualiza sistema
# ------------------------------------------------------------
echo "[INFO] Atualizando sistema..."
dnf update --refresh -y $DNF_INSTALL_FLAGS

# ------------------------------------------------------------
# 3. Habilita RPM Fusion (Free e Nonfree) + codecs
# ------------------------------------------------------------
echo "[INFO] Habilitando RPM Fusion..."
FEDORA_VERSION="$(rpm -E %fedora)"
dnf install -y $DNF_INSTALL_FLAGS \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

dnf4 groupupdate -y core
dnf4 groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
dnf4 groupupdate -y sound-and-video

# ------------------------------------------------------------
# 4. Utilitários básicos
# ------------------------------------------------------------
dnf install -y $DNF_INSTALL_FLAGS wget curl gnupg ca-certificates git unzip jq glib2-devel dnf-plugins-core

# ------------------------------------------------------------
# 5. Repositório Google Chrome
# ------------------------------------------------------------
cat > /etc/yum.repos.d/google-chrome.repo <<'EOF'
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
dnf install -y $DNF_INSTALL_FLAGS google-chrome-stable

# ------------------------------------------------------------
# 6. Clona repositório GiuSoft
# ------------------------------------------------------------
GIT_REPO_DIR="/opt/giusoft/FreeIPA"
mkdir -p /opt/giusoft

# --- Configuração de segurança do Git ---
git config --global --add safe.directory "$GIT_REPO_DIR"

if [ -d "$GIT_REPO_DIR/.git" ]; then
    (cd "$GIT_REPO_DIR" && git pull)
else
    git clone https://github.com/giusoft/FreeIPA.git "$GIT_REPO_DIR"
fi

# ------------------------------------------------------------
# 7. Instala Zoiper 5
# ------------------------------------------------------------
ZOIPER_RPM_PATH="$GIT_REPO_DIR/Zoiper.rpm"
if [ -f "$ZOIPER_RPM_PATH" ]; then
    dnf install -y $DNF_INSTALL_FLAGS gtk2 libXScrnSaver ibus-gtk2 libcanberra-gtk2 adwaita-gtk2-theme highcontrast-icon-theme
    rpm -U --nodigest --nosignature "$ZOIPER_RPM_PATH"
fi

# ------------------------------------------------------------
# 8. Instalação da Extensão HostnameIP
# ------------------------------------------------------------
echo "[INFO] Instalando extensão GNOME 'hostnameIP'..."

# Limpeza prévia
rm -rf /tmp/hostnameIP-build
git clone -b dev "https://github.com/ornan-matos/gnome-shell-extension-hostnameIP.git" /tmp/hostnameIP-build

EXT_SRC="/tmp/hostnameIP-build/hostnameIP@ornan-matos"

if [ -d "$EXT_SRC" ] && [ -f "$EXT_SRC/metadata.json" ]; then
    # Extrai UUID
    EXT_UUID=$(jq -r .uuid < "$EXT_SRC/metadata.json")
    EXT_SYS_DIR="/usr/share/gnome-shell/extensions/$EXT_UUID"

    echo "[INFO] Instalando em: $EXT_SYS_DIR"
    rm -rf "$EXT_SYS_DIR"
    mkdir -p "$EXT_SYS_DIR"
    
    # Copia recursivamente preservando atributos
    cp -r "$EXT_SRC"/* "$EXT_SYS_DIR/"
    
    TARGET_FILE="$EXT_SYS_DIR/extension.js"
    if [ -f "$TARGET_FILE" ]; then
        echo "[INFO] Aplicando patch de filtro de IP (Método Seguro)..."
        sed -i "s|return addr.to_string();|if(addr.to_string().substring(0,3)!='127')return addr.to_string();|" "$TARGET_FILE"
    fi
    
    # Atualiza versão do shell no metadata.json
    META="$EXT_SYS_DIR/metadata.json"
    if [ -f "$META" ]; then
        jq --arg v "46" '.["shell-version"] |= (. + [$v] | unique)' "$META" > "${META}.tmp" && mv "${META}.tmp" "$META"
    fi
    
    # Permissões
    chmod -R 755 "$EXT_SYS_DIR"
    
    if [ -d "$EXT_SYS_DIR/schemas" ]; then
        glib-compile-schemas "$EXT_SYS_DIR/schemas"
    fi
else
    echo "[ERRO] Falha ao clonar ou encontrar metadata da extensão HostnameIP."
fi

# ------------------------------------------------------------
# 9. Outras Extensões (Corrigido: Dash-to-Dock/Panel)
# ------------------------------------------------------------
# Instala dependência para tradução (msgfmt)
dnf install -y $DNF_INSTALL_FLAGS make sassc gettext

# --- Dash-to-Dock ---
EXT_D2D_REPO_DIR="/opt/dash-to-dock-ext"
EXT_UUID_D2D="dash-to-dock@micxgx.gmail.com"
EXT_DEST_SYSLOC="/usr/share/gnome-shell/extensions"
EXT_D2D_DEST_DIR="$EXT_DEST_SYSLOC/$EXT_UUID_D2D"

# Clone ou Pull
if [ -d "$EXT_D2D_REPO_DIR/.git" ]; then
    (cd "$EXT_D2D_REPO_DIR" && git pull)
else
    git clone "https://github.com/micheleg/dash-to-dock.git" "$EXT_D2D_REPO_DIR"
fi

if [ -d "$EXT_D2D_REPO_DIR" ]; then
    echo "[INFO] Compilando Dash-to-Dock..."
    (cd "$EXT_D2D_REPO_DIR" && make)
    
    echo "[INFO] Instalando Dash-to-Dock..."
    rm -rf "$EXT_D2D_DEST_DIR"
    mkdir -p "$EXT_D2D_DEST_DIR"
    # Copia todos os arquivos da raiz do repositório
    cp -r "$EXT_D2D_REPO_DIR/"* "$EXT_D2D_DEST_DIR/"
    # Remove lixo do git da pasta de destino
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
    echo "[INFO] Compilando Dash-to-Panel..."
    (cd "$EXT_D2P_REPO_DIR" && make)
    
    echo "[INFO] Instalando Dash-to-Panel..."
    rm -rf "$EXT_D2P_DEST_DIR"
    mkdir -p "$EXT_D2P_DEST_DIR"
    # Copia da raiz do repo
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
# 10. Repositório OwnCloud Client
# ------------------------------------------------------------
OWNCLOUD_FEDORA_REPO_VERSION="41"
rpm --import "https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Fedora_${OWNCLOUD_FEDORA_REPO_VERSION}/repodata/repomd.xml.key"
dnf4 config-manager --add-repo "https://download.owncloud.com/desktop/ownCloud/stable/latest/linux/Fedora_${OWNCLOUD_FEDORA_REPO_VERSION}/owncloud-client.repo"
dnf clean all

# ------------------------------------------------------------
# 11. Pacotes adicionais
# ------------------------------------------------------------
echo "[INFO] Instalando pacotes adicionais..."

# Adiciona Flathub
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

dnf install -y $DNF_INSTALL_FLAGS \
    vim nano htop tmux zsh bash-completion \
    net-tools telnet traceroute nmap bind-utils iperf3 \
    rsync tree zip p7zip p7zip-plugins unrar \
    fontconfig dejavu-sans-mono-fonts liberation-fonts \
    glibc-langpack-pt-BR langpacks-pt_BR \
    @fonts @base-x @multimedia @sound-and-video \
    gstreamer1-plugins-good gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly \
    gstreamer1-libav gstreamer1-plugins-base-tools \
    flatpak libreoffice libreoffice-langpack-pt-BR libreoffice-help-pt-BR hunspell-pt-BR \
    sssd oddjob adcli realmd sssd-tools \
    samba cifs-utils ipa-client krb5-workstation \
    gnome-remote-desktop \
    cockpit cockpit-machines cockpit-storaged cockpit-networkmanager cockpit-packagekit cockpit-pcp pcp-zeroconf \
    gdm gnome-extensions-app file-roller nautilus crond \
    owncloud-client inxi glmark2 fio stress-ng lm_sensors


dnf remove -y gnome-tweaks gnome-shell-extension-background-logo

# ------------------------------------------------------------
# 12. Ocultar Aplicações 
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
    "com.github.ADBeveridge.Papers.desktop" "io.bina.Showtime.desktop"
)


GLOBAL_OVERRIDE_DIR="/usr/local/share/applications"
mkdir -p "$GLOBAL_OVERRIDE_DIR"

for app in "${HIDDEN_APPS[@]}"; do
    SRC=""
    [ -f "/usr/share/applications/$app" ] && SRC="/usr/share/applications/$app"
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

# mkdir /etc/cron.d/

# ------------------------------------------------------------
# 13. Configuração da Rotação de Senhas e Extensões
# ------------------------------------------------------------
echo "[INFO] Configurando scripts de rotação de senhas..."

# Script de login (RDP + HostnameIP + Desativar Background Logo)
cat <<EOF > "/usr/local/bin/update-user-info.sh"
#!/bin/bash

# Variáveis
EXT_UUID="hostnameIP@ornan-matos"
EXT_BG_LOGO="background-logo@fedorahosted.org"

# --- ALGORITMO DE SENHA BASEADO EM HOST E DATA ---
HOST_CLEAN=\$(hostname | tr '[:upper:]' '[:lower:]' | tr -d ' ')
HOST_SEED=\$(echo -n "\$HOST_CLEAN" | cksum | cut -f1 -d" ")

# Lista Senhas RDP
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

DIA_DO_ANO=\$(date +%-j)
# Módulo 10 para usar todas as senhas
INDICE=\$(( (DIA_DO_ANO + HOST_SEED) % 10 ))
SENHA_DO_DIA="\${SENHAS[\$INDICE]}"

sleep 5

# -- GESTÃO DE EXTENSÕES --
# 1. Desativa Background Logo (Padrão Fedora)
gnome-extensions disable "\$EXT_BG_LOGO" 2>/dev/null || true

# 2. Ativa HostnameIP (Automaticamente)
gnome-extensions enable "\$EXT_UUID" 2>/dev/null || true

CURRENT_IP=\$(hostname -I | awk '{for(i=1;i<=NF;i++) if (\$i !~ /^127/ && \$i !~ /^172\.17/ && \$i !~ /^172\.18/) {print \$i; exit}}')
[ -z "\$CURRENT_IP" ] && CURRENT_IP=\$(hostname -I | awk '{print \$1}')

# -- CONFIGURAÇÃO RDP / CONTROLE REMOTO --
if command -v grdctl >/dev/null 2>&1; then
    # Define senha rotativa
    grdctl rdp set-credentials "\$USER" "\$SENHA_DO_DIA" || true
    
    # GARANTE CONTROLE REMOTO (Não apenas visualização)
    grdctl rdp set-view-only false || true
    gsettings set org.gnome.desktop.remote-desktop.rdp view-only false || true
    
    # Ativa RDP
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

# Configuração Admin (admings)
echo "[INFO] Configurando rotação de senha separada para admings..."

if ! id "admings" &>/dev/null; then
    useradd -m -s /bin/bash -G wheel admings
fi

cat <<'EOF' > "/usr/local/bin/rotate-admin-pass.sh"
#!/bin/bash

HOST_CLEAN=$(hostname | tr '[:upper:]' '[:lower:]' | tr -d ' ')
HOST_SEED=$(echo -n "$HOST_CLEAN" | cksum | cut -f1 -d" ")

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
INDICE=$(( (DIA_DO_ANO + HOST_SEED) % 10 ))
SENHA_ADMIN_DIA="${SENHAS_ADMIN[$INDICE]}"

echo "admings:$SENHA_ADMIN_DIA" | chpasswd
EOF
chmod 700 /usr/local/bin/rotate-admin-pass.sh

# Executa rotação inicial
/usr/local/bin/rotate-admin-pass.sh

# --- Adicionado execução diária atráves do reboot---
cat <<'EOF' > /etc/cron.d/giusoft-admin-rotation
@reboot root /usr/local/bin/rotate-admin-pass.sh
EOF

# ------------------------------------------------------------
# 14. Firewalld e Cockpit
# ------------------------------------------------------------
systemctl enable --now cockpit.socket
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=cockpit
firewall-cmd --reload
systemctl enable --now sshd

# ------------------------------------------------------------
# 15. Wallpaper e Dconf (COM SCRIPT DE UPDATE UNIVERSAL)
# ------------------------------------------------------------
WALLPAPER_DST="/usr/share/backgrounds/giusoft/giusoft-wallpaper.png"
install -d -m 0755 "$(dirname "$WALLPAPER_DST")"

# ---  Criação do script de atualização (Universal) ---
cat <<EOF > /usr/local/bin/giusoft-update-wallpaper.sh
#!/bin/bash
# Script de atualização do Wallpaper GiuSoft (Universal Fedora/Ubuntu)

cd /opt/giusoft/FreeIPA || exit 1

# Garante que não há alterações locais
git checkout . >/dev/null 2>&1

# Pega o branch atual e atualiza
CURRENT_BRANCH=\$(git rev-parse --abbrev-ref HEAD)
echo "[INFO] Atualizando repositório (Branch: \$CURRENT_BRANCH)..."
git pull origin "\$CURRENT_BRANCH"

if [ -f "Wallpaper.png" ]; then
    # --- CAMINHO 1: Padrão Fedora ---
    DEST_FEDORA="/usr/share/backgrounds/giusoft/giusoft-wallpaper.png"
    # Cria diretório caso não exista (importante para Fedora)
    mkdir -p "\$(dirname "\$DEST_FEDORA")"
    cp -f Wallpaper.png "\$DEST_FEDORA"
    chmod 644 "\$DEST_FEDORA"
    
    # --- CAMINHO 2: Padrão Ubuntu ---
    DEST_UBUNTU="/usr/share/backgrounds/giusoft/Wallpaper.png"
    # (Mantido para compatibilidade universal do script)
    
    echo "[SUCESSO] Imagens atualizadas em: \$(date)"
else
    echo "[ERRO] Arquivo Wallpaper.png não encontrado no repositório."
fi
EOF

# Permissões
chmod +x /usr/local/bin/giusoft-update-wallpaper.sh

# Executa agora para configurar o visual imediatamente
echo "--- Aplicando correção visual agora ---"
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

# --- Cron usa o script universal agora ---
echo "0 15 2,16 * * root /usr/local/bin/giusoft-update-wallpaper.sh" > /etc/cron.d/giusoft-wallpaper-update

if ! grep -q '^user-db:local' /etc/dconf/profile/user 2>/dev/null; then
    cat >/etc/dconf/profile/user <<'EOF'
user-db:user
user-db:local
system-db:local
EOF
fi

# Energia (Disable suspend)
cat >/etc/dconf/db/local.d/02-giusoft-power <<EOF
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=0
sleep-inactive-battery-type='nothing'
EOF

# ------------------------------------------------------------
# 16. Logo do GDM
# ------------------------------------------------------------
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
    

    [ -d "/usr/share/plymouth/themes/spinner" ] && cp -f "$GDM_LOGO_SRC_FILE" /usr/share/plymouth/themes/spinner/watermark.png
fi

# ------------------------------------------------------------
# 17. Locks e Update Dconf
# ------------------------------------------------------------
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
/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout
/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type
/org/gnome/shell/app-picker-sort-order
/org/gnome/desktop/wm/preferences/button-layout
EOF

dconf update

# ------------------------------------------------------------
# 18. DNS e Rede
# ------------------------------------------------------------
ACTIVE_ETH=$(nmcli -t -f UUID,TYPE connection show | grep "802-3-ethernet" | cut -d: -f1 | head -n1 || true)
if [ -n "$ACTIVE_ETH" ]; then
    echo "[INFO] Configurando DNS ETH via nmcli (Paridade Ubuntu): $ACTIVE_ETH"
    nmcli connection modify "$ACTIVE_ETH" ipv4.dns "192.168.1.199 1.1.1.1" ipv4.ignore-auto-dns yes ipv4.dns-search "gs.internal"
    nmcli connection up "$ACTIVE_ETH" || true
else
    # Fallback para systemd-resolved se nenhuma interface estiver ativa ainda
    RESOLVED_CONF="/etc/systemd/resolved.conf"
    if [ -f "$RESOLVED_CONF" ]; then
        sed -i "s/^#DNS=.*/DNS=192.168.1.199/" "$RESOLVED_CONF"
        sed -i "s/^#FallbackDNS=.*/FallbackDNS=1.1.1.1 8.8.8.8/" "$RESOLVED_CONF"
        sed -i "s/^#Domains=.*/Domains=gs.internal/" "$RESOLVED_CONF"
        systemctl restart systemd-resolved || true
    fi
fi

# ------------------------------------------------------------
# 19. Finalização
# ------------------------------------------------------------

# Bloqueio de configuração manual do RDP via GUI
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

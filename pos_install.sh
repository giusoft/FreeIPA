#!/bin/bash

# Define para sair imediatamente se um comando falhar
set -e

# --- 1. Verificação de Root ---
if [ "$(id -u)" -ne 0 ]; then
   echo "[ERRO] Este script deve ser executado como root." >&2
   exit 1
fi

echo "[INFO] Iniciando script de pós-instalação para Ubuntu/Debian..."

# --- 2. Atualização e Instalação de Pacotes ---
echo "[INFO] Atualizando listas de pacotes..."
apt-get update

echo "[INFO] Instalando pacotes necessários..."

PACKAGES=(
    "chrony"
    "certmonger"
    "freeipa-client"
    "oddjob-mkhomedir"
    "oddjob"
    "openssh-server"
    "tailscale"
)

# O -y aceita automaticamente
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

# --- 3. Habilitação de Serviços ---
echo "[INFO] Habilitando e iniciando serviços..."

# O serviço SSH no Debian/Ubuntu é 'ssh'
systemctl enable --now ssh
echo "[SUCCESS] Serviço 'ssh' habilitado e iniciado."

systemctl enable --now tailscaled
echo "[SUCCESS] Serviço 'tailscaled' habilitado e iniciado."

# Serviços de dependência para o FreeIPA e mkhomedir
# O serviço do Chrony no Debian/Ubuntu é 'chrony'
systemctl enable --now chrony
echo "[SUCCESS] Serviço 'chrony' habilitado e iniciado."
# O serviço do Oddjob no Debian/Ubuntu é 'oddjob'
systemctl enable --now oddjob
echo "[SUCCESS] Serviço 'oddjob' habilitado e iniciado."


# --- 4. Cria grupo powerusers e regra polkit (Sua regra) ---
echo "[INFO] Criando grupo 'powerusers' e regra Polkit para desligar/reiniciar..."
# O -f impede erro caso o grupo já exista
groupadd -f powerusers

# Cria a regra Polkit para powerusers
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
echo "[SUCCESS] Regra Polkit '40-regras-personalizadas.rules' criada."

# --- 5. Cria regra Polkit para bloquear GNOME Settings ---
echo "[INFO] Criando regra Polkit para restringir o GNOME Settings..."

cat > /etc/polkit-1/rules.d/50-gnome-settings-lockdown.rules <<'EOF'
/* Impede que usuários não-administrativos (fora do grupo 'sudo')
  modifiquem configurações de sistema no GNOME Settings (gnome-control-center).
  Isto nega qualquer ação que normalmente exigiria senha de administrador.
*/
polkit.addRule(function(action, subject) {
    if (action.id.startsWith("org.gnome.controlcenter.") &&
        (action.lookup("polkit.auth_admin") == "true" ||
         action.lookup("polkit.auth_admin_keep") == "true") &&
        !subject.isInGroup("sudo"))  /* <-- 'sudo' para Ubuntu */
    {
        // Nega a ação completamente, em vez de pedir uma senha de admin
        // que o usuário não possui.
        return polkit.Result.NO;
    }
});
EOF

chmod 644 /etc/polkit-1/rules.d/50-gnome-settings-lockdown.rules
echo "[SUCCESS] Regra Polkit '50-gnome-settings-lockdown.rules' criada."

# --- 6. Conclusão ---
echo ""
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

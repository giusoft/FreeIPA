#!/bin/bash
# ============================================================
# Consulta Rápida de Senhas Diárias - Ambiente GiuSoft
# ============================================================

# Listas exatas configuradas nas máquinas clientes
SENHAS_RDP=(
    "SolLua27" "MarVento84" "PedraRio15" "FogoTerra62" "CactoAreia39" 
    "NuvemCeo48" "MonteVale73" "FolhaTronco21" "LagoIlha56" "RosaJardim90"
)

SENHAS_ADMIN=(
    "LeaoTigre14" "FerroAco67" "CobrePrata52" "LivroPapel31" "MesaCadeira88" 
    "MotorRoda46" "JanelaPorta79" "TeclaMouse23" "TelaCabo64" "BalaFoguete95"
)

# Cálculo baseado no dia de hoje
DIA_DO_ANO=$(date +%-j)
INDICE_RDP=$(( DIA_DO_ANO % ${#SENHAS_RDP[@]} ))
INDICE_ADMIN=$(( DIA_DO_ANO % ${#SENHAS_ADMIN[@]} ))

# Saída formatada
clear
echo "========================================"
echo " 🔑 SENHAS GIUSOFT - $(date '+%d/%m/%Y')"
echo "========================================"
echo " Dia do ano (Índice): $DIA_DO_ANO"
echo "----------------------------------------"
echo " 🖥️  Acesso Remoto (RDP/RustDesk)"
echo " Usuário logado + Senha:"
echo " ➔  ${SENHAS_RDP[$INDICE_RDP]}"
echo "----------------------------------------"
echo " 🛡️  Administrador Local (admings)"
echo " Usuário: admings"
echo " ➔  ${SENHAS_ADMIN[$INDICE_ADMIN]}"
echo "========================================"
echo ""
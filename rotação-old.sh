#!/bin/bash
# ============================================================
# Decodificador de Senhas GiuSoft
# ============================================================

echo "=== GERADOR DE SENHAS MESTRA GIUSOFT ==="
echo "Algoritmo: Hostname Checksum + Rotação Separada"
echo ""

read -p "Digite o HOSTNAME da máquina alvo: " TARGET_HOST
HOST_CLEAN=$(echo "$TARGET_HOST" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

if [ -z "$HOST_CLEAN" ]; then echo "Erro: Hostname vazio."; exit 1; fi


HOST_SEED=$(echo -n "$HOST_CLEAN" | cksum | cut -f1 -d" ")
DIA_DO_ANO=$(date +%-j)
DATA_HOJE=$(date +"%d/%m/%Y")


INDICE=$(( (DIA_DO_ANO + HOST_SEED) % 10 ))


SENHAS_RDP=(
    "User@${HOST_CLEAN}#78"
    "Access#${HOST_CLEAN}!04"
    "Desk\$${HOST_CLEAN}&92"
    "Remote@${HOST_CLEAN}#11"
    "Rdp#${HOST_CLEAN}!33"
    "Client\$${HOST_CLEAN}&56"
    "Session@${HOST_CLEAN}#88"
    "Net#${HOST_CLEAN}!21"
    "Link\$${HOST_CLEAN}&43"
    "Gate@${HOST_CLEAN}#67"
)


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

echo ""
echo "-----------------------------------------------"
echo " Alvo: $HOST_CLEAN | Data: $DATA_HOJE"
echo "-----------------------------------------------"
echo "SENHA RDP (USUÁRIO/REMOTO):"
echo "    ${SENHAS_RDP[$INDICE]}"
echo ""
echo "SENHA ADMIN (USER: admings):"
echo "    ${SENHAS_ADMIN[$INDICE]}"
echo "-----------------------------------------------"
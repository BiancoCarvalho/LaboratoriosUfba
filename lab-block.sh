#!/bin/bash
# Lab Block
# v2.0.0
# Ativa o modo prova: cria 'prova', aplica policies SÓ nele, abre kiosk

set -e

USUARIO="prova"
URL="https://jude.dcc.ufba.br/auth/login"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# 1) Cria o usuário 'prova'
/usr/local/sbin/lab-prova-profile-config.sh

# 2) Aplica policies SOMENTE no perfil dele
/usr/local/sbin/lab-prova-config.sh

# 3) Espera
sleep 2

# 4) Mata Firefox antigo
pkill -KILL -f firefox 2>/dev/null || true
sleep 1

# 5) Abre Firefox kiosk como 'prova'
sudo -u "$USUARIO" DISPLAY=:0 firefox --kiosk "$URL" >> "$LOG" 2>&1 &

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

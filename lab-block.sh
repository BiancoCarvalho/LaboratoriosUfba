#!/bin/bash
# Lab Block
# v1.0.0
# Ativa o modo prova: cria usuário 'prova' e abre Firefox kiosk no JUDE

set -e

USUARIO="prova"
URL="https://jude.dcc.ufba.br/auth/login"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# 1) cria o usuário restrito (ou recria)
/usr/local/sbin/lab-prova-profile-config.sh

# 2) garante que as policies estão aplicadas
/usr/local/sbin/lab-prova-config.sh

# 3) espera o home do 'prova' ficar pronto
sleep 1

# 4) mata qualquer Firefox antigo
pkill -KILL -f firefox 2>/dev/null || true

# 5) abre Firefox kiosk como 'prova'
sudo -u "$USUARIO" DISPLAY=:0 firefox --kiosk "$URL" >> "$LOG" 2>&1 &

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

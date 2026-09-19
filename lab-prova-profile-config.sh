#!/bin/bash
# Lab Prova Profile Config
# v1.0.0
# Cria o usuário 'prova' (sem sudo) — NÃO aplica policies.

export DEBIAN_FRONTEND=noninteractive

USUARIO="prova"
SENHA="${PROVA_PASSWORD:-Pw#Lab2026!}"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-PROFILE-CONFIG" >> "$LOG"

if id "$USUARIO" &>/dev/null; then
    pkill -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

useradd \
    --create-home \
    --shell /bin/bash \
    --groups audio,video,cdrom,plugdev \
    "$USUARIO"

echo "$USUARIO:$SENHA" | chpasswd

deluser "$USUARIO" sudo 2>/dev/null || true
deluser "$USUARIO" adm  2>/dev/null || true

cat > /etc/sudoers.d/99-prova-bloqueado <<EOS
$USUARIO ALL=(ALL) !ALL
EOS
chmod 440 /etc/sudoers.d/99-prova-bloqueado

echo "[$(date '+%F %T')] PROVA-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

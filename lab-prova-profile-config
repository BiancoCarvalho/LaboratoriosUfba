#!/bin/bash
# Lab Prova Profile Config
# v1.0.0
# Cria o usuário restrito 'prova' (sem sudo) para o modo quiosque

export DEBIAN_FRONTEND=noninteractive

USUARIO="prova"
SENHA="${PROVA_PASSWORD:-prova@2026}"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-PROFILE-CONFIG" >> "$LOG"

# Se já existe, remove
if id "$USUARIO" &>/dev/null; then
    pkill -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

# Cria SEM sudo, com grupos não privilegiados
useradd \
    --create-home \
    --shell /bin/bash \
    --groups audio,video,cdrom,plugdev \
    "$USUARIO"

echo "$USUARIO:$SENHA" | chpasswd

# Garante que NÃO está em grupos privilegiados
deluser "$USUARIO" sudo 2>/dev/null || true
deluser "$USUARIO" adm  2>/dev/null || true

# Bloqueia sudo para o usuário 'prova'
cat > /etc/sudoers.d/99-prova-bloqueado <<EOF
# Usuário 'prova' não pode usar sudo nem su
$USUARIO ALL=(ALL) !ALL
EOF
chmod 440 /etc/sudoers.d/99-prova-bloqueado

echo "[$(date '+%F %T')] PROVA-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

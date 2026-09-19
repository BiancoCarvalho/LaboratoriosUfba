#!/bin/bash
# =====================================================================
#  lab-prova-profile-config.sh
#  v2.0.0
#
#  Cria (ou recria) o usuário restrito 'prova'.
#  NÃO tem sudo. Só acessa o Firefox com as policies aplicadas.
#
#  Localização: /usr/local/sbin/lab-prova-profile-config.sh
#  Uso: sudo /usr/local/sbin/lab-prova-profile-config.sh
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

USUARIO="prova"
SENHA="${PROVA_PASSWORD:-Pw#Lab2026!}"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-PROFILE-CONFIG" >> "$LOG"

# Se já existe, remove
if id "$USUARIO" &>/dev/null; then
    pkill -9 -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

# Cria sem sudo
useradd \
    --create-home \
    --shell /bin/bash \
    --groups audio,video,cdrom,plugdev \
    "$USUARIO"

echo "$USUARIO:$SENHA" | chpasswd 2>/dev/null || true

# Garante que NÃO está em grupos privilegiados
deluser "$USUARIO" sudo 2>/dev/null || true
deluser "$USUARIO" adm  2>/dev/null || true

# Bloqueia sudo
cat > /etc/sudoers.d/99-prova-bloqueado <<EOS
$USUARIO ALL=(ALL) !ALL
EOS
chmod 440 /etc/sudoers.d/99-prova-bloqueado

echo "[$(date '+%F %T')] PROVA-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

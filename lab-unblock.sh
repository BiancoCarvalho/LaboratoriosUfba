#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v2.0.0
#
#  Desativa o "modo prova": remove o usuário 'prova'.
#  Assim, todo o perfil (com policies) é apagado.
#
#  Localização: /usr/local/sbin/lab-unblock.sh
#  Uso: sudo /usr/local/sbin/lab-unblock.sh
# =====================================================================

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# Mata processos do 'prova'
pkill -9 -u "$USUARIO" 2>/dev/null || true

# Remove o usuário (e a home, com o perfil do Firefox)
if id "$USUARIO" &>/dev/null; then
    userdel -r "$USUARIO" 2>/dev/null || true
fi

# Remove regra do sudoers
rm -f /etc/sudoers.d/99-prova-bloqueado

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

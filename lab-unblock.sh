#!/bin/bash
# Lab Unblock
# v1.0.0
# Desativa o modo prova: fecha Firefox e remove o usuário 'prova'

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# 1) fecha Firefox e mata tudo do 'prova'
pkill -KILL -f firefox 2>/dev/null || true
pkill -KILL -u "$USUARIO" 2>/dev/null || true

# 2) remove o usuário 'prova'
if id "$USUARIO" &>/dev/null; then
    userdel -r "$USUARIO" 2>/dev/null || true
fi

# 3) remove a regra de bloqueio do sudoers
rm -f /etc/sudoers.d/99-prova-bloqueado

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v3.0.0
#
#  Desativa o modo prova: remove as policies.
#  Todos os usuários voltam a acessar tudo.
#
#  Localização: /usr/local/sbin/lab-unblock.sh
#  Uso: sudo /usr/local/sbin/lab-unblock.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Remove policies do Snap
# ---------------------------------------------------------------------
rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true

# ---------------------------------------------------------------------
# 2) Remove policies do .deb
# ---------------------------------------------------------------------
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true

# ---------------------------------------------------------------------
# 3) Mata o Firefox para forçar releitura
# ---------------------------------------------------------------------
pkill -9 firefox 2>/dev/null || true

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

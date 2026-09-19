#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v3.0.0
#  Desativa o modo prova: remove as policies.
# =====================================================================

set -e
LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true
pkill -9 firefox 2>/dev/null || true

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

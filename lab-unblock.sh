#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v4.0.0
#
#  Desativa o modo prova:
#    - Remove as policies do Firefox
#    - Remove as policies do Chrome / Chromium
#    - Mata os navegadores para forçar releitura
#
#  Localização: /usr/local/sbin/lab-unblock.sh
#  Uso: sudo /usr/local/sbin/lab-unblock.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# =====================================================================
# FIREFOX
# =====================================================================
rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true

# =====================================================================
# CHROME / CHROMIUM
# =====================================================================
rm -f /etc/opt/chrome/policies/managed/policies.json 2>/dev/null || true
rm -f /etc/opt/chromium/policies/managed/policies.json 2>/dev/null || true

# =====================================================================
# MATA OS NAVEGADORES
# =====================================================================
pkill -9 firefox 2>/dev/null || true
pkill -9 chrome 2>/dev/null || true
pkill -9 google-chrome 2>/dev/null || true
pkill -9 chromium 2>/dev/null || true

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v5.0.0
#
#  Desativa o modo prova:
#    - Remove as policies do Firefox (Snap + .deb)
#    - Remove as policies do Chrome / Chromium
#    - Mata os navegadores para forçar releitura
#
#  Localização: /usr/local/sbin/lab-unblock.sh
#  Uso: sudo /usr/local/sbin/lab-unblock.sh
# =====================================================================

set +e

LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# =====================================================================
# FIREFOX — remove TODOS os locais possíveis
# =====================================================================
rm -rf /var/snap/firefox/common/policies                 2>/dev/null
rm -rf /etc/firefox/policies                             2>/dev/null
rm -f  /usr/lib/firefox/distribution/policies.json       2>/dev/null
rm -f  /usr/lib/firefox/defaults/pref/*.json             2>/dev/null

# =====================================================================
# CHROME / CHROMIUM — remove TODOS os locais possíveis
# =====================================================================
rm -rf /etc/opt/chrome/policies/managed      2>/dev/null
rm -rf /etc/opt/chromium/policies/managed    2>/dev/null
rm -rf /etc/chromium/policies/managed        2>/dev/null

# =====================================================================
# MATA OS NAVEGADORES (para forçar releitura das policies)
# =====================================================================
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

# TERM (educado)
for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -TERM firefox   2>/dev/null
    sudo -u "$u" pkill -TERM chrome    2>/dev/null
    sudo -u "$u" pkill -TERM chromium  2>/dev/null
done

pkill -TERM firefox   2>/dev/null
pkill -TERM chrome    2>/dev/null
pkill -TERM chromium  2>/dev/null

sleep 2

# KILL (forçado)
for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -KILL firefox   2>/dev/null
    sudo -u "$u" pkill -KILL chrome    2>/dev/null
    sudo -u "$u" pkill -KILL chromium  2>/dev/null
done

pkill -KILL firefox   2>/dev/null
pkill -KILL chrome    2>/dev/null
pkill -KILL chromium  2>/dev/null

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

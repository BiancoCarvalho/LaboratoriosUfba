#!/bin/bash
# =====================================================================
#  lab-unblock.sh  v6.0.0
#
#  Remove bloqueio:
#   1) remove apenas os policies.json (NÃO os diretórios)
#   2) limpa iptables
#   3) para o watchdog
# =====================================================================

set +e

LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Remove só os arquivos de policy (NÃO os diretórios)
# ---------------------------------------------------------------------
rm -f /var/snap/firefox/common/policies/policies.json    2>/dev/null
rm -f /etc/firefox/policies/policies.json                2>/dev/null
rm -f /usr/lib/firefox/distribution/policies.json        2>/dev/null

rm -f /etc/opt/chrome/policies/managed/policies.json     2>/dev/null
rm -f /etc/opt/chromium/policies/managed/policies.json   2>/dev/null
rm -f /etc/chromium/policies/managed/policies.json       2>/dev/null

# ---------------------------------------------------------------------
# 2) Limpa iptables
# ---------------------------------------------------------------------
iptables -F OUTPUT 2>/dev/null
iptables -P OUTPUT ACCEPT 2>/dev/null

if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1
elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4
fi

# ---------------------------------------------------------------------
# 3) Para o watchdog
# ---------------------------------------------------------------------
if systemctl list-unit-files | grep -q '^lab-watchdog.timer'; then
    systemctl disable --now lab-watchdog.timer >/dev/null 2>&1
fi

# ---------------------------------------------------------------------
# 4) Mata navegadores para forçar releitura
# ---------------------------------------------------------------------
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -TERM -x firefox   2>/dev/null
    sudo -u "$u" pkill -TERM -x chrome    2>/dev/null
    sudo -u "$u" pkill -TERM -x chromium  2>/dev/null
done
pkill -TERM -x firefox   2>/dev/null
pkill -TERM -x chrome    2>/dev/null
pkill -TERM -x chromium  2>/dev/null

sleep 2

for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -KILL -x firefox   2>/dev/null
    sudo -u "$u" pkill -KILL -x chrome    2>/dev/null
    sudo -u "$u" pkill -KILL -x chromium  2>/dev/null
done
pkill -KILL -x firefox   2>/dev/null
pkill -KILL -x chrome    2>/dev/null
pkill -KILL -x chromium  2>/dev/null

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

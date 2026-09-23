#!/bin/bash
# =====================================================================
#  lab-block-status.sh  v1.0.0
#
#  Retorna o estado real do bloqueio:
#    BLOCKED_OK          — policies + iptables ativos
#    BLOCKED_TAMPERED    — iptables ok, mas policy sumiu
#    UNBLOCKED           — nada ativo
# =====================================================================

FIREFOX_POLICY_OK=0
CHROME_POLICY_OK=0
IPTABLES_OK=0

[ -f /var/snap/firefox/common/policies/policies.json ] && FIREFOX_POLICY_OK=1
[ -f /etc/firefox/policies/policies.json ]             && FIREFOX_POLICY_OK=1
[ -f /etc/opt/chrome/policies/managed/policies.json ]  && CHROME_POLICY_OK=1
[ -f /etc/opt/chromium/policies/managed/policies.json ] && CHROME_POLICY_OK=1

# Verifica se há regra DROP no OUTPUT
if iptables -L OUTPUT -n 2>/dev/null | grep -q 'DROP'; then
    IPTABLES_OK=1
fi

if [ "$FIREFOX_POLICY_OK" = "1" ] && [ "$IPTABLES_OK" = "1" ]; then
    echo "BLOCKED_OK"
elif [ "$IPTABLES_OK" = "1" ]; then
    echo "BLOCKED_TAMPERED"
elif [ "$FIREFOX_POLICY_OK" = "1" ]; then
    echo "BLOCKED_PARTIAL"
else
    echo "UNBLOCKED"
fi
exit 0

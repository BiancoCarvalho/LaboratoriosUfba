#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v6.2.0
#
#  Remove TODAS as políticas aplicadas pelo lab-block.sh:
#    - Políticas de Firefox / Chrome / Chromium
#    - Bloqueio de armazenamento USB
#    - ⭐ Bloqueio de terminal
#
#  Localização: /usr/local/sbin/lab-unblock.sh
# =====================================================================

set +e

LOG="/var/log/lab.log"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK: $*" >> "$LOG"
}

log "iniciado"

# =========================================================
# 1) Remove políticas de BROWSER
# =========================================================
REMOVER=(
    "/var/snap/firefox/common/policies/policies.json"
    "/etc/firefox/policies/policies.json"
    "/usr/lib/firefox/distribution/policies.json"
    "/etc/opt/chrome/policies/managed/policies.json"
    "/etc/opt/chromium/policies/managed/policies.json"
    "/etc/chromium/policies/managed/policies.json"
)

for f in "${REMOVER[@]}"; do
    if [ -f "$f" ]; then
        rm -f "$f"
        log "removido: $f"
    fi
done

# Remove pastas vazias
for d in \
    "/var/snap/firefox/common/policies" \
    "/etc/firefox/policies" \
    "/etc/opt/chrome/policies/managed" \
    "/etc/opt/chromium/policies/managed" \
    "/etc/chromium/policies/managed"
do
    if [ -d "$d" ] && [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
        rmdir "$d" 2>/dev/null
    fi
done

# =========================================================
# 2) Restaura ARMAZENAMENTO USB
# =========================================================
USB_CONF="/etc/modprobe.d/lab-usb.conf"

if [ -f "$USB_CONF" ]; then
    rm -f "$USB_CONF"
    log "removido: $USB_CONF"
fi

if ! lsmod | grep -q '^usb_storage'; then
    modprobe usb-storage 2>/dev/null && log "usb-storage recarregado"
fi

log "USB liberado"

# =========================================================
# 3) Desbloqueia TERMINAL (novo)
# =========================================================
if [ -x /usr/local/sbin/lab-unblock-terminal.sh ]; then
    log "desbloqueando terminal"
    /usr/local/sbin/lab-unblock-terminal.sh >> "$LOG" 2>&1 || \
        log "AVISO: falha ao desbloquear terminal"
    echo "✅ Terminal restaurado"
else
    log "AVISO: lab-unblock-terminal.sh não encontrado"
    echo "⚠️  Terminal NÃO restaurado (script ausente)"
fi

# =========================================================
# 4) Encerra NAVEGADORES
# =========================================================
BROWSERS=(
    firefox firefox-esr
    chrome google-chrome
    chromium chromium-browser
    falkon epiphany midori qutebrowser surf
)

for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null || true
done

sleep 2

for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null || true
done

log "concluído"
echo ""
echo "✅ Desbloqueio concluído"
exit 0

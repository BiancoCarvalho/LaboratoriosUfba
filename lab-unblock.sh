#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v6.1.0
#
#  Remove TODAS as políticas aplicadas pelo lab-block.sh:
#    - Políticas de Firefox / Chrome / Chromium
#    - Bloqueio de armazenamento USB
#
#  CORREÇÕES v6.1.0:
#    - NÃO roda update-initramfs (lento demais — timeout SSH)
#    - Remove arquivo modprobe.d (suficiente)
#    - Kill de browsers com fallback
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

# ⭐ NÃO roda update-initramfs (muito lento)
# O módulo já foi descarregado pelo lab-block.sh; recarregar agora:
if ! lsmod | grep -q '^usb_storage'; then
    modprobe usb-storage 2>/dev/null && log "usb-storage recarregado"
fi

log "USB liberado (initramfs NÃO atualizado — evita timeout)"

# =========================================================
# 3) Encerra NAVEGADORES
# =========================================================
BROWSERS=(
    firefox firefox-esr
    chrome google-chrome
    chromium chromium-browser
    falkon epiphany midori qutebrowser surf
)

# TERM educado
for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null || true
done

sleep 2

# KILL garantido
for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null || true
done

log "concluído"
exit 0

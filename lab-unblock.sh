#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v6.0.0
#
#  Remove TODAS as políticas aplicadas pelo lab-block.sh:
#    - Políticas de Firefox / Chrome / Chromium
#    - Bloqueio de armazenamento USB (pendrive, HD externo, cartão SD)
#  E encerra os browsers para que as mudanças surtam efeito.
#
#  Uso:
#    sudo /usr/local/sbin/lab-unblock.sh
# =====================================================================

set +e

LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

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
        echo "[$(date '+%F %T')] removido: $f" >> "$LOG"
    fi
done

# Remove pastas vazias (só se não tiverem mais nada)
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
# 2) Restaura ARMAZENAMENTO USB (pendrive / HD externo / cartão SD)
# =========================================================
USB_CONF="/etc/modprobe.d/lab-usb.conf"

if [ -f "$USB_CONF" ]; then
    rm -f "$USB_CONF"
    echo "[$(date '+%F %T')] removido: $USB_CONF" >> "$LOG"
fi

# Tenta recarregar o módulo agora, se ainda não estiver carregado
if ! lsmod | grep -q '^usb_storage'; then
    modprobe usb-storage 2>/dev/null \
        && echo "[$(date '+%F %T')] usb-storage recarregado" >> "$LOG" \
        || echo "[$(date '+%F %T')] AVISO: falha ao recarregar usb-storage" >> "$LOG"
fi

# Regenera a initramfs sem a regra de bloqueio
if command -v update-initramfs &>/dev/null; then
    update-initramfs -u >/dev/null 2>&1 \
        && echo "[$(date '+%F %T')] initramfs atualizado (usb liberado)" >> "$LOG" \
        || echo "[$(date '+%F %T')] AVISO: falha ao atualizar initramfs" >> "$LOG"
fi

# =========================================================
# 3) Encerra NAVEGADORES (mesma lista do lab-block.sh v10)
# =========================================================
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

BROWSERS=(
    firefox
    firefox-esr
    chrome
    google-chrome
    chromium
    chromium-browser
    falkon
    epiphany
    midori
    qutebrowser
    surf
)

# TERM primeiro (educado)
for u in $USUARIOS_HUMANOS; do
    for b in "${BROWSERS[@]}"; do
        sudo -u "$u" pkill -TERM -x "$b" 2>/dev/null
    done
done

for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null
done

sleep 2

# KILL depois (garantia)
for u in $USUARIOS_HUMANOS; do
    for b in "${BROWSERS[@]}"; do
        sudo -u "$u" pkill -KILL -x "$b" 2>/dev/null
    done
done

for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null
done

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

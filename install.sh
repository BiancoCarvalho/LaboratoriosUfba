#!/bin/bash
# =====================================================================
# /root/labstartup.sh
# Roda no boot, baixa o lab-startup.sh e executa.
# =====================================================================

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
LOG="/var/log/labstartup.log"

echo "[$(date '+%F %T')] === INÍCIO ===" >> "$LOG"

# Espera a rede estar pronta (systemd já garante, mas por segurança)
for i in $(seq 1 30); do
    if ping -c 1 -W 2 raw.githubusercontent.com &>/dev/null; then
        break
    fi
    echo "[$(date '+%F %T')] aguardando rede... ($i/30)" >> "$LOG"
    sleep 2
done

# Baixa o lab-startup.sh
if ! wget -q "$REPO/lab-startup.sh" -O /tmp/startup.sh; then
    echo "[$(date '+%F %T')] ❌ Falha ao baixar lab-startup.sh" >> "$LOG"
    exit 1
fi

if [ ! -s /tmp/startup.sh ]; then
    echo "[$(date '+%F %T')] ❌ lab-startup.sh vazio" >> "$LOG"
    exit 1
fi

chmod +x /tmp/startup.sh

# Roda
echo "[$(date '+%F %T')] Executando lab-startup.sh..." >> "$LOG"
/tmp/startup.sh >> "$LOG" 2>&1

RET=$?
echo "[$(date '+%F %T')] === FIM (exit $RET) ===" >> "$LOG"
exit $RET

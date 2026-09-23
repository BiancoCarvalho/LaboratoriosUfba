#!/bin/bash
# =====================================================================
#  lab-watchdog.sh  v1.0.0
#
#  Roda a cada 15s. Se o bloqueio sumiu, reaplica.
# =====================================================================

LOG="/var/log/lab.log"
STATE_FILE="/run/lab-block.args"

# Se não há reserva ativa (arquivo ausente), não faz nada
[ ! -f "$STATE_FILE" ] && exit 0

ARGS="$(cat "$STATE_FILE")"
STATUS="$(/usr/local/sbin/lab-block-status.sh)"

case "$STATUS" in
    BLOCKED_OK)
        # tudo certo
        ;;
    BLOCKED_TAMPERED|BLOCKED_PARTIAL|UNBLOCKED)
        echo "[$(date '+%F %T')] watchdog: status=$STATUS — reaplicando" >> "$LOG"
        /usr/local/sbin/lab-block.sh "$ARGS"
        ;;
esac

exit 0

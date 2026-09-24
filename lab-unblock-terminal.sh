#!/bin/bash
# =====================================================================
#  lab-unblock-terminal.sh
#  v1.0.0
#
#  Restaura o terminal para o usuário 'aluno'.
#
#  Localização: /usr/local/sbin/lab-unblock-terminal.sh
# =====================================================================

set -u

LOG="/var/log/lab.log"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK-TERMINAL: $*" >> "$LOG"
}

log "iniciado"

# =========================================================
# 1. Restaura permissões dos terminais
# =========================================================
TERMINAIS=(
    gnome-terminal xterm konsole tilix alacritty kitty
    xfce4-terminal mate-terminal terminator guake yakuake
    sakura rxvt urxvt
)

RESTAURADOS=0
for term in "${TERMINAIS[@]}"; do
    BIN="/usr/bin/$term"
    if [ -f "$BIN" ]; then
        chown root:root "$BIN" 2>/dev/null || true
        chmod 755 "$BIN" 2>/dev/null || true
        RESTAURADOS=$((RESTAURADOS + 1))
        log "restaurado: $BIN"
    fi
done

# =========================================================
# 2. Remove bloqueio de atalhos
# =========================================================
rm -f /etc/dconf/db/local.d/00-lab-block-terminal
rm -f /etc/dconf/db/local.d/locks/00-lab-block-terminal
command -v dconf &>/dev/null && dconf update 2>/dev/null || true
log "atalhos restaurados"

# =========================================================
# 3. Remove bloqueio de TTY
# =========================================================
rm -f /etc/systemd/logind.conf.d/lab-block-tty.conf
systemctl restart systemd-logind 2>/dev/null || true
log "TTY restaurado"

# =========================================================
# 4. Restaura menu
# =========================================================
for desktop in /usr/share/applications/*.desktop; do
    if [ -f "$desktop.bak" ]; then
        mv "$desktop.bak" "$desktop"
        log "menu restaurado: $desktop"
    else
        sed -i '/^NoDisplay=true$/d' "$desktop" 2>/dev/null || true
    fi
done
log "menus restaurados"

log "concluído — $RESTAURADOS terminais restaurados"
echo "✅ Terminal restaurado ($RESTAURADOS binários)"
exit 0

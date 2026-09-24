#!/bin/bash
# =====================================================================
#  lab-block-terminal.sh
#  v1.0.0
#
#  Bloqueia o terminal para o usuário 'aluno' (não afeta 'nati').
#
#  Localização: /usr/local/sbin/lab-block-terminal.sh
# =====================================================================

set -u

LOG="/var/log/lab.log"
GRUPO="terminal-users"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) BLOCK-TERMINAL: $*" >> "$LOG"
}

log "iniciado"

# =========================================================
# 1. Cria grupo (se não existir)
# =========================================================
if ! getent group "$GRUPO" >/dev/null 2>&1; then
    groupadd "$GRUPO"
    log "grupo $GRUPO criado"
fi

# Adiciona 'nati' e 'root' ao grupo
for u in nati root; do
    if id "$u" &>/dev/null; then
        usermod -aG "$GRUPO" "$u" 2>/dev/null || true
    fi
done
log "nati e root no grupo $GRUPO"

# =========================================================
# 2. Bloqueia binários dos terminais
# =========================================================
TERMINAIS=(
    gnome-terminal xterm konsole tilix alacritty kitty
    xfce4-terminal mate-terminal terminator guake yakuake
    sakura rxvt urxvt
)

BLOQUEADOS=0
for term in "${TERMINAIS[@]}"; do
    BIN="/usr/bin/$term"
    if [ -f "$BIN" ]; then
        chown "root:$GRUPO" "$BIN" 2>/dev/null || true
        chmod 750 "$BIN" 2>/dev/null || true
        BLOQUEADOS=$((BLOQUEADOS + 1))
        log "bloqueado: $BIN"
    fi
done

# =========================================================
# 3. Remove atalhos do GNOME
# =========================================================
mkdir -p /etc/dconf/db/local.d /etc/dconf/db/local.d/locks

cat > /etc/dconf/db/local.d/00-lab-block-terminal <<'DCONF'
[org/gnome/settings-daemon/plugins/media-keys]
terminal = ''

[org/gnome/shell/keybindings]
toggle-application-view = ['']
DCONF

cat > /etc/dconf/db/local.d/locks/00-lab-block-terminal <<'DCONF'
/org/gnome/settings-daemon/plugins/media-keys/terminal
/org/gnome/shell/keybindings/toggle-application-view
DCONF

command -v dconf &>/dev/null && dconf update 2>/dev/null || true
log "atalhos bloqueados"

# =========================================================
# 4. Bloqueia troca de TTY
# =========================================================
mkdir -p /etc/systemd/logind.conf.d

cat > /etc/systemd/logind.conf.d/lab-block-tty.conf <<'TTY'
[Login]
NAutoVTs=0
ReserveVT=0
TTY

systemctl restart systemd-logind 2>/dev/null || true
log "TTY bloqueado"

# =========================================================
# 5. Esconde do menu
# =========================================================
for desktop in \
    /usr/share/applications/org.gnome.Terminal.desktop \
    /usr/share/applications/gnome-terminal.desktop \
    /usr/share/applications/xterm.desktop \
    /usr/share/applications/konsole.desktop \
    /usr/share/applications/tilix.desktop \
    /usr/share/applications/alacritty.desktop \
    /usr/share/applications/kitty.desktop
do
    if [ -f "$desktop" ]; then
        [ ! -f "$desktop.bak" ] && cp "$desktop" "$desktop.bak"
        grep -q "^NoDisplay=true" "$desktop" || echo "NoDisplay=true" >> "$desktop"
    fi
done
log "menus atualizados"

log "concluído — $BLOQUEADOS terminais bloqueados"
echo "✅ Terminal bloqueado ($BLOQUEADOS binários)"
exit 0

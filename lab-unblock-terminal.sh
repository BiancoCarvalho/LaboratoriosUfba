#!/bin/bash
# =====================================================================
#  lab-unblock-terminal.sh
#  v1.2.0
#
#  Restaura o terminal para o usuário 'aluno'.
#
#  CORREÇÕES v1.2.0:
#    - NÃO mata o gnome-shell do aluno (causava tela preta)
#    - NÃO reinicia systemd-logind (derrubava sessão gráfica)
#    - NÃO remove /etc/systemd/logind.conf.d (pasta padrão)
#    - Restaura APENAS os .desktop de terminais
#    - Não mexe em sessões ativas
#
#  Localização: /usr/local/sbin/lab-unblock-terminal.sh
# =====================================================================

set -u

LOG="/var/log/lab.log"
GRUPO="terminal-users"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK-TERMINAL: $*" >> "$LOG"
}

log "iniciado"

# =========================================================
# 1. Restaura permissões dos binários de terminal
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
# 2. Remove arquivos de atalhos do GNOME
# =========================================================
rm -f /etc/dconf/db/local.d/00-lab-block-terminal
rm -f /etc/dconf/db/local.d/locks/00-lab-block-terminal

command -v dconf &>/dev/null && dconf update 2>/dev/null || true
log "atalhos restaurados"

# =========================================================
# 3. Remove bloqueio de TTY (SEM reiniciar logind)
# =========================================================
# ⭐ NÃO reinicia systemd-logind (derrubava a sessão gráfica)
# ⭐ NÃO remove /etc/systemd/logind.conf.d (pasta padrão do systemd)
rm -f /etc/systemd/logind.conf.d/lab-block-tty.conf
log "TTY restaurado (aplicará no próximo boot)"

# =========================================================
# 4. Restaura APENAS .desktop de terminais
# =========================================================
# ⭐ NÃO mexe em TODOS os .desktop (isso quebrava o GNOME)
for desktop in \
    /usr/share/applications/org.gnome.Terminal.desktop \
    /usr/share/applications/gnome-terminal.desktop \
    /usr/share/applications/xterm.desktop \
    /usr/share/applications/konsole.desktop \
    /usr/share/applications/tilix.desktop \
    /usr/share/applications/alacritty.desktop \
    /usr/share/applications/kitty.desktop
do
    if [ -f "$desktop.bak" ]; then
        mv "$desktop.bak" "$desktop" 2>/dev/null || true
        log "menu restaurado: $desktop"
    fi
    # Só remove NoDisplay do terminal
    [ -f "$desktop" ] && sed -i '/^NoDisplay=true$/d' "$desktop" 2>/dev/null || true
done
log "menus de terminal restaurados"

# =========================================================
# 5. Remove 'nati' e 'root' do grupo terminal-users
# =========================================================
for u in nati root; do
    if id "$u" &>/dev/null; then
        gpasswd -d "$u" "$GRUPO" 2>/dev/null || true
    fi
done
log "nati e root removidos do grupo $GRUPO"

# =========================================================
# 6. Remove o grupo terminal-users (se vazio)
# =========================================================
if getent group "$GRUPO" >/dev/null 2>&1; then
    MEMBROS=$(getent group "$GRUPO" | cut -d: -f4)
    if [ -z "$MEMBROS" ]; then
        groupdel "$GRUPO" 2>/dev/null || true
        log "grupo $GRUPO removido"
    fi
fi

# =========================================================
# 7. ⭐ NÃO mata gnome-shell do aluno
# =========================================================
# O GNOME Shell recarrega os atalhos sozinho no próximo login.
# Matar o gnome-shell derrubava a sessão gráfica.
#
# if pgrep -u aluno gnome-shell >/dev/null 2>&1; then
#     pkill -TERM -u aluno -x gnome-shell 2>/dev/null || true
# fi

log "concluído — $RESTAURADOS terminais restaurados"
echo "✅ Terminal restaurado ($RESTAURADOS binários)"
echo "   - Permissões: OK"
echo "   - Atalhos: OK (aplicam no próximo login)"
echo "   - TTY: OK (aplica no próximo boot)"
echo "   - Menu: OK"
exit 0

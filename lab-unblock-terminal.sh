#!/bin/bash
# =====================================================================
#  lab-unblock-terminal.sh
#  v1.1.0
#
#  Restaura o terminal para o usuário 'aluno'.
#
#  O que faz:
#    1. Restaura permissões dos binários dos terminais
#    2. Remove arquivos de atalhos do GNOME
#    3. Remove bloqueio de TTY
#    4. Restaura .desktop (do backup)
#    5. Remove 'nati' e 'root' do grupo terminal-users
#    6. Remove o grupo terminal-users (se vazio)
#    7. Força gnome-shell a recarregar os atalhos
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
# 1. Restaura permissões dos binários
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
        # Restaura dono e permissão original
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
# 3. Remove bloqueio de TTY
# =========================================================
rm -f /etc/systemd/logind.conf.d/lab-block-tty.conf

# Remove a pasta se ficou vazia
if [ -d /etc/systemd/logind.conf.d ]; then
    rmdir /etc/systemd/logind.conf.d 2>/dev/null || true
fi

systemctl restart systemd-logind 2>/dev/null || true
log "TTY restaurado"

# =========================================================
# 4. Restaura .desktop (do backup)
# =========================================================
for desktop in /usr/share/applications/*.desktop; do
    if [ -f "$desktop.bak" ]; then
        # Backup existe → restaura
        mv "$desktop.bak" "$desktop" 2>/dev/null || true
        log "menu restaurado: $desktop"
    else
        # Sem backup → só remove a linha NoDisplay que adicionamos
        sed -i '/^NoDisplay=true$/d' "$desktop" 2>/dev/null || true
    fi
done
log "menus restaurados"

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
    # Verifica se o grupo está vazio (sem usuários)
    MEMBROS=$(getent group "$GRUPO" | cut -d: -f4)
    if [ -z "$MEMBROS" ]; then
        groupdel "$GRUPO" 2>/dev/null || true
        log "grupo $GRUPO removido"
    else
        log "grupo $GRUPO ainda tem membros: $MEMBROS"
    fi
fi

# =========================================================
# 7. Recarrega gnome-shell (se o aluno estiver logado)
# =========================================================
# Isso faz o GNOME Shell reler as configurações
# (atalhos voltam ao normal sem precisar relogar)
if pgrep -u aluno gnome-shell >/dev/null 2>&1; then
    # Pede ao gnome-shell para recarregar (SIGTERM → ele se recupera)
    pkill -TERM -u aluno -x gnome-shell 2>/dev/null || true
    log "gnome-shell do aluno recarregado"
fi

# =========================================================
# Finalização
# =========================================================
log "concluído — $RESTAURADOS terminais restaurados"
echo "✅ Terminal restaurado ($RESTAURADOS binários)"
echo "   - Permissões: OK"
echo "   - Atalhos: OK"
echo "   - TTY: OK"
echo "   - Menu: OK"
echo "   - Grupo: removido (se vazio)"
exit 0

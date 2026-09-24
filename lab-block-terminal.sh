#!/bin/bash
# =====================================================================
#  lab-block-terminal.sh
#  v1.3.0
#
#  Bloqueia o terminal para o usuário 'aluno' (não afeta 'nati').
#
#  O que faz:
#    1. Cria grupo 'terminal-users' (nati + root)
#    2. Bloqueia binários dos terminais (chmod 750)
#    3. Remove atalhos do GNOME
#    4. Bloqueia troca de TTY (sem reiniciar logind)
#    5. Esconde terminais do menu
#    6. Mata terminais e processos do aluno (PRESERVANDO SSH)
#
#  CORREÇÕES v1.3.0:
#    - ⭐ NÃO mata processos SSH se estiver rodando via SSH
#      (evita derrubar a conexão do C#)
#    - ⭐ Corrige o `case` para pegar sshd-session, sshd-auth, etc.
#    - ⭐ Usa `ps -o args=` além de `ps -o comm=` para maior precisão
#    - Preserva mais processos essenciais
# =====================================================================

set -u

LOG="/var/log/lab.log"
GRUPO="terminal-users"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) BLOCK-TERMINAL: $*" >> "$LOG"
}

log "iniciado"

# =========================================================
# 1. Cria grupo
# =========================================================
if ! getent group "$GRUPO" >/dev/null 2>&1; then
    groupadd "$GRUPO"
    log "grupo $GRUPO criado"
fi

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
# 4. Bloqueia troca de TTY (SEM reiniciar logind)
# =========================================================
mkdir -p /etc/systemd/logind.conf.d

cat > /etc/systemd/logind.conf.d/lab-block-tty.conf <<'TTY'
[Login]
NAutoVTs=0
ReserveVT=0
TTY

# ⭐ NÃO reinicia systemd-logind (evita derrubar SSH)
# A configuração só afeta novos logins. Reboot aplica.
log "TTY bloqueado (aplicará no próximo login)"

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

# =========================================================
# 6. Mata terminais e processos do aluno (PRESERVANDO SSH)
#    ⭐ CORREÇÃO v1.3.0
# =========================================================
log "matando processos do aluno"

MORTOS=0
PRESERVADOS=0

# ⭐ Se estiver rodando via SSH, NÃO mata processos
#    (evita derrubar a conexão do C#)
if [ -n "${SSH_CONNECTION:-}" ]; then
    log "rodando via SSH — pulando kill de processos (segurança)"
    PRESERVADOS=$(pgrep -u aluno 2>/dev/null | wc -l)
else
    for pid in $(pgrep -u aluno 2>/dev/null); do
        proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
        proc_args=$(ps -p "$pid" -o args= 2>/dev/null)

        # ⭐ Preserva SSH (por nome OU por argumentos)
        if [[ "$proc_name" == sshd* ]] || [[ "$proc_args" == *sshd* ]]; then
            PRESERVADOS=$((PRESERVADOS + 1))
            continue
        fi

        # Preserva sessão gráfica
        case "$proc_name" in
            gnome-shell|gnome-session-binary|gnome-session|Xorg|Xwayland|dbus-daemon|dbus-launch|gdm-session-worker)
                PRESERVADOS=$((PRESERVADOS + 1))
                continue
                ;;
        esac

        # Preserva Firefox
        case "$proc_name" in
            firefox|firefox-esr|firefox-bin)
                PRESERVADOS=$((PRESERVADOS + 1))
                continue
                ;;
        esac

        # Preserva processos do sistema
        case "$proc_name" in
            systemd|systemd-user|systemd-logind|login|sudo)
                PRESERVADOS=$((PRESERVADOS + 1))
                continue
                ;;
        esac

        # Mata o resto (terminais, editores, etc)
        kill -KILL "$pid" 2>/dev/null || true
        MORTOS=$((MORTOS + 1))
    done
fi

log "$MORTOS processos do aluno mortos ($PRESERVADOS preservados)"

# =========================================================
# Finalização
# =========================================================
log "concluído — $BLOQUEADOS terminais bloqueados, $MORTOS processos mortos, $PRESERVADOS preservados"
echo "✅ Terminal bloqueado"
echo "   - $BLOQUEADOS binários bloqueados"
echo "   - $MORTOS processos do aluno encerrados"
echo "   - $PRESERVADOS processos preservados (SSH, GNOME, Firefox)"
exit 0

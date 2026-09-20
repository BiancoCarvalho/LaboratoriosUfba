#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v8.0.0
#
#  Roda a cada boot (via labstartup.service).
#  Baixa os scripts do repo e atualiza o PostLogin/Default.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
DIR="/usr/local/sbin"

SCRIPTS="
lab-profile-config.sh
lab-aluno-config.sh
lab-aluno-ssh-config.sh
lab-programs.sh
lab-eula-programs.sh
lab-program-config.sh
lab-inventory.sh
lab-admin-profile-config.sh
lab-labadmin-config.sh
lab-prova-install.sh
lab-block.sh
lab-unblock.sh
lab-postlogin-default.sh
labadmin.pub
labsecurity-agent.sh
"

echo "==> Baixando scripts do repositório..."

for f in $SCRIPTS; do
    wget -q -O "/tmp/$f" "$REPO/$f" 2>/dev/null || true
done

DONE="true"
[ ! -f "$DIR/done.txt" ] && echo "false" > "$DIR/done.txt"

for f in $SCRIPTS; do
    if [ -f "/tmp/$f" ] && [ -s "/tmp/$f" ]; then
        if [ ! -f "$DIR/$f" ] || ! cmp -s "$DIR/$f" "/tmp/$f"; then
            echo "false" > "$DIR/done.txt"
            break
        fi
    fi
done

DONE=$(cat "$DIR/done.txt")

if [ "$DONE" = "false" ]; then
    echo "==> Atualizando scripts..."

    for f in $SCRIPTS; do
        if [ -f "/tmp/$f" ] && [ -s "/tmp/$f" ]; then
            cp "/tmp/$f" "$DIR/" 2>/dev/null || true
        fi
    done

    chmod 755 "$DIR"/lab-*.sh 2>/dev/null || true
    chmod 644 "$DIR/labadmin.pub" 2>/dev/null || true

    # ================================================================
    # Copia o lab-postlogin-default.sh para /etc/gdm3/PostLogin/Default
    # ================================================================
    if [ -f "$DIR/lab-postlogin-default.sh" ]; then
        mkdir -p /etc/gdm3/PostLogin
        cp "$DIR/lab-postlogin-default.sh" /etc/gdm3/PostLogin/Default
        chmod a+x /etc/gdm3/PostLogin/Default
        echo "==> /etc/gdm3/PostLogin/Default atualizado"
    fi

    # ================================================================
    # Executa os scripts
    # ================================================================
    [ -f "$DIR/lab-profile-config.sh" ]       && "$DIR/lab-profile-config.sh"       || true
    [ -f "$DIR/lab-aluno-config.sh" ]         && "$DIR/lab-aluno-config.sh"         || true
    [ -f "$DIR/lab-aluno-ssh-config.sh" ]     && "$DIR/lab-aluno-ssh-config.sh"     || true
    [ -f "$DIR/lab-programs.sh" ]             && "$DIR/lab-programs.sh"             || true
    [ -f "$DIR/lab-eula-programs.sh" ]        && "$DIR/lab-eula-programs.sh"        || true
    [ -f "$DIR/lab-program-config.sh" ]       && "$DIR/lab-program-config.sh"       || true
    [ -f "$DIR/lab-inventory.sh" ]            && "$DIR/lab-inventory.sh"            || true
    [ -f "$DIR/lab-admin-profile-config.sh" ] && "$DIR/lab-admin-profile-config.sh" || true
    [ -f "$DIR/lab-labadmin-config.sh" ]      && "$DIR/lab-labadmin-config.sh"      || true

    echo "true" > "$DIR/done.txt"
    echo "==> Scripts atualizados."
else
    echo "==> Sem atualizações."
fi

exit 0

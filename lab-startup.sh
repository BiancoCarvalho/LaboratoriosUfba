#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v5.0.0
#
#  Roda a cada boot. Baixa os scripts do repositório e executa os de
#  configuração de usuário.
#
#  NÃO chama lab-block.sh nem lab-prova-install.sh!
#  O modo prova só é ativado quando o servidor C# manda via SSH.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
DIR="/usr/local/sbin"

# Lista de todos os scripts
SCRIPTS="
lab-profile-config.sh
lab-aluno-config.sh
lab-programs.sh
lab-eula-programs.sh
lab-program-config.sh
lab-inventory.sh
lab-admin-profile-config.sh
lab-labadmin-config.sh
lab-prova-profile-config.sh
lab-prova-config.sh
lab-prova-install.sh
lab-block.sh
lab-unblock.sh
labadmin.pub
labsecurity-agent.sh
"

echo "==> Baixando scripts do repositório..."

for f in $SCRIPTS; do
    wget -q -O "/tmp/$f" "$REPO/$f" 2>/dev/null || true
done

# Verifica se houve mudança
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

    # Executa os scripts de configuração de usuário
    # ATENÇÃO: NÃO chamar lab-block.sh nem lab-prova-install.sh aqui!
    [ -f "$DIR/lab-profile-config.sh" ]       && "$DIR/lab-profile-config.sh"       || true
    [ -f "$DIR/lab-aluno-config.sh" ]         && "$DIR/lab-aluno-config.sh"         || true
    [ -f "$DIR/lab-admin-profile-config.sh" ] && "$DIR/lab-admin-profile-config.sh" || true
    [ -f "$DIR/lab-labadmin-config.sh" ]      && "$DIR/lab-labadmin-config.sh"      || true

    echo "true" > "$DIR/done.txt"
    echo "==> Scripts atualizados."
else
    echo "==> Sem atualizações."
fi

exit 0

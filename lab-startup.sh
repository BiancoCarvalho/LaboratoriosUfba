#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  Baixa e executa os scripts do repositório
#  NÃO chama lab-block.sh nem lab-prova-config.sh!
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
DIR="/usr/local/sbin"

echo "==> Baixando scripts do repositório..."

# Lista de scripts (todos os do repo)
for f in \
    lab-profile-config.sh \
    lab-aluno-config.sh \
    lab-programs.sh \
    lab-eula-programs.sh \
    lab-program-config.sh \
    lab-inventory.sh \
    lab-admin-profile-config.sh \
    lab-labadmin-config.sh \
    lab-prova-profile-config.sh \
    lab-prova-config.sh \
    lab-prova-install.sh \
    lab-block.sh \
    lab-unblock.sh \
    labadmin.pub \
    labsecurity-agent.sh
do
    wget -q -O "/tmp/$f" "$REPO/$f" || true
done

# Verifica se houve mudança
DONE="true"
[ ! -f "$DIR/done.txt" ] && echo "false" > "$DIR/done.txt"

for f in \
    lab-profile-config.sh \
    lab-aluno-config.sh \
    lab-programs.sh \
    lab-eula-programs.sh \
    lab-program-config.sh \
    lab-inventory.sh \
    lab-admin-profile-config.sh \
    lab-labadmin-config.sh \
    lab-prova-profile-config.sh \
    lab-prova-config.sh \
    lab-prova-install.sh \
    lab-block.sh \
    lab-unblock.sh \
    labadmin.pub \
    labsecurity-agent.sh
do
    if [ ! -f "$DIR/$f" ] || ! cmp -s "$DIR/$f" "/tmp/$f"; then
        echo "false" > "$DIR/done.txt"
        break
    fi
done

DONE=$(cat "$DIR/done.txt")

if [ "$DONE" = "false" ]; then
    echo "==> Atualizando scripts..."

    for f in \
        lab-profile-config.sh \
        lab-aluno-config.sh \
        lab-programs.sh \
        lab-eula-programs.sh \
        lab-program-config.sh \
        lab-inventory.sh \
        lab-admin-profile-config.sh \
        lab-labadmin-config.sh \
        lab-prova-profile-config.sh \
        lab-prova-config.sh \
        lab-prova-install.sh \
        lab-block.sh \
        lab-unblock.sh \
        labadmin.pub \
        labsecurity-agent.sh
    do
        cp "/tmp/$f" "$DIR/" 2>/dev/null || true
    done

    chmod 755 "$DIR"/lab-*.sh 2>/dev/null || true
    chmod 644 "$DIR/labadmin.pub" 2>/dev/null || true

    # -----------------------------------------------------------------
    # RODA OS SCRIPTS DE CONFIGURAÇÃO
    # IMPORTANTE: NÃO chamar lab-block.sh nem lab-prova-config.sh aqui!
    # -----------------------------------------------------------------
    /usr/local/sbin/lab-profile-config.sh          || true
    /usr/local/sbin/lab-aluno-config.sh            || true
    /usr/local/sbin/lab-admin-profile-config.sh    || true
    /usr/local/sbin/lab-labadmin-config.sh         || true

    # O lab-prova-config.sh NÃO é chamado no boot.
    # O lab-prova-install.sh NÃO é chamado no boot.
    # Só o lab-block.sh (via SSH) chama o lab-prova-config.sh.

    echo "true" > "$DIR/done.txt"
    echo "==> Scripts atualizados."
else
    echo "==> Sem atualizações."
fi

exit 0

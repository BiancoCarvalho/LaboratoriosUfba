#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v11.0.0
#
#  Roda a cada boot (via labstartup.service).
#  Garante que:
#    1) Os scripts são baixados do GitHub
#    2) Se houver mudança, são aplicados
#    3) Os usuários (aluno, labadmin) estão configurados
#
#  ⚠️ NÃO reaplica bloqueio cegamente.
#     O bloqueio é controlado pelo servidor (ReservaMonitorService).
#
#  Roda em modo "fail-safe": nunca para por erro.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
DIR="/usr/local/sbin"
LOG="/var/log/lab.log"

# Nunca para por erro
set +e

echo "" >> "$LOG"
echo "[$(date '+%F %T')] ================================================" >> "$LOG"
echo "[$(date '+%F %T')] LAB-STARTUP INICIADO (v11.0.0)" >> "$LOG"
echo "[$(date '+%F %T')] ================================================" >> "$LOG"

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
lab-block-sites.sh
lab-unblock.sh
lab-postlogin-default.sh
labadmin.pub
labsecurity-agent.sh
"

# =====================================================================
# 1) ESPERA A REDE FICAR PRONTA (timeout de 60s)
# =====================================================================
echo "[$(date '+%F %T')] Aguardando rede..." >> "$LOG"

for i in $(seq 1 30); do
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "[$(date '+%F %T')] Rede OK" >> "$LOG"
        break
    fi
    sleep 2
done

# =====================================================================
# 2) BAIXA OS SCRIPTS (sempre)
# =====================================================================
echo "==> Baixando scripts do repositório..."
echo "[$(date '+%F %T')] Baixando scripts do GitHub..." >> "$LOG"

BAIXADOS=0
FALHAS=0

for f in $SCRIPTS; do
    if wget -q -T 15 -O "/tmp/$f" "$REPO/$f" 2>/dev/null; then
        if [ -s "/tmp/$f" ]; then
            BAIXADOS=$((BAIXADOS+1))
        else
            FALHAS=$((FALHAS+1))
        fi
    else
        FALHAS=$((FALHAS+1))
    fi
done

echo "[$(date '+%F %T')] Baixados: $BAIXADOS | Falhas: $FALHAS" >> "$LOG"

# =====================================================================
# 3) DETECTA MUDANÇAS (cmp)
# =====================================================================
DONE="true"
[ ! -f "$DIR/done.txt" ] && echo "false" > "$DIR/done.txt"

for f in $SCRIPTS; do
    if [ -f "/tmp/$f" ] && [ -s "/tmp/$f" ]; then
        if [ ! -f "$DIR/$f" ] || ! cmp -s "$DIR/$f" "/tmp/$f"; then
            echo "[$(date '+%F %T')] Mudança detectada: $f" >> "$LOG"
            echo "false" > "$DIR/done.txt"
            break
        fi
    fi
done

DONE=$(cat "$DIR/done.txt")

# =====================================================================
# 4) SE HOUVE MUDANÇA → APLICA TUDO
# =====================================================================
if [ "$DONE" = "false" ]; then
    echo "==> Atualizando scripts..."
    echo "[$(date '+%F %T')] APLICANDO atualizações..." >> "$LOG"

    # 4.1) Copia os scripts novos
    for f in $SCRIPTS; do
        if [ -f "/tmp/$f" ] && [ -s "/tmp/$f" ]; then
            cp "/tmp/$f" "$DIR/" 2>/dev/null || true
        fi
    done

    chmod 755 "$DIR"/lab-*.sh 2>/dev/null || true
    chmod 644 "$DIR/labadmin.pub" 2>/dev/null || true

    echo "[$(date '+%F %T')] Scripts copiados para $DIR" >> "$LOG"

    # 4.2) Copia o PostLogin/Default
    if [ -f "$DIR/lab-postlogin-default.sh" ]; then
        mkdir -p /etc/gdm3/PostLogin
        cp "$DIR/lab-postlogin-default.sh" /etc/gdm3/PostLogin/Default
        chmod a+x /etc/gdm3/PostLogin/Default
        echo "==> /etc/gdm3/PostLogin/Default atualizado"
        echo "[$(date '+%F %T')] PostLogin/Default atualizado" >> "$LOG"
    fi

    # 4.3) Executa os scripts de configuração (um por um)
    echo "[$(date '+%F %T')] Executando scripts de configuração..." >> "$LOG"

    for script in \
        lab-profile-config.sh \
        lab-aluno-config.sh \
        lab-aluno-ssh-config.sh \
        lab-programs.sh \
        lab-eula-programs.sh \
        lab-program-config.sh \
        lab-inventory.sh \
        lab-admin-profile-config.sh \
        lab-labadmin-config.sh \
        lab-prova-install.sh
    do
        if [ -f "$DIR/$script" ]; then
            echo "[$(date '+%F %T')] Executando $script..." >> "$LOG"
            echo "==> Executando $script"
            "$DIR/$script" 2>&1 | tee -a "$LOG" || {
                echo "[$(date '+%F %T')] ERRO ao executar $script (continuando)" >> "$LOG"
            }
        fi
    done

    echo "true" > "$DIR/done.txt"
    echo "==> Scripts atualizados."
    echo "[$(date '+%F %T')] Scripts atualizados com sucesso" >> "$LOG"
else
    echo "==> Sem atualizações."
    echo "[$(date '+%F %T')] Sem atualizações (nada mudou)" >> "$LOG"
fi

# =====================================================================
# 5) NÃO REAPLICA BLOQUEIO AUTOMATICAMENTE
#    O controle é feito pelo servidor via ReservaMonitorService.
#    Se você reiniciar a máquina no meio de uma reserva ativa, o
#    servidor irá reaplicar o bloqueio no próximo ciclo (30s).
# =====================================================================
echo "[$(date '+%F %T')] Bloqueio NÃO reaplicado automaticamente (controlado pelo servidor)" >> "$LOG"

# =====================================================================
# 6) GARANTE QUE O labstartup.service ESTÁ HABILITADO
# =====================================================================
if ! systemctl is-enabled labstartup.service &>/dev/null; then
    echo "[$(date '+%F %T')] labstartup.service não estava habilitado. Habilitando..." >> "$LOG"
    systemctl enable labstartup.service 2>/dev/null || true
fi

# =====================================================================
# 7) FIM
# =====================================================================
echo "[$(date '+%F %T')] ================================================" >> "$LOG"
echo "[$(date '+%F %T')] LAB-STARTUP CONCLUÍDO" >> "$LOG"
echo "[$(date '+%F %T')] ================================================" >> "$LOG"

echo "==> Finalizado. Log em /var/log/lab.log"
exit 0

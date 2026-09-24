#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v10.2.0
#
#  Mudanças em relação à v10.1.0:
#    - ⭐ Adiciona download de lab-ipset-update.sh, .service, .timer
#    - ⭐ Adiciona download de lab-block-status.sh
#    - ⭐ Copia as units do ipset para /etc/systemd/system/
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

# ==============================
# Sincronização de data e hora
# ==============================
echo "Configurando sincronização de data e hora..."

sudo timedatectl set-ntp true
sudo timedatectl set-timezone America/Bahia
sudo timedatectl set-local-rtc 0
sudo systemctl restart systemd-timesyncd

echo "Status da sincronização:"
timedatectl status

echo "✅ Sincronização de tempo configurada."

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"

# ==============================
# 1. Baixa os scripts atualizados do repositorio
# ==============================
echo "========================================="
echo "  Baixando scripts do repositorio..."
echo "========================================="

# --- scripts existentes ---
wget -q --timeout=30 --tries=3 "$REPO/lab-profile-config.sh"         -O /tmp/lab-profile-config.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-aluno-config.sh"           -O /tmp/lab-aluno-config.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-programs.sh"               -O /tmp/lab-programs.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-eula-programs.sh"          -O /tmp/lab-eula-programs.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-program-config.sh"         -O /tmp/lab-program-config.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-inventory.sh"              -O /tmp/lab-inventory.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-admin-profile-config.sh"   -O /tmp/lab-admin-profile-config.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-block.sh"                  -O /tmp/lab-block.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-block-sites.sh"            -O /tmp/lab-block-sites.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-unblock.sh"                -O /tmp/lab-unblock.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-block-terminal.sh"         -O /tmp/lab-block-terminal.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-unblock-terminal.sh"       -O /tmp/lab-unblock-terminal.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-postlogin-default.sh"      -O /tmp/lab-postlogin-default.sh
wget -q --timeout=30 --tries=3 "$REPO/labsecurity-agent.sh"          -O /tmp/labsecurity-agent.sh
wget -q --timeout=30 --tries=3 "$REPO/labadmin.pub"                  -O /tmp/labadmin.pub

# --- NOVOS: scripts do ipset ---
wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.sh"           -O /tmp/lab-ipset-update.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.service"      -O /tmp/lab-ipset-update.service
wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.timer"        -O /tmp/lab-ipset-update.timer

# --- NOVO: status do bloqueio ---
wget -q --timeout=30 --tries=3 "$REPO/lab-block-status.sh"           -O /tmp/lab-block-status.sh

echo "[OK] Download concluido!"
echo ""

# ==============================
# 2. Verifica se ja existe o controle de atualizacao
# ==============================
echo "========================================="
echo "  Verificando atualizacoes..."
echo "========================================="

if ! [ -f /usr/local/sbin/done.txt ]; then
    touch /usr/local/sbin/done.txt
    echo "false" > /usr/local/sbin/done.txt
    chmod 755 /usr/local/sbin/done.txt
else
    # --- scripts em /usr/local/sbin ---
    for arq in \
        lab-profile-config.sh \
        lab-aluno-config.sh \
        lab-programs.sh \
        lab-eula-programs.sh \
        lab-program-config.sh \
        lab-inventory.sh \
        lab-admin-profile-config.sh \
        labsecurity-agent.sh \
        lab-block.sh \
        lab-block-sites.sh \
        lab-unblock.sh \
        lab-postlogin-default.sh \
        lab-block-terminal.sh \
        lab-unblock-terminal.sh \
        lab-ipset-update.sh \
        lab-block-status.sh ; do
        if [ ! -f "/usr/local/sbin/$arq" ] || ! cmp -s "/usr/local/sbin/$arq" "/tmp/$arq"; then
            echo "false" > /usr/local/sbin/done.txt
        fi
    done

    # --- units systemd ---
    for arq in \
        lab-ipset-update.service \
        lab-ipset-update.timer ; do
        if [ ! -f "/etc/systemd/system/$arq" ] || ! cmp -s "/etc/systemd/system/$arq" "/tmp/$arq"; then
            echo "false" > /usr/local/sbin/done.txt
        fi
    done
fi

DONE=$(cat /usr/local/sbin/done.txt)

# ==============================
# 3. Copia e executa scripts se houve atualizacao
# ==============================
if [ "$DONE" = "false" ]; then
    echo "========================================="
    echo "  Atualizando scripts..."
    echo "========================================="

    cp /tmp/lab-profile-config.sh       /usr/local/sbin
    cp /tmp/lab-aluno-config.sh         /usr/local/sbin
    cp /tmp/lab-programs.sh             /usr/local/sbin
    cp /tmp/lab-eula-programs.sh        /usr/local/sbin
    cp /tmp/lab-program-config.sh       /usr/local/sbin
    cp /tmp/lab-inventory.sh            /usr/local/sbin
    cp /tmp/lab-admin-profile-config.sh /usr/local/sbin
    cp /tmp/lab-block.sh                /usr/local/sbin
    cp /tmp/lab-block-sites.sh          /usr/local/sbin
    cp /tmp/lab-unblock.sh              /usr/local/sbin
    cp /tmp/lab-block-terminal.sh       /usr/local/sbin
    cp /tmp/lab-unblock-terminal.sh     /usr/local/sbin
    cp /tmp/lab-postlogin-default.sh    /usr/local/sbin
    cp /tmp/labsecurity-agent.sh        /usr/local/sbin
    cp /tmp/labadmin.pub                /usr/local/sbin
    cp /tmp/lab-ipset-update.sh         /usr/local/sbin
    cp /tmp/lab-block-status.sh         /usr/local/sbin

    chmod 755 /usr/local/sbin/lab-profile-config.sh
    chmod 755 /usr/local/sbin/lab-aluno-config.sh
    chmod 755 /usr/local/sbin/lab-programs.sh
    chmod 755 /usr/local/sbin/lab-eula-programs.sh
    chmod 755 /usr/local/sbin/lab-program-config.sh
    chmod 755 /usr/local/sbin/lab-inventory.sh
    chmod 755 /usr/local/sbin/lab-admin-profile-config.sh
    chmod 755 /usr/local/sbin/lab-block.sh
    chmod 755 /usr/local/sbin/lab-block-sites.sh
    chmod 755 /usr/local/sbin/lab-unblock.sh
    chmod 755 /usr/local/sbin/lab-block-terminal.sh
    chmod 755 /usr/local/sbin/lab-unblock-terminal.sh
    chmod 755 /usr/local/sbin/lab-postlogin-default.sh
    chmod 755 /usr/local/sbin/labsecurity-agent.sh
    chmod 644 /usr/local/sbin/labadmin.pub
    chmod 755 /usr/local/sbin/lab-ipset-update.sh
    chmod 755 /usr/local/sbin/lab-block-status.sh

    # Units do systemd
    cp /tmp/lab-ipset-update.service    /etc/systemd/system/
    cp /tmp/lab-ipset-update.timer      /etc/systemd/system/
    chmod 644 /etc/systemd/system/lab-ipset-update.service
    chmod 644 /etc/systemd/system/lab-ipset-update.timer
    systemctl daemon-reload

    echo "[OK] Scripts copiados com sucesso!"
    echo ""

    # =============================================
    # 3.1 Copia o PostLogin/Default
    # =============================================
    if [ -f /usr/local/sbin/lab-postlogin-default.sh ]; then
        mkdir -p /etc/gdm3/PostLogin
        cp /usr/local/sbin/lab-postlogin-default.sh /etc/gdm3/PostLogin/Default
        chmod a+x /etc/gdm3/PostLogin/Default
        echo "[OK] /etc/gdm3/PostLogin/Default atualizado"
        echo ""
    fi

    echo "========================================="
    echo "  Executando scripts de configuracao..."
    echo "========================================="

    /usr/local/sbin/lab-profile-config.sh
    /usr/local/sbin/lab-aluno-config.sh
    /usr/local/sbin/lab-programs.sh
    /usr/local/sbin/lab-eula-programs.sh
    /usr/local/sbin/lab-program-config.sh
    /usr/local/sbin/lab-inventory.sh
    /usr/local/sbin/lab-admin-profile-config.sh

    rm -f /tmp/lab-admin-profile-config.sh

    echo ""
    echo "[OK] SCRIPTS ATUALIZADOS E EXECUTADOS"
    echo "true" > /usr/local/sbin/done.txt
else
    echo "[OK] SEM NECESSIDADE DE ATUALIZAR SCRIPTS"
fi

echo ""

# ==============================
# 3.5 SEMPRE roda o lab-programs.sh
# ==============================
if [ -x /usr/local/sbin/lab-programs.sh ]; then
    echo "========================================="
    echo "  Rodando lab-programs.sh (SEMPRE)..."
    echo "========================================="
    /usr/local/sbin/lab-programs.sh
    echo ""
fi

# ==============================
# 4. Instala e inicia o agente LabSecurity
# ==============================
echo "========================================="
echo "  Instalando LabSecurity Agent..."
echo "========================================="

if [ -f /usr/local/sbin/labsecurity-agent.sh ]; then
    echo "[OK] Agente encontrado"

    cat > /etc/systemd/system/labsecurity-agent.service << 'EOF'
[Unit]
Description=LabSecurity Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/sbin/labsecurity-agent.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable labsecurity-agent.service
    systemctl restart labsecurity-agent.service

    sleep 2

    if systemctl is-active --quiet labsecurity-agent.service; then
        echo "[OK] LabSecurity Agent instalado e rodando!"
    else
        echo "[AVISO] Falha ao iniciar o servico."
    fi
else
    echo "[AVISO] labsecurity-agent.sh nao encontrado"
fi

echo ""

# ==============================
# 4.5 Desabilita timers que não devem rodar no boot
# ==============================
if systemctl list-unit-files 2>/dev/null | grep -q '^lab-ipset-update.timer'; then
    if systemctl is-enabled --quiet lab-ipset-update.timer 2>/dev/null; then
        echo "[INFO] Desabilitando lab-ipset-update.timer (só roda durante reservas)"
        systemctl disable --now lab-ipset-update.timer >/dev/null 2>&1 || true
    fi
fi

echo ""

# ==============================
# 5. Executa recriacao do usuario NATI
# ==============================
echo "========================================="
echo "  Recriando usuario NATI..."
echo "========================================="

if [ -f /usr/local/sbin/lab-admin-profile-config.sh ]; then
    /usr/local/sbin/lab-admin-profile-config.sh
    echo "[OK] Usuario NATI configurado"
else
    echo "[AVISO] lab-admin-profile-config.sh nao encontrado"
fi

echo ""

# ==============================
# 6. Informacoes finais
# ==============================
echo "========================================="
echo "  CONFIGURACAO CONCLUIDA!"
echo "========================================="
echo ""
echo "RESUMO:"
echo "   [OK] Scripts do laboratorio atualizados"
echo "   [OK] LabSecurity Agent instalado"
echo "   [OK] Terminal bloqueável via lab-block.sh"
echo "   [OK] ipset-update instalado (inativo até a 1ª reserva)"
echo ""
echo "BLOQUEIO:"
echo "   Bloquear:    sudo /usr/local/sbin/lab-block.sh \"site1,site2\""
echo "   Desbloquear: sudo /usr/local/sbin/lab-unblock.sh"
echo "   Status:      sudo /usr/local/sbin/lab-block-status.sh"
echo ""
echo "LOGS:"
echo "   lab: tail -f /var/log/lab.log"
echo ""
echo "========================================="

exit 0

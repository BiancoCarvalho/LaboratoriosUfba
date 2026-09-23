#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v11.0.0
#
#  Mudanças em relação à v10:
#    - Baixa e instala os 4 novos arquivos do watchdog:
#         lab-block-status.sh, lab-watchdog.sh,
#         lab-watchdog.service, lab-watchdog.timer
#    - Instala as units no systemd (cp + daemon-reload)
#    - Compara TODOS os 17 arquivos no controle de atualização
#    - Executa lab-programs.sh SEMPRE (selos decidem internamente)
#    - NÃO habilita o lab-watchdog.timer no boot (ativado só
#      quando uma reserva começa, via lab-block.sh)
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"

# ==============================
# 1. Baixa os scripts atualizados do repositório
# ==============================
echo "========================================="
echo "  Baixando scripts do repositorio..."
echo "========================================="

# --- scripts existentes (v10) ---
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
wget -q --timeout=30 --tries=3 "$REPO/lab-postlogin-default.sh"      -O /tmp/lab-postlogin-default.sh
wget -q --timeout=30 --tries=3 "$REPO/labsecurity-agent.sh"          -O /tmp/labsecurity-agent.sh
wget -q --timeout=30 --tries=3 "$REPO/labadmin.pub"                  -O /tmp/labadmin.pub

# --- novos scripts (v11) ---
wget -q --timeout=30 --tries=3 "$REPO/lab-block-status.sh"           -O /tmp/lab-block-status.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-watchdog.sh"               -O /tmp/lab-watchdog.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-watchdog.service"          -O /tmp/lab-watchdog.service
wget -q --timeout=30 --tries=3 "$REPO/lab-watchdog.timer"            -O /tmp/lab-watchdog.timer

wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.sh"           -O /tmp/lab-ipset-update.sh
wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.service"      -O /tmp/lab-ipset-update.service
wget -q --timeout=30 --tries=3 "$REPO/lab-ipset-update.timer"        -O /tmp/lab-ipset-update.timer

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
    # --- scripts existentes ---
    if [ ! -f /usr/local/sbin/lab-profile-config.sh ] || ! cmp -s /usr/local/sbin/lab-profile-config.sh /tmp/lab-profile-config.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-aluno-config.sh ] || ! cmp -s /usr/local/sbin/lab-aluno-config.sh /tmp/lab-aluno-config.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-programs.sh ] || ! cmp -s /usr/local/sbin/lab-programs.sh /tmp/lab-programs.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-eula-programs.sh ] || ! cmp -s /usr/local/sbin/lab-eula-programs.sh /tmp/lab-eula-programs.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-program-config.sh ] || ! cmp -s /usr/local/sbin/lab-program-config.sh /tmp/lab-program-config.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-inventory.sh ] || ! cmp -s /usr/local/sbin/lab-inventory.sh /tmp/lab-inventory.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-admin-profile-config.sh ] || ! cmp -s /usr/local/sbin/lab-admin-profile-config.sh /tmp/lab-admin-profile-config.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/labsecurity-agent.sh ] || ! cmp -s /usr/local/sbin/labsecurity-agent.sh /tmp/labsecurity-agent.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi

    # ⭐ NOVOS — ipset update
    if [ ! -f /usr/local/sbin/lab-ipset-update.sh ] || ! cmp -s /usr/local/sbin/lab-ipset-update.sh /tmp/lab-ipset-update.sh; then
    echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /etc/systemd/system/lab-ipset-update.service ] || ! cmp -s /etc/systemd/system/lab-ipset-update.service /tmp/lab-ipset-update.service; then
    echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /etc/systemd/system/lab-ipset-update.timer ] || ! cmp -s /etc/systemd/system/lab-ipset-update.timer /tmp/lab-ipset-update.timer; then
    echo "false" > /usr/local/sbin/done.txt
    fi

    # --- novos scripts ---
    if [ ! -f /usr/local/sbin/lab-block-status.sh ] || ! cmp -s /usr/local/sbin/lab-block-status.sh /tmp/lab-block-status.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-watchdog.sh ] || ! cmp -s /usr/local/sbin/lab-watchdog.sh /tmp/lab-watchdog.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /etc/systemd/system/lab-watchdog.service ] || ! cmp -s /etc/systemd/system/lab-watchdog.service /tmp/lab-watchdog.service; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /etc/systemd/system/lab-watchdog.timer ] || ! cmp -s /etc/systemd/system/lab-watchdog.timer /tmp/lab-watchdog.timer; then
        echo "false" > /usr/local/sbin/done.txt
    fi

    # ⚠ Também considera mudanças nos scripts que já eram baixados
    #    mas NÃO estavam sendo comparados (block, block-sites, unblock,
    #    postlogin, admin-profile). Isso corrige um bug da v10.
    if [ ! -f /usr/local/sbin/lab-block.sh ] || ! cmp -s /usr/local/sbin/lab-block.sh /tmp/lab-block.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-block-sites.sh ] || ! cmp -s /usr/local/sbin/lab-block-sites.sh /tmp/lab-block-sites.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-unblock.sh ] || ! cmp -s /usr/local/sbin/lab-unblock.sh /tmp/lab-unblock.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
    if [ ! -f /usr/local/sbin/lab-postlogin-default.sh ] || ! cmp -s /usr/local/sbin/lab-postlogin-default.sh /tmp/lab-postlogin-default.sh; then
        echo "false" > /usr/local/sbin/done.txt
    fi
fi

DONE=$(cat /usr/local/sbin/done.txt)

# ==============================
# 3. Copia e executa scripts se houve atualizacao
# ==============================
if [ "$DONE" = "false" ]; then
    echo "========================================="
    echo "  Atualizando scripts..."
    echo "========================================="

    # --- scripts existentes ---
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
    cp /tmp/lab-postlogin-default.sh    /usr/local/sbin
    cp /tmp/labsecurity-agent.sh        /usr/local/sbin
    cp /tmp/labadmin.pub                /usr/local/sbin

    # --- novos scripts ---
    cp /tmp/lab-block-status.sh         /usr/local/sbin
    cp /tmp/lab-watchdog.sh             /usr/local/sbin

    # --- permissões (scripts existentes) ---
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
    chmod 755 /usr/local/sbin/lab-postlogin-default.sh
    chmod 755 /usr/local/sbin/labsecurity-agent.sh
    chmod 644 /usr/local/sbin/labadmin.pub

    # --- permissões (novos scripts) ---
    chmod 755 /usr/local/sbin/lab-block-status.sh
    chmod 755 /usr/local/sbin/lab-watchdog.sh

    # --- units do systemd ---
    # Copia as units, mas NÃO habilita o timer automaticamente.
    # O lab-block.sh fará "systemctl enable --now" quando a reserva começar.
    cp /tmp/lab-watchdog.service /etc/systemd/system/lab-watchdog.service
    cp /tmp/lab-watchdog.timer   /etc/systemd/system/lab-watchdog.timer
    chmod 644 /etc/systemd/system/lab-watchdog.service
    chmod 644 /etc/systemd/system/lab-watchdog.timer
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
# 3.5 SEMPRE roda o lab-programs.sh (selos decidem)
# ==============================
# Mesmo que "nada mudou", roda o lab-programs.sh para instalar
# programas novos que foram adicionados ao script.
if [ -x /usr/local/sbin/lab-programs.sh ]; then
    echo "========================================="
    echo "  Rodando lab-programs.sh (SEMPRE)..."
    echo "========================================="
    /usr/local/sbin/lab-programs.sh
    echo ""
fi

# ==============================
# 4. Instala e inicia o agente LabSecurity como servico
# ==============================
echo "========================================="
echo "  Instalando LabSecurity Agent..."
echo "========================================="

if [ -f /usr/local/sbin/labsecurity-agent.sh ]; then
    echo "[OK] Agente encontrado em /usr/local/sbin/labsecurity-agent.sh"

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

    echo "[OK] Servico systemd criado"

    systemctl daemon-reload
    systemctl enable labsecurity-agent.service
    systemctl restart labsecurity-agent.service

    sleep 2

    if systemctl is-active --quiet labsecurity-agent.service; then
        echo "[OK] LabSecurity Agent instalado e rodando!"
        echo "Dashboard: http://IC-1046419:5000"
    else
        echo "[AVISO] Falha ao iniciar o servico."
    fi
else
    echo "[AVISO] labsecurity-agent.sh nao encontrado"
fi

echo ""

# ==============================
# 4.5 Garante que o lab-watchdog.timer NÃO está habilitado no boot
# ==============================
# O watchdog só deve rodar durante uma reserva ativa.
# Se por algum motivo ele foi habilitado antes, desabilita agora.
if systemctl list-unit-files 2>/dev/null | grep -q '^lab-watchdog.timer'; then
    if systemctl is-enabled --quiet lab-watchdog.timer 2>/dev/null; then
        echo "[INFO] Desabilitando lab-watchdog.timer (só roda durante reservas)"
        systemctl disable --now lab-watchdog.timer >/dev/null 2>&1 || true
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
echo "   [OK] Watchdog de bloqueio instalado (inativo ate a 1a reserva)"
echo ""
echo "PARA MONITORAR:"
echo "   Acesse http://IC-1046419:5000 no navegador"
echo ""
echo "COMANDOS UTEIS:"
echo "   Ver status:      systemctl status labsecurity-agent"
echo "   Ver logs:        journalctl -u labsecurity-agent -f"
echo "   Parar agente:    systemctl stop labsecurity-agent"
echo "   Iniciar agente:  systemctl start labsecurity-agent"
echo "   Reiniciar:       systemctl restart labsecurity-agent"
echo ""
echo "WATCHDOG DE BLOQUEIO:"
echo "   Status do timer:    systemctl status lab-watchdog.timer"
echo "   Ver agendamento:    systemctl list-timers lab-watchdog.timer"
echo "   Ver logs:           journalctl -u lab-watchdog.service -f"
echo "   Status do bloqueio: sudo /usr/local/sbin/lab-block-status.sh"
echo ""
echo "LOGS:"
echo "   systemd: journalctl -u labsecurity-agent -n 50"
echo "   arquivo: tail -f /var/log/labsecurity-agent.log"
echo ""
echo "========================================="

exit 0

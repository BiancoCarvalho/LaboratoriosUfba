#!/bin/sh
# =====================================================================
#  install.sh
#  Instala o serviço que roda os scripts no boot
#  Uso: wget -O - <URL>/install.sh | sudo bash
# =====================================================================

set -e

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"

echo "=================================================="
echo " Instalando lab-startup.service"
echo "=================================================="
echo ""

# ---------------------------------------------------------------------
# 1) Cria o script que roda no boot
# ---------------------------------------------------------------------
echo "==> [1/4] Criando /root/labstartup.sh"

cat > /root/labstartup.sh <<'EOF'
#!/bin/sh
# Baixa o lab-startup.sh mais recente e executa
wget -q -O /tmp/startup.sh https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main/lab-startup.sh
chmod a+x /tmp/startup.sh
/tmp/startup.sh
exit 0
EOF

chmod a+x /root/labstartup.sh
echo "    + /root/labstartup.sh criado"

# ---------------------------------------------------------------------
# 2) Cria o serviço systemd
# ---------------------------------------------------------------------
echo "==> [2/4] Criando /etc/systemd/system/labstartup.service"

cat > /etc/systemd/system/labstartup.service <<'EOF'
[Unit]
Description=Atualiza instalacao dos labs
Wants=network-online.target
After=network.target network-online.target

[Service]
ExecStart=/root/labstartup.sh
Type=oneshot
Restart=on-failure
RestartSec=20

[Install]
WantedBy=multi-user.target
EOF

echo "    + labstartup.service criado"

# ---------------------------------------------------------------------
# 3) Recarrega systemd e habilita
# ---------------------------------------------------------------------
echo "==> [3/4] Habilitando serviço"

systemctl daemon-reload
systemctl enable labstartup.service

echo "    + serviço habilitado (roda no próximo boot)"

# ---------------------------------------------------------------------
# 4) Roda AGORA (sem precisar reiniciar)
# ---------------------------------------------------------------------
echo "==> [4/4] Executando pela primeira vez (pode demorar ~30s)"
echo ""

systemctl start labstartup.service

# Espera até 60s para terminar
for i in $(seq 1 60); do
    if systemctl is-active --quiet labstartup.service; then
        sleep 1
    else
        break
    fi
done

# ---------------------------------------------------------------------
# Verificação
# ---------------------------------------------------------------------
echo ""
echo "=================================================="
echo " VERIFICAÇÃO"
echo "=================================================="
echo ""

if systemctl is-enabled --quiet labstartup.service; then
    echo "  ✅ Serviço habilitado (roda a cada boot)"
else
    echo "  ❌ Serviço NÃO habilitado"
fi

STATUS=$(systemctl is-active labstartup.service)
if [ "$STATUS" = "active" ]; then
    echo "  ⏳ Serviço ainda rodando..."
elif [ "$STATUS" = "failed" ]; then
    echo "  ⚠️ Serviço falhou. Veja o log:"
    echo "     journalctl -u labstartup.service -n 50"
else
    echo "  ✅ Serviço terminou (código: $STATUS)"
fi

echo ""
echo " Verificando scripts instalados:"
for f in lab-block.sh lab-unblock.sh lab-prova-config.sh lab-labadmin-config.sh; do
    if [ -f "/usr/local/sbin/$f" ]; then
        SIZE=$(stat -c%s "/usr/local/sbin/$f" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 0 ]; then
            echo "  ✅ /usr/local/sbin/$f ($SIZE bytes)"
        else
            echo "  ❌ /usr/local/sbin/$f está VAZIO"
        fi
    else
        echo "  ❌ /usr/local/sbin/$f NÃO existe"
    fi
done

echo ""
echo " Verificando usuários:"
if id labadmin &>/dev/null; then
    echo "  ✅ usuário labadmin existe"
else
    echo "  ⚠️ usuário labadmin NÃO existe (rode o lab-labadmin-config.sh)"
fi

if id prova &>/dev/null; then
    echo "  ⚠️ usuário prova EXISTE (será removido no unblock)"
else
    echo "  ✅ usuário prova NÃO existe (normal antes da prova)"
fi

echo ""
echo "=================================================="
echo " ✅ INSTALAÇÃO CONCLUÍDA"
echo "=================================================="
echo ""
echo " Para acompanhar o log:"
echo "   journalctl -fu labstartup.service"
echo ""
echo " Para rodar de novo manualmente:"
echo "   systemctl restart labstartup.service"
echo ""

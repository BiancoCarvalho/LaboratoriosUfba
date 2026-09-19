#!/bin/sh
# =====================================================================
#  install.sh
#  Instala o serviço labstartup (roda a cada boot)
#  NÃO dispara na instalação — você roda manualmente quando quiser
#
#  Uso:
#    wget -O - https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main/install.sh | sudo bash
#
#  Depois, para rodar manualmente:
#    sudo systemctl start labstartup.service
#    sudo journalctl -fu labstartup.service
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
echo "==> [1/3] Criando /root/labstartup.sh"

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
echo "==> [2/3] Criando /etc/systemd/system/labstartup.service"

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
# 3) Recarrega systemd e habilita (sem iniciar)
# ---------------------------------------------------------------------
echo "==> [3/3] Habilitando serviço (sem iniciar)"

systemctl daemon-reload
systemctl enable labstartup.service

echo "    + serviço habilitado (roda no próximo boot)"

# ---------------------------------------------------------------------
# Verificação
# ---------------------------------------------------------------------
echo ""
echo "=================================================="
echo " VERIFICAÇÃO"
echo "=================================================="
echo ""

if systemctl is-enabled --quiet labstartup.service; then
    echo "  OK: Serviço habilitado (roda a cada boot)"
else
    echo "  ERRO: Serviço NÃO habilitado"
fi

STATUS=$(systemctl is-active labstartup.service)
if [ "$STATUS" = "active" ]; then
    echo "  Serviço está ATIVO agora"
else
    echo "  Serviço está INATIVO (normal — não foi iniciado)"
fi

echo ""
echo "=================================================="
echo " INSTALAÇÃO CONCLUÍDA"
echo "=================================================="
echo ""
echo " O serviço está instalado, mas NÃO foi iniciado."
echo ""
echo " Para rodar AGORA (manualmente):"
echo "   sudo systemctl start labstartup.service"
echo ""
echo " Para acompanhar o log:"
echo "   sudo journalctl -fu labstartup.service"
echo ""
echo " Para rodar de novo:"
echo "   sudo systemctl restart labstartup.service"
echo ""
echo " Para ver o status:"
echo "   sudo systemctl status labstartup.service"
echo ""

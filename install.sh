#!/bin/bash
# =====================================================================
#  install.sh
#  v2.0.0
#
#  Executado UMA VEZ para preparar a máquina.
#  - Cria /root/labstartup.sh (wrapper que baixa do GitHub e executa)
#  - Cria e habilita /etc/systemd/system/labstartup.service
#  - Roda o lab-startup.sh uma vez (pra já instalar tudo agora)
#
#  Depois disso, toda reinicialização chama o labstartup.service,
#  que roda o /root/labstartup.sh, que baixa a versão mais nova do
#  GitHub e executa.
# =====================================================================

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
LOG="/var/log/labstartup.log"

echo "========================================="
echo "  install.sh v2.0.0"
echo "  Configurando atualização automática"
echo "========================================="

# ---------------------------------------------------------------------
# 1) Cria o wrapper /root/labstartup.sh
# ---------------------------------------------------------------------
echo "==> Criando /root/labstartup.sh..."

cat > /root/labstartup.sh <<'WRAPPER_EOF'
#!/bin/bash
# =====================================================================
# /root/labstartup.sh
# Roda no boot, baixa o lab-startup.sh do GitHub e executa.
# =====================================================================

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
LOG="/var/log/labstartup.log"

echo "[$(date '+%F %T')] === INÍCIO ===" >> "$LOG"

# Espera a rede (até 60s)
for i in $(seq 1 30); do
    if ping -c 1 -W 2 raw.githubusercontent.com &>/dev/null; then
        break
    fi
    echo "[$(date '+%F %T')] aguardando rede... ($i/30)" >> "$LOG"
    sleep 2
done

# Baixa o lab-startup.sh
if ! wget -q --timeout=30 --tries=3 "$REPO/lab-startup.sh" -O /tmp/startup.sh; then
    echo "[$(date '+%F %T')] ❌ Falha ao baixar lab-startup.sh" >> "$LOG"
    exit 1
fi

if [ ! -s /tmp/startup.sh ]; then
    echo "[$(date '+%F %T')] ❌ lab-startup.sh vazio" >> "$LOG"
    exit 1
fi

chmod +x /tmp/startup.sh

# Roda
echo "[$(date '+%F %T')] Executando lab-startup.sh..." >> "$LOG"
/tmp/startup.sh >> "$LOG" 2>&1

RET=$?
echo "[$(date '+%F %T')] === FIM (exit $RET) ===" >> "$LOG"
exit $RET
WRAPPER_EOF

chmod +x /root/labstartup.sh
echo "  ✅ /root/labstartup.sh criado"

# ---------------------------------------------------------------------
# 2) Cria o serviço systemd
# ---------------------------------------------------------------------
echo "==> Criando /etc/systemd/system/labstartup.service..."

cat > /etc/systemd/system/labstartup.service <<'SERVICE_EOF'
[Unit]
Description=Atualiza instalacao dos labs
Wants=network-online.target
After=network.target network-online.target

[Service]
ExecStart=/root/labstartup.sh
Type=oneshot
Restart=on-failure
RestartSec=20
TimeoutStartSec=3600

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable labstartup.service
echo "  ✅ Serviço criado e habilitado"

# ---------------------------------------------------------------------
# 3) Roda agora (uma vez) — pra já instalar tudo neste boot
# ---------------------------------------------------------------------
echo "==> Executando lab-startup.sh agora (primeira vez)..."
/root/labstartup.sh

# ---------------------------------------------------------------------
# 4) Resumo
# ---------------------------------------------------------------------
echo ""
echo "========================================="
echo "  ✅ CONCLUÍDO"
echo "========================================="
echo ""
echo "A partir de agora, a cada reinicialização:"
echo "  1. systemd dispara labstartup.service"
echo "  2. /root/labstartup.sh baixa o lab-startup.sh do GitHub"
echo "  3. lab-startup.sh baixa TODOS os scripts (incluindo lab-programs.sh)"
echo "  4. Compara com os locais e atualiza os que mudaram"
echo "  5. Executa o lab-programs.sh (que instala o que falta)"
echo ""
echo "Logs:"
echo "  tail -f /var/log/labstartup.log"
echo "  tail -f /var/log/lab-startup.log"
echo ""
echo "Para verificar que o serviço está habilitado:"
echo "  systemctl is-enabled labstartup.service"
echo ""
echo "========================================="

exit 0

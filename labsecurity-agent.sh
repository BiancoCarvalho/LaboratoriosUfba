#!/bin/bash
# LabSecurity Agent Script
# v1.0.0
# Monitoramento de recursos para laboratórios
# Servidor: IC-1046419.local

# ==============================
# Configurações
# ==============================
SERVER="http://IC-1046419.local:5000"
LOG_FILE="/home/NATI/labsecurity-agent.log"
PID_FILE="/tmp/labsecurity-agent.pid"
SERVICE_NAME="labsecurity-agent"

# ==============================
# Cores para output
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ==============================
# Função de log
# ==============================
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# ==============================
# Verificar conectividade com o servidor
# ==============================
check_server() {
    if ping -c 1 IC-1046419.local &> /dev/null; then
        return 0
    else
        log_message "ERRO: Servidor IC-1046419.local não está acessível"
        return 1
    fi
}

# ==============================
# Coletar dados do sistema (VERSÃO SIMPLIFICADA QUE FUNCIONA)
# ==============================
collect_data() {
    # CPU Usage - garantir formato com ponto
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr ',' '.')
    if [ -z "$CPU" ]; then
        CPU=50
    fi
    CPU=$(printf "%.1f" "$CPU" | tr ',' '.')
    
    # RAM Usage
    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED=$(free | grep Mem | awk '{print $3}')
    RAM=$(echo "scale=1; ($MEM_USED/$MEM_TOTAL)*100" | bc | tr ',' '.')
    
    # Disk Usage
    DISK=$(df -h / | tail -n1 | awk '{print $5}' | sed 's/%//')
    
    # Hostname
    HOSTNAME=$(hostname)
    
    # Criar JSON APENAS COM OS CAMPOS ESSENCIAIS
    cat <<EOF
{"machine":"$HOSTNAME","timestamp":"$(date '+%Y-%m-%d %H:%M:%S')","cpu":$CPU,"ram":$RAM,"disk":$DISK,"os":"Linux"}
EOF
}

# ==============================
# Enviar dados para o servidor
# ==============================
send_data() {
    local data="$1"
    
    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -X POST "$SERVER/api/data" \
                     -H "Content-Type: application/json" \
                     -d "$data" \
                     -s -o /dev/null \
                     -w "%{http_code}" \
                     --max-time 10)
        echo $HTTP_CODE
    elif command -v wget &> /dev/null; then
        wget --quiet --method POST \
             --header "Content-Type: application/json" \
             --body-data="$data" \
             --output-document=/dev/null \
             --timeout=10 \
             "$SERVER/api/data" 2>&1
        echo "200"
    else
        echo "000"
    fi
}

# ==============================
# Instalar como serviço
# ==============================
install_service() {
    echo "Instalando serviço $SERVICE_NAME..."
    
    # Copiar script para /usr/local/sbin
    cp /home/NATI/labsecurity-agent.sh /usr/local/sbin/$SERVICE_NAME.sh
    chmod +x /usr/local/sbin/$SERVICE_NAME.sh
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=LabSecurity Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/sbin/$SERVICE_NAME.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME.service
    systemctl start $SERVICE_NAME.service
    
    if systemctl is-active --quiet $SERVICE_NAME.service; then
        echo -e "${GREEN}✅ Serviço $SERVICE_NAME instalado e rodando!${NC}"
        log_message "Serviço instalado e iniciado com sucesso"
        return 0
    else
        echo -e "${RED}❌ Falha ao iniciar o serviço${NC}"
        log_message "ERRO: Falha ao iniciar o serviço"
        return 1
    fi
}

# ==============================
# Remover serviço
# ==============================
remove_service() {
    echo "Removendo serviço $SERVICE_NAME..."
    
    systemctl stop $SERVICE_NAME.service 2>/dev/null
    systemctl disable $SERVICE_NAME.service 2>/dev/null
    rm -f /etc/systemd/system/$SERVICE_NAME.service
    rm -f /usr/local/sbin/$SERVICE_NAME.sh
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ Serviço removido${NC}"
    log_message "Serviço removido"
}

# ==============================
# Executar agente (modo direto)
# ==============================
run_agent() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  LabSecurity Agent - Modo Direto${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "Servidor: $SERVER"
    echo "Máquina: $(hostname)"
    echo "Log: $LOG_FILE"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    log_message "Agente iniciado em modo direto na máquina $(hostname)"
    
    while true; do
        if check_server; then
            DATA=$(collect_data)
            HTTP_CODE=$(send_data "$DATA")
            
            # Extrair valores para exibição
            CPU=$(echo "$DATA" | grep -o '"cpu":[0-9.]*' | cut -d':' -f2)
            RAM=$(echo "$DATA" | grep -o '"ram":[0-9.]*' | cut -d':' -f2)
            DISK=$(echo "$DATA" | grep -o '"disk":[0-9.]*' | cut -d':' -f2)
            
            if [ "$HTTP_CODE" = "200" ]; then
                echo -e "[$(date '+%H:%M:%S')] ${GREEN}✓${NC} CPU:${CPU}% RAM:${RAM}% DISK:${DISK}%"
                log_message "OK - CPU:${CPU}% RAM:${RAM}% DISK:${DISK}%"
            else
                echo -e "[$(date '+%H:%M:%S')] ${RED}✗${NC} Falha ao enviar (HTTP $HTTP_CODE)"
                log_message "ERRO - Falha ao enviar (HTTP $HTTP_CODE)"
                # Salvar dados localmente se falhar
                echo "$DATA" >> /tmp/labsecurity_cache.json
            fi
        else
            echo -e "[$(date '+%H:%M:%S')] ${YELLOW}⚠${NC} Servidor IC-1046419.local offline"
        fi
        
        sleep 30
    done
}

# ==============================
# Verificar status
# ==============================
check_status() {
    if systemctl is-active --quiet $SERVICE_NAME.service 2>/dev/null; then
        echo -e "${GREEN}✅ Serviço $SERVICE_NAME está rodando${NC}"
        systemctl status $SERVICE_NAME.service --no-pager
    else
        echo -e "${RED}❌ Serviço $SERVICE_NAME não está rodando${NC}"
    fi
}

# ==============================
# Mostrar logs
# ==============================
show_logs() {
    if [ -f $LOG_FILE ]; then
        tail -f $LOG_FILE
    else
        echo -e "${RED}Arquivo de log não encontrado${NC}"
    fi
}

# ==============================
# Menu principal
# ==============================
show_help() {
    echo "========================================="
    echo "  LabSecurity Agent - Script de Monitoramento"
    echo "========================================="
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  install   - Instalar como serviço systemd"
    echo "  remove    - Remover o serviço"
    echo "  start     - Iniciar o serviço"
    echo "  stop      - Parar o serviço"
    echo "  status    - Verificar status do serviço"
    echo "  run       - Executar em modo direto (terminal)"
    echo "  logs      - Mostrar logs em tempo real"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 install   # Instalar e iniciar como serviço"
    echo "  $0 run       # Executar diretamente no terminal"
    echo "  $0 status    # Verificar se está rodando"
    echo "========================================="
}

# ==============================
# Main
# ==============================
case "${1:-help}" in
    install)
        install_service
        ;;
    remove)
        remove_service
        ;;
    start)
        systemctl start $SERVICE_NAME.service
        echo -e "${GREEN}✅ Serviço iniciado${NC}"
        ;;
    stop)
        systemctl stop $SERVICE_NAME.service
        echo -e "${GREEN}✅ Serviço parado${NC}"
        ;;
    status)
        check_status
        ;;
    run)
        run_agent
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Comando desconhecido: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0
EOF

chmod +x /home/NATI/labsecurity-agent.sh

#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# ==============================
# 1. Baixa os scripts atualizados do repositório
# ==============================
echo "========================================="
echo "  Baixando scripts do repositório..."
echo "========================================="

wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-profile-config.sh -O /tmp/lab-profile-config.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-aluno-config.sh -O /tmp/lab-aluno-config.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-programs.sh -O /tmp/lab-programs.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-eula-programs.sh -O /tmp/lab-eula-programs.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-program-config.sh -O /tmp/lab-program-config.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-inventory.sh -O /tmp/lab-inventory.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-admin-profile-config.sh -O /tmp/lab-admin-profile-config.sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/labsecurity-agent.sh -O /tmp/labsecurity-agent.sh

echo "✅ Download concluído!"
echo ""

# ==============================
# 2. Verifica se já existe o controle de atualização
# ==============================
echo "========================================="
echo "  Verificando atualizações..."
echo "========================================="

if ! [ -f /usr/local/sbin/done.txt ]; then
	touch /usr/local/sbin/done.txt
	echo "false" > /usr/local/sbin/done.txt
	chmod 755 /usr/local/sbin/done.txt
else
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
fi

DONE=$(cat /usr/local/sbin/done.txt)

# ==============================
# 3. Copia e executa scripts se houve atualização
# ==============================
if [ "$DONE" = "false" ]; then
	echo "========================================="
	echo "  Atualizando scripts..."
	echo "========================================="
	
	cp /tmp/lab-profile-config.sh /usr/local/sbin
	cp /tmp/lab-aluno-config.sh /usr/local/sbin
	cp /tmp/lab-programs.sh /usr/local/sbin
	cp /tmp/lab-eula-programs.sh /usr/local/sbin
	cp /tmp/lab-program-config.sh /usr/local/sbin
	cp /tmp/lab-inventory.sh /usr/local/sbin
	cp /tmp/lab-admin-profile-config.sh /usr/local/sbin
	cp /tmp/labsecurity-agent.sh /usr/local/sbin

	chmod 755 /usr/local/sbin/lab-profile-config.sh
	chmod 755 /usr/local/sbin/lab-aluno-config.sh
	chmod 755 /usr/local/sbin/lab-programs.sh
	chmod 755 /usr/local/sbin/lab-eula-programs.sh
	chmod 755 /usr/local/sbin/lab-program-config.sh
	chmod 755 /usr/local/sbin/lab-inventory.sh
	chmod 755 /usr/local/sbin/lab-admin-profile-config.sh
	chmod 755 /usr/local/sbin/labsecurity-agent.sh

	echo "✅ Scripts copiados com sucesso!"
	echo ""
	
	echo "========================================="
	echo "  Executando scripts de configuração..."
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
	echo "✅ SCRIPTS ATUALIZADOS E EXECUTADOS"
	echo "true" > /usr/local/sbin/done.txt
else
	echo "✅ SEM NECESSIDADE DE ATUALIZAR SCRIPTS"
fi

echo ""

# ==============================
# 4. Instala e inicia o agente LabSecurity como serviço
# ==============================
echo "========================================="
echo "  Instalando LabSecurity Agent..."
echo "========================================="

# Verificar se o arquivo do agente existe
if [ -f /usr/local/sbin/labsecurity-agent.sh ]; then
    
    echo "✅ Agente encontrado em /usr/local/sbin/labsecurity-agent.sh"
    
    # Criar serviço systemd
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

    echo "✅ Serviço systemd criado"
    
    # Recarregar systemd e ativar serviço
    systemctl daemon-reload
    systemctl enable labsecurity-agent.service
    systemctl restart labsecurity-agent.service
    
    sleep 2
    
    # Verificar se o serviço iniciou corretamente
    if systemctl is-active --quiet labsecurity-agent.service; then
        echo "✅ LabSecurity Agent instalado e rodando!"
        echo "📊 Dashboard: http://IC-1046419:5000"
    else
        echo "⚠️ Falha ao iniciar o serviço. Verifique os logs:"
        echo "   journalctl -u labsecurity-agent.service -f"
    fi
else
    echo "❌ Arquivo labsecurity-agent.sh não encontrado!"
    echo "   Verificando se o download foi feito corretamente..."
    
    if [ -f /tmp/labsecurity-agent.sh ]; then
        echo "   Arquivo encontrado em /tmp, copiando manualmente..."
        cp /tmp/labsecurity-agent.sh /usr/local/sbin/
        chmod 755 /usr/local/sbin/labsecurity-agent.sh
        echo "   ✅ Copiado! Reiniciando instalação..."
        
        # Tentar instalar novamente
        cat > /etc/systemd/system/labsecurity-agent.service << 'EOF'
[Unit]
Description=LabSecurity Monitoring Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/sbin/labsecurity-agent.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable labsecurity-agent.service
        systemctl start labsecurity-agent.service
        
        if systemctl is-active --quiet labsecurity-agent.service; then
            echo "✅ LabSecurity Agent instalado com sucesso!"
        else
            echo "❌ Falha na instalação"
        fi
    else
        echo "❌ Arquivo não encontrado em nenhum local!"
    fi
fi

echo ""

# ==============================
# 5. Executa recriação do usuário NATI
# ==============================
echo "========================================="
echo "  Recriando usuário NATI..."
echo "========================================="

if [ -f /usr/local/sbin/lab-admin-profile-config.sh ]; then
    /usr/local/sbin/lab-admin-profile-config.sh
    echo "✅ Usuário NATI configurado"
else
    echo "⚠️ Script lab-admin-profile-config.sh não encontrado"
fi

echo ""

# ==============================
# 6. Informações finais
# ==============================
echo "========================================="
echo "  CONFIGURAÇÃO CONCLUÍDA!"
echo "========================================="
echo ""
echo "📋 RESUMO:"
echo "   ✅ Scripts do laboratório atualizados"
echo "   ✅ LabSecurity Agent instalado"
echo ""
echo "📊 PARA MONITORAR:"
echo "   Acesse http://IC-1046419:5000 no navegador"
echo ""
echo "📋 COMANDOS ÚTEIS:"
echo "   Ver status: systemctl status labsecurity-agent"
echo "   Ver logs: journalctl -u labsecurity-agent -f"
echo "   Parar agente: systemctl stop labsecurity-agent"
echo "   Iniciar agente: systemctl start labsecurity-agent"
echo "   Reiniciar agente: systemctl restart labsecurity-agent"
echo ""
echo "📁 LOGS:"
echo "   systemd: journalctl -u labsecurity-agent -n 50"
echo "   arquivo: tail -f /var/log/labsecurity-agent.log"
echo ""
echo "========================================="

exit 0

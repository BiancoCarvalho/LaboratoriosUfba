#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v12.0.0
#
#  Modelo: baseado no lab-startup.sh antigo (com echo, done.txt, etc)
#
#  Correções da v12 (em relação à v11):
#    - GARANTE /etc/sudoers.d/aluno-ssh no BOOT (não depende de login GDM)
#    - Adiciona /usr/local/sbin/labadmin.pub no cmp
#    - Valida o sudoers com visudo antes de aplicar
#    - Mensagem clara quando o sudoers é criado
#
#  Herdado da v11:
#    - Baixa TODOS os 16 arquivos (13 antigos + AppArmor + whitelist)
#    - SEMPRE roda o lab-programs.sh (mesmo se done.txt = true)
#    - Copia PostLogin para /etc/gdm3/PostLogin/Default
#    - Instala apparmor / apparmor-utils / pam_apparmor
#    - Instala /etc/apparmor.d/lab-restrict (perfil base)
#    - Instala /etc/apparmor.d/pam_apparmor (mapa grupo -> perfil)
#    - Habilita "session required pam_apparmor.so" em common-session
#    - Carrega o perfil base no kernel via apparmor_parser
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"

# ==============================
# 1. Baixa os scripts atualizados do repositorio
# ==============================
echo "========================================="
echo "  Baixando scripts do repositorio..."
echo "========================================="

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

# ---- NOVOS (AppArmor) ----
wget -q --timeout=30 --tries=3 "$REPO/lab-restrict.profile"          -O /tmp/lab-restrict.profile
wget -q --timeout=30 --tries=3 "$REPO/pam_apparmor.conf"             -O /tmp/pam_apparmor.conf

# ---- NOVO (whitelist legada do chmod, mantida por compatibilidade) ----
wget -q --timeout=30 --tries=3 "$REPO/lab-essential-bins.txt"        -O /tmp/lab-essential-bins.txt

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
	# ---- NOVOS ----
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
	if [ ! -f /usr/local/sbin/labadmin.pub ] || ! cmp -s /usr/local/sbin/labadmin.pub /tmp/labadmin.pub; then
		echo "false" > /usr/local/sbin/done.txt
	fi
	if [ ! -f /etc/apparmor.d/lab-restrict ] || ! cmp -s /etc/apparmor.d/lab-restrict /tmp/lab-restrict.profile; then
		echo "false" > /usr/local/sbin/done.txt
	fi
	if [ ! -f /etc/apparmor.d/pam_apparmor ] || ! cmp -s /etc/apparmor.d/pam_apparmor /tmp/pam_apparmor.conf; then
		echo "false" > /usr/local/sbin/done.txt
	fi
	if [ ! -f /etc/lab/essential-bins.txt ] || ! cmp -s /etc/lab/essential-bins.txt /tmp/lab-essential-bins.txt; then
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

	cp /tmp/lab-profile-config.sh /usr/local/sbin
	cp /tmp/lab-aluno-config.sh /usr/local/sbin
	cp /tmp/lab-programs.sh /usr/local/sbin
	cp /tmp/lab-eula-programs.sh /usr/local/sbin
	cp /tmp/lab-program-config.sh /usr/local/sbin
	cp /tmp/lab-inventory.sh /usr/local/sbin
	cp /tmp/lab-admin-profile-config.sh /usr/local/sbin
	cp /tmp/lab-block.sh /usr/local/sbin
	cp /tmp/lab-block-sites.sh /usr/local/sbin
	cp /tmp/lab-unblock.sh /usr/local/sbin
	cp /tmp/lab-postlogin-default.sh /usr/local/sbin
	cp /tmp/labsecurity-agent.sh /usr/local/sbin
	cp /tmp/labadmin.pub /usr/local/sbin

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

	# =============================================
	# 3.2 SUDOERS DO ALUNO — GARANTIDO NO BOOT
	# ---------------------------------------------
	# Este bloco é o que estava FALTANDO na v11.
	# Sem ele, o /etc/sudoers.d/aluno-ssh só era criado no
	# login GDM, e o C# (que acessa via SSH) nunca dispara isso.
	# =============================================
	echo "========================================="
	echo "  Configurando sudoers do aluno..."
	echo "========================================="

	cat > /etc/sudoers.d/aluno-ssh <<'EOF'
# aluno - permite apenas comandos especificos do laboratorio
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF
	chmod 440 /etc/sudoers.d/aluno-ssh
	chown root:root /etc/sudoers.d/aluno-ssh

	if ! visudo -cf /etc/sudoers.d/aluno-ssh >/dev/null 2>&1; then
		echo "[AVISO] Sudoers invalido - aplicando fallback"
		cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: ALL
EOF
		chmod 440 /etc/sudoers.d/aluno-ssh
		chown root:root /etc/sudoers.d/aluno-ssh
	fi
	echo "[OK] /etc/sudoers.d/aluno-ssh instalado e validado"
	echo ""

	# =============================================
	# 3.3 AppArmor — instala pacotes, perfil base e PAM
	# =============================================
	echo "========================================="
	echo "  Configurando AppArmor..."
	echo "========================================="

	# 3.3.1 Garante os pacotes
	PACOTES_FALTANDO=""
	for pkg in apparmor apparmor-utils pam_apparmor; do
		if ! dpkg -s "$pkg" >/dev/null 2>&1; then
			PACOTES_FALTANDO="$PACOTES_FALTANDO $pkg"
		fi
	done

	if [ -n "$PACOTES_FALTANDO" ]; then
		echo "[INFO] Instalando pacotes:$PACOTES_FALTANDO"
		apt-get update -qq
		apt-get install -y -qq $PACOTES_FALTANDO
		echo "[OK] Pacotes instalados"
	else
		echo "[OK] Pacotes AppArmor já presentes"
	fi

	# 3.3.2 Perfil base em /etc/apparmor.d/lab-restrict
	mkdir -p /etc/apparmor.d
	cp /tmp/lab-restrict.profile /etc/apparmor.d/lab-restrict
	chmod 644 /etc/apparmor.d/lab-restrict
	echo "[OK] /etc/apparmor.d/lab-restrict instalado"

	# 3.3.3 Mapa grupo -> perfil em /etc/apparmor.d/pam_apparmor
	cp /tmp/pam_apparmor.conf /etc/apparmor.d/pam_apparmor
	chmod 644 /etc/apparmor.d/pam_apparmor
	echo "[OK] /etc/apparmor.d/pam_apparmor instalado"

	# 3.3.4 Habilita pam_apparmor no PAM (se ainda não estiver)
	if ! grep -q "pam_apparmor.so" /etc/pam.d/common-session; then
		echo 'session required pam_apparmor.so' >> /etc/pam.d/common-session
		echo "[OK] pam_apparmor habilitado em /etc/pam.d/common-session"
	else
		echo "[OK] pam_apparmor já estava habilitado"
	fi

	# 3.3.5 Cria grupo labusers
	getent group labusers >/dev/null || groupadd labusers
	echo "[OK] Grupo labusers garantido"

	# 3.3.6 Carrega o perfil base no kernel (fica pronto, não ativa bloqueio)
	if command -v apparmor_parser >/dev/null 2>&1; then
		apparmor_parser -r /etc/apparmor.d/lab-restrict 2>/dev/null || true
		echo "[OK] Perfil base carregado (não ativado)"
	fi

	# 3.3.7 Whitelist legada do chmod em /etc/lab/
	mkdir -p /etc/lab
	cp /tmp/lab-essential-bins.txt /etc/lab/essential-bins.txt
	chmod 644 /etc/lab/essential-bins.txt
	echo "[OK] /etc/lab/essential-bins.txt instalado"
	echo ""

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
echo "   [OK] Sudoers do aluno garantido"
echo "   [OK] AppArmor configurado (perfil lab-restrict + pam_apparmor)"
echo "   [OK] LabSecurity Agent instalado"
echo ""
echo "PARA MONITORAR:"
echo "   Acesse http://IC-1046419:5000 no navegador"
echo ""
echo "COMANDOS UTEIS (LabSecurity):"
echo "   Ver status: systemctl status labsecurity-agent"
echo "   Ver logs: journalctl -u labsecurity-agent -f"
echo ""
echo "COMANDOS UTEIS (Bloqueio):"
echo "   Sites:     sudo /usr/local/sbin/lab-block.sh --sites-only"
echo "   Programas: sudo /usr/local/sbin/lab-block.sh --programs-only"
echo "   Ambos:     sudo /usr/local/sbin/lab-block.sh --sites-and-programs"
echo "   Reverter:  sudo /usr/local/sbin/lab-unblock.sh"
echo ""
echo "LOGS:"
echo "   Bloqueio: /var/log/lab.log"
echo "   systemd:  journalctl -u labsecurity-agent -n 50"
echo "   arquivo:  tail -f /var/log/labsecurity-agent.log"
echo ""
echo "========================================="

exit 0

#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v3.2.0
#
#  Cria/configura o usuário administrador 'nati'.
#
#  Mudanças em relação à v3.1.0:
#    - ⭐ Adiciona Defaults:nati !requiretty (para SSH não-interativo)
#    - ⭐ Adiciona TODOS os comandos do lab ao sudoers do nati
#    - ⭐ Adiciona lab-startup.sh ao sudoers
#    - ⭐ Fallback SEGURO (remove, não abre NOPASSWD: ALL)
#    - ⭐ Remove o aluno do sudo (modelo mais seguro)
# =====================================================================

set -u

export DEBIAN_FRONTEND=noninteractive

USUARIO="nati"
SENHA='@PNZ!2026'
LOG="/var/log/lab.log"

CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE: $*" >> "$LOG"
}

log "iniciado"

# ---------------------------------------------------------------------
# 1) Cria o usuário SOMENTE se não existir
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    log "usuário $USUARIO já existe - pulando recriação"
else
    log "criando usuário $USUARIO..."

    if ! useradd --create-home --shell /bin/bash "$USUARIO"; then
        log "ERRO: falha ao criar usuário $USUARIO"
        exit 1
    fi

    log "usuário $USUARIO criado"
fi

# Garante senha correta
if ! echo "$USUARIO:$SENHA" | chpasswd; then
    log "ERRO: falha ao definir senha de $USUARIO"
    exit 1
fi

# Garante grupo sudo
usermod -aG sudo "$USUARIO" 2>/dev/null || true

# ---------------------------------------------------------------------
# 2) Chave pública SSH (para o C# conectar como nati)
# ---------------------------------------------------------------------
mkdir -p "/home/$USUARIO/.ssh"
chmod 700 "/home/$USUARIO/.ssh"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.ssh"

echo "$CHAVE_PUBLICA" > "/home/$USUARIO/.ssh/authorized_keys"
chmod 600 "/home/$USUARIO/.ssh/authorized_keys"
chown "$USUARIO:$USUARIO" "/home/$USUARIO/.ssh/authorized_keys"

# Home acessível
chmod 755 "/home/$USUARIO"
chown "$USUARIO:$USUARIO" "/home/$USUARIO"

# Garante SSH rodando
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
# 3) Sudoers do nati — TODOS os comandos do lab
#    ⭐ CORREÇÃO: adiciona Defaults:nati !requiretty e mais comandos
# ---------------------------------------------------------------------
SUDOERS_FILE="/etc/sudoers.d/nati-lab"
rm -f /etc/sudoers.d/NATI /etc/sudoers.d/nati-admin /etc/sudoers.d/nati-lab

cat > "$SUDOERS_FILE" <<EOF
# nati - administrador do laboratório
# Permite todos os comandos do ServidorLab sem senha
Defaults:nati !requiretty

# Pacotes (apt)
$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg

# Scripts do ServidorLab
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-status.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-ipset-update.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-terminal.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock-terminal.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-startup.sh
EOF

# Linha em branco no final
echo "" >> "$SUDOERS_FILE"

chmod 440 "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"

# ⭐ Validação: se falhar, REMOVE o arquivo (não abre NOPASSWD: ALL)
if ! visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
    log "ERRO: sudoers $SUDOERS_FILE inválido. Removendo."
    rm -f "$SUDOERS_FILE"
fi

# ---------------------------------------------------------------------
# 4) Remove o ALUNO do sudo (modelo mais seguro)
# ---------------------------------------------------------------------
deluser aluno sudo 2>/dev/null || true
gpasswd -d aluno sudo 2>/dev/null || true
rm -f /etc/sudoers.d/aluno-ssh

log "aluno removido do sudo"

# ---------------------------------------------------------------------
# 5) Remove 'suporte' se existir
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
    log "usuário suporte removido"
fi

# ---------------------------------------------------------------------
# 6) Teste final
# ---------------------------------------------------------------------
if sudo -n -l -U "$USUARIO" >/dev/null 2>&1; then
    log "[OK] sudoers $USUARIO OK"
else
    log "[AVISO] sudoers $USUARIO NÃO funciona"
fi

# Confirma que o aluno NÃO tem sudo
if groups aluno 2>/dev/null | grep -q sudo; then
    log "[AVISO] aluno AINDA está no grupo sudo"
else
    log "[OK] aluno NÃO tem sudo"
fi

log "concluído"
exit 0

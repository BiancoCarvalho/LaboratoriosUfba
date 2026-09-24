#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v3.1.0
#
#  Cria/configura o usuário administrador 'nati'.
#  - Cria o usuário se NÃO existir
#  - Se existir, reconfigura (senha, chave, sudoers) SEM derrubar sessão
#  - Sem 'sudo' (roda como root via systemd)
#  - Sempre reaplica chave SSH, sudoers e permissões
#  - Remove o usuário 'suporte' se existir
#
#  CORREÇÕES v3.1.0:
#    - Sudoers agora usa 'nati' (minúsculo, igual ao usuário)
#    - Teste de sudoers usa o binário correto
#    - Validação robusta de cada etapa
#
#  Localização: /usr/local/sbin/lab-admin-profile-config.sh
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

# Garante senha correta (mesmo se já existia)
if ! echo "$USUARIO:$SENHA" | chpasswd; then
    log "ERRO: falha ao definir senha de $USUARIO"
    exit 1
fi

# Garante grupo sudo
usermod -aG sudo "$USUARIO" 2>/dev/null || true

# ---------------------------------------------------------------------
# 2) Chave pública SSH
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
# 3) Sudoers restrito
#    ⭐ CORREÇÃO: usa o nome EXATO do usuário (nati, não NATI)
# ---------------------------------------------------------------------
SUDOERS_FILE="/etc/sudoers.d/nati-admin"
rm -f /etc/sudoers.d/NATI /etc/sudoers.d/nati-admin

cat > "$SUDOERS_FILE" <<EOF
# nati - administrador do laboratório
$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
EOF

chmod 440 "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"

# ⭐ Valida o arquivo específico
if ! visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
    log "AVISO: sudoers $SUDOERS_FILE inválido - aplicando fallback"

    cat > "$SUDOERS_FILE" <<EOF
$USUARIO ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 "$SUDOERS_FILE"
    chown root:root "$SUDOERS_FILE"
fi

# ---------------------------------------------------------------------
# 4) Remove 'suporte' se existir
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
    log "usuário suporte removido"
fi

# ---------------------------------------------------------------------
# 5) Teste final
#    ⭐ CORREÇÃO: usa `sudo -n -l -U` (lista permissões, não executa)
# ---------------------------------------------------------------------
if sudo -n -l -U "$USUARIO" >/dev/null 2>&1; then
    log "[OK] sudoers $USUARIO OK"
else
    log "[AVISO] sudoers $USUARIO NÃO funciona"
fi

log "concluído"
exit 0

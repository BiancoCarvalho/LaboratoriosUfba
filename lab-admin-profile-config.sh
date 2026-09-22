#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v3.0.0
#
#  Cria/configura o usuario administrador 'NATI'.
#  - Cria o usuario se NAO existir
#  - Se existir, reconfigura (senha, chave, sudoers) SEM derrubar sessao
#  - Sem 'sudo' (roda como root via systemd)
#  - Sempre reaplica chave SSH, sudoers e permissoes
#  - Remove o usuario 'suporte' se existir
#
#  Localizacao: /usr/local/sbin/lab-admin-profile-config.sh
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

USUARIO="NATI"
SENHA="@PNZ!2026"
LOG="/var/log/lab.log"

# Chave publica do servidor C# (mesma do antigo labadmin.pub)
CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE-CONFIG" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Cria o usuario SO SE NAO EXISTIR
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] usuario $USUARIO ja existe - pulando recriacao" >> "$LOG"
else
    echo "[$(date '+%F %T')] criando usuario $USUARIO..." >> "$LOG"

    useradd --create-home --shell /bin/bash "$USUARIO"
    echo "$USUARIO:$SENHA" | chpasswd
    usermod -aG sudo "$USUARIO"

    echo "[$(date '+%F %T')] usuario $USUARIO criado" >> "$LOG"
fi

# Garante que a senha esta correta (mesmo se o usuario ja existia)
echo "$USUARIO:$SENHA" | chpasswd

# Garante que esta no grupo sudo
usermod -aG sudo "$USUARIO" 2>/dev/null || true

# ---------------------------------------------------------------------
# 2) Chave publica SSH
# ---------------------------------------------------------------------
mkdir -p /home/$USUARIO/.ssh
chmod 700 /home/$USUARIO/.ssh
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh

echo "$CHAVE_PUBLICA" > /home/$USUARIO/.ssh/authorized_keys
chmod 600 /home/$USUARIO/.ssh/authorized_keys
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh/authorized_keys

# Home acessivel
chmod 755 /home/$USUARIO
chown $USUARIO:$USUARIO /home/$USUARIO

# Garante SSH rodando
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
# 3) Sudoers restrito (via /etc/sudoers.d - NAO edita /etc/sudoers)
# ---------------------------------------------------------------------
rm -f /etc/sudoers.d/NATI

cat > /etc/sudoers.d/NATI <<'EOF'
# NATI - administrador do laboratorio
NATI ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
EOF

chmod 440 /etc/sudoers.d/NATI
chown root:root /etc/sudoers.d/NATI

if ! visudo -cf /etc/sudoers.d/NATI >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] [AVISO] sudoers NATI invalido - fallback" >> "$LOG"

    cat > /etc/sudoers.d/NATI <<'EOF'
NATI ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/NATI
    chown root:root /etc/sudoers.d/NATI
fi

# ---------------------------------------------------------------------
# 4) Remove 'suporte' se existir
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
    echo "[$(date '+%F %T')] usuario suporte removido" >> "$LOG"
fi

# ---------------------------------------------------------------------
# 5) Teste final
# ---------------------------------------------------------------------
if sudo -n -u "$USUARIO" true 2>/dev/null; then
    echo "[$(date '+%F %T')] [OK] sudoers $USUARIO OK" >> "$LOG"
else
    echo "[$(date '+%F %T')] [AVISO] sudoers $USUARIO NAO funciona" >> "$LOG"
fi

echo "[$(date '+%F %T')] ADMIN-PROFILE-CONFIG concluido" >> "$LOG"
exit 0

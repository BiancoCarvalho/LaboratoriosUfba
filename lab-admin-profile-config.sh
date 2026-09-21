#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v1.1.0
#
#  Cria/configura o usuário administrador 'NATI'.
#  Inclui chave pública SSH (substitui o antigo labadmin).
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

USUARIO="NATI"
SENHA="@PNZ!2026"
LOG="/var/log/lab.log"

# ⭐ Chave pública do servidor C# (mesma do antigo labadmin.pub)
CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE-CONFIG" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Recria o usuário do zero
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    pkill -9 -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 2
fi

useradd --create-home --shell /bin/bash "$USUARIO"
echo "$USUARIO:$SENHA" | chpasswd
usermod -aG sudo "$USUARIO"

# ---------------------------------------------------------------------
# 2) Chave pública SSH
# ---------------------------------------------------------------------
mkdir -p /home/$USUARIO/.ssh
chmod 700 /home/$USUARIO/.ssh
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh

echo "$CHAVE_PUBLICA" > /home/$USUARIO/.ssh/authorized_keys
chmod 600 /home/$USUARIO/.ssh/authorized_keys
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh/authorized_keys

# Home acessível
chmod 755 /home/$USUARIO
chown $USUARIO:$USUARIO /home/$USUARIO

# Garante SSH rodando
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
# 3) Sudoers restrito
# ---------------------------------------------------------------------
rm -f /etc/sudoers.d/NATI

cat > /etc/sudoers.d/NATI <<'EOF'
# NATI — administrador do laboratório
NATI ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
NATI ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
EOF

chmod 440 /etc/sudoers.d/NATI
chown root:root /etc/sudoers.d/NATI

if ! visudo -cf /etc/sudoers.d/NATI >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ⚠️ sudoers NATI inválido — fallback" >> "$LOG"
    cat > /etc/sudoers.d/NATI <<'EOF'
NATI ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/NATI
    chown root:root /etc/sudoers.d/NATI
fi

# ---------------------------------------------------------------------
# 4) Remove 'suporte'
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
fi

# ---------------------------------------------------------------------
# 5) Teste
# ---------------------------------------------------------------------
if sudo -n -u "$USUARIO" true 2>/dev/null; then
    echo "[$(date '+%F %T')] ✅ sudoers $USUARIO OK" >> "$LOG"
else
    echo "[$(date '+%F %T')] ⚠️ sudoers $USUARIO NÃO funciona" >> "$LOG"
fi

echo "[$(date '+%F %T')] ADMIN-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

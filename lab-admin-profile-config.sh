#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v3.0.0
#
#  Cria o usuário NATI (admin local) e configura SSH + sudoers.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

USUARIO="NATI"
SENHA="@PNZ!2026"
LOG="/var/log/lab.log"
CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE-CONFIG" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Cria/recria o usuário NATI
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    echo "O usuário $USUARIO já existe. Removendo..."
    sudo pkill -9 -u "$USUARIO" 2>/dev/null || true
    sudo userdel -r "$USUARIO" 2>/dev/null || true
    sleep 2
fi

echo "Criando usuário $USUARIO..."
sudo useradd --create-home --shell /bin/bash "$USUARIO"
echo "$USUARIO:$SENHA" | sudo chpasswd
sudo usermod -aG sudo "$USUARIO"

# ---------------------------------------------------------------------
# 2) Configura .ssh + chave (para SSH do servidor C#)
# ---------------------------------------------------------------------
mkdir -p /home/$USUARIO/.ssh
chmod 700 /home/$USUARIO/.ssh
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh

echo "$CHAVE" > /home/$USUARIO/.ssh/authorized_keys
chmod 600 /home/$USUARIO/.ssh/authorized_keys
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh/authorized_keys

# ---------------------------------------------------------------------
# 3) Garante o SSH rodando
# ---------------------------------------------------------------------
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
# 4) Sudoers restrito
# ---------------------------------------------------------------------
grep -q "$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/dpkg" /etc/sudoers || \
    echo "$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/dpkg" | sudo tee -a /etc/sudoers

grep -q "$USUARIO ALL=(ALL) !/usr/sbin/useradd, !/usr/sbin/userdel" /etc/sudoers || \
    echo "$USUARIO ALL=(ALL) !/usr/sbin/useradd, !/usr/sbin/userdel" | sudo tee -a /etc/sudoers

# Adiciona os scripts do modo prova
cat > /etc/sudoers.d/${USUARIO}-ssh <<EOF
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF
chmod 440 /etc/sudoers.d/${USUARIO}-ssh

if ! visudo -c >/dev/null 2>&1; then
    rm -f /etc/sudoers.d/${USUARIO}-ssh
fi

# ---------------------------------------------------------------------
# 5) Remove usuário suporte (se existir)
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    sudo userdel -r suporte
    echo "Usuário suporte removido."
fi

echo "[$(date '+%F %T')] ADMIN-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

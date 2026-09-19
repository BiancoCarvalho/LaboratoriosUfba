#!/bin/bash
# Lab Labadmin Profile Config
# v1.1.0
# Cria o usuário 'labadmin' (SSH do servidor C#) e configura a chave

export DEBIAN_FRONTEND=noninteractive

USUARIO="labadmin"
SENHA="${LABADMIN_PASSWORD:-$(openssl rand -base64 16)}"
LOG="/var/log/lab.log"
CHAVE_PUBLICA=""

if [ -f /usr/local/sbin/labadmin.pub ]; then
    CHAVE_PUBLICA=$(cat /usr/local/sbin/labadmin.pub)
fi

echo "[$(date '+%F %T')] host=$(hostname) LABADMIN-CONFIG" >> "$LOG"

# Cria/recria
if id "$USUARIO" &>/dev/null; then
    pkill -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

useradd --create-home --shell /bin/bash --comment "SSH do servidor C#" "$USUARIO"
echo "$USUARIO:$SENHA" | chpasswd

deluser "$USUARIO" sudo 2>/dev/null || true
deluser "$USUARIO" adm  2>/dev/null || true

# Chave SSH
mkdir -p /home/$USUARIO/.ssh
chmod 700 /home/$USUARIO/.ssh
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh
touch /home/$USUARIO/.ssh/authorized_keys

if [ -n "$CHAVE_PUBLICA" ]; then
    if ! grep -qF "$CHAVE_PUBLICA" /home/$USUARIO/.ssh/authorized_keys 2>/dev/null; then
        echo "$CHAVE_PUBLICA" >> /home/$USUARIO/.ssh/authorized_keys
    fi
fi

chmod 600 /home/$USUARIO/.ssh/authorized_keys
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh/authorized_keys

# Sudoers: só os scripts do modo prova
tee /etc/sudoers.d/labadmin > /dev/null <<EOF
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-profile-config.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-config.sh
EOF

chmod 440 /etc/sudoers.d/labadmin

if ! visudo -c >/dev/null 2>&1; then
    rm -f /etc/sudoers.d/labadmin
    exit 1
fi

echo "[$(date '+%F %T')] LABADMIN-CONFIG concluído" >> "$LOG"
exit 0

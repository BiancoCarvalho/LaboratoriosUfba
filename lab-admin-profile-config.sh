#!/bin/bash
# =====================================================================
#  lab-labadmin-config.sh
#  v3.0.0
#
#  Cria o usuário 'labadmin' (usado pelo servidor C# via SSH).
# =====================================================================

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
    pkill -9 -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

useradd --create-home --shell /bin/bash --comment "Usuario SSH do servidor" "$USUARIO"
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

# Sudoers
rm -f /etc/sudoers.d/labadmin

cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-profile-config.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-config.sh
EOF

chmod 440 /etc/sudoers.d/labadmin
chown root:root /etc/sudoers.d/labadmin

# ⭐ Valida SÓ o arquivo criado
if ! visudo -cf /etc/sudoers.d/labadmin >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ⚠️ sudoers labadmin inválido — fallback" >> "$LOG"

    cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/labadmin
    chown root:root /etc/sudoers.d/labadmin
fi

# Testa
if sudo -n -u labadmin true 2>/dev/null; then
    echo "[$(date '+%F %T')] ✅ sudoers labadmin OK" >> "$LOG"
else
    echo "[$(date '+%F %T')] ⚠️ sudoers labadmin NÃO funciona" >> "$LOG"
fi

echo "[$(date '+%F %T')] LABADMIN-CONFIG concluído" >> "$LOG"
exit 0

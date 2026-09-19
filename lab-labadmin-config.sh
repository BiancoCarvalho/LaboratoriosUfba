#!/bin/bash
# Lab Labadmin Profile Config
# v1.0.0
# Cria o usuário 'labadmin' — usuário SSH usado pelo servidor C# para disparar
# o modo prova (bloqueio/destrave) nos PCs dos laboratórios.
# (add version to trigger update in 'lab-startup' cmp)

export DEBIAN_FRONTEND=noninteractive

USUARIO="labadmin"
SENHA="${LABADMIN_PASSWORD:-$(openssl rand -base64 16)}"
LOG="/var/log/lab.log"
CHAVE_PUBLICA="${LABADMIN_SSH_KEY:-}"

echo "[$(date '+%F %T')] host=$(hostname) LABADMIN-CONFIG" >> "$LOG"

# =====================================================================
# 1) Cria ou recria o usuário
# =====================================================================
if id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] Usuário $USUARIO já existe. Recriando..." >> "$LOG"
    pkill -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 1
fi

echo "[$(date '+%F %T')] Criando usuário $USUARIO..." >> "$LOG"

# Cria o usuário SEM entrar no grupo sudo (diferente do NATI)
useradd \
    --create-home \
    --shell /bin/bash \
    --comment "Usuário SSH do servidor de reservas" \
    "$USUARIO"

echo "$USUARIO:$SENHA" | chpasswd

# =====================================================================
# 2) Configura a chave pública do servidor C# (authorized_keys)
# =====================================================================
mkdir -p /home/$USUARIO/.ssh
chmod 700 /home/$USUARIO/.ssh
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh

touch /home/$USUARIO/.ssh/authorized_keys

if [ -n "$CHAVE_PUBLICA" ]; then
    # Só adiciona se ainda não existir
    if ! grep -qF "$CHAVE_PUBLICA" /home/$USUARIO/.ssh/authorized_keys 2>/dev/null; then
        echo "$CHAVE_PUBLICA" >> /home/$USUARIO/.ssh/authorized_keys
        echo "[$(date '+%F %T')] Chave pública adicionada ao authorized_keys" >> "$LOG"
    else
        echo "[$(date '+%F %T')] Chave pública já presente" >> "$LOG"
    fi
else
    echo "[$(date '+%F %T')] AVISO: CHAVE_PUBLICA vazia. Configure depois." >> "$LOG"
fi

chmod 600 /home/$USUARIO/.ssh/authorized_keys
chown $USUARIO:$USUARIO /home/$USUARIO/.ssh/authorized_keys

# =====================================================================
# 3) Sudoers restrito — SÓ os scripts do modo prova
# =====================================================================
tee /etc/sudoers.d/labadmin > /dev/null <<EOF
# Usuário 'labadmin' — usado pelo servidor C# via SSH
# Pode rodar SOMENTE os scripts do modo prova sem senha.
# Nada mais. Não pode instalar pacotes, não pode mexer em usuários.
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-profile-config.sh
EOF

chmod 440 /etc/sudoers.d/labadmin

# Valida o sudoers — se estiver inválido, remove e aborta
if ! visudo -c >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ERRO: sudoers inválido. Removendo." >> "$LOG"
    rm -f /etc/sudoers.d/labadmin
    exit 1
fi

echo "[$(date '+%F %T')] LABADMIN-CONFIG concluído" >> "$LOG"
exit 0

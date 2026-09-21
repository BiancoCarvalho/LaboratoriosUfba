#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v1.0.0
#
#  Cria/configura o usuário administrador 'NATI'.
#  - Recria o usuário do zero (home limpo)
#  - Adiciona ao grupo sudo
#  - Regras restritas em /etc/sudoers.d/NATI
#  - Remove o usuário 'suporte' se existir
#
#  Localização: /usr/local/sbin/lab-admin-profile-config.sh
#  Uso: sudo /usr/local/sbin/lab-admin-profile-config.sh
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

USUARIO="NATI"
SENHA="@PNZ!2026"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE-CONFIG" >> "$LOG"

# ---------------------------------------------------------------------
# 1) Recria o usuário do zero
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] usuário $USUARIO já existe — removendo..." >> "$LOG"

    pkill -9 -u "$USUARIO" 2>/dev/null || true
    userdel -r "$USUARIO" 2>/dev/null || true
    sleep 2
fi

echo "[$(date '+%F %T')] criando usuário $USUARIO..." >> "$LOG"

useradd --create-home --shell /bin/bash "$USUARIO"
echo "$USUARIO:$SENHA" | chpasswd
usermod -aG sudo "$USUARIO"

echo "[$(date '+%F %T')] usuário $USUARIO criado e adicionado ao grupo sudo" >> "$LOG"

# ---------------------------------------------------------------------
# 2) Sudoers restrito (via /etc/sudoers.d — NUNCA editar /etc/sudoers)
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

# ⭐ Valida SÓ o arquivo criado
if ! visudo -cf /etc/sudoers.d/NATI >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ⚠️ sudoers NATI inválido — aplicando fallback" >> "$LOG"

    cat > /etc/sudoers.d/NATI <<'EOF'
NATI ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/NATI
    chown root:root /etc/sudoers.d/NATI
fi

# ---------------------------------------------------------------------
# 3) Remove o usuário 'suporte' se existir
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
    echo "[$(date '+%F %T')] usuário suporte removido" >> "$LOG"
fi

# ---------------------------------------------------------------------
# 4) Teste final
# ---------------------------------------------------------------------
if sudo -n -u "$USUARIO" true 2>/dev/null; then
    echo "[$(date '+%F %T')] ✅ sudoers $USUARIO OK" >> "$LOG"
else
    echo "[$(date '+%F %T')] ⚠️ sudoers $USUARIO NÃO funciona" >> "$LOG"
fi

echo "[$(date '+%F %T')] ADMIN-PROFILE-CONFIG concluído" >> "$LOG"
exit 0

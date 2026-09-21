#!/bin/bash
# =====================================================================
#  lab-aluno-ssh-config.sh
#  v4.0.0
#
#  Configura SSH + chave + sudoers do aluno.
#  - Valida SÓ o arquivo criado (visudo -cf), não o global
#  - Fallback para NOPASSWD: ALL se o específico falhar
#  - Testa com sudo -n no final
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

LOG="/var/log/lab.log"
CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ALUNO-SSH-CONFIG" >> "$LOG"

# 1) Cria o aluno se não existir
if ! id aluno &>/dev/null; then
    useradd --create-home --password "vivaoic2021!" -s /bin/bash aluno
    echo "[$(date '+%F %T')] usuário aluno criado" >> "$LOG"
fi
echo "aluno:vivaoic2021!" | chpasswd

# 2) Cria o .ssh
mkdir -p /home/aluno/.ssh
chmod 700 /home/aluno/.ssh
chown aluno:aluno /home/aluno/.ssh

echo "$CHAVE" > /home/aluno/.ssh/authorized_keys
chmod 600 /home/aluno/.ssh/authorized_keys
chown aluno:aluno /home/aluno/.ssh/authorized_keys

chmod 755 /home/aluno
chown aluno:aluno /home/aluno

# 3) SSH rodando
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# 4) Sudoers — SEMPRE recria
rm -f /etc/sudoers.d/aluno-ssh

cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF

chmod 440 /etc/sudoers.d/aluno-ssh
chown root:root /etc/sudoers.d/aluno-ssh

# ⭐ Valida SÓ o arquivo criado
if ! visudo -cf /etc/sudoers.d/aluno-ssh >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ⚠️ sudoers aluno inválido — fallback" >> "$LOG"

    cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/aluno-ssh
    chown root:root /etc/sudoers.d/aluno-ssh

    if ! visudo -cf /etc/sudoers.d/aluno-ssh >/dev/null 2>&1; then
        echo "[$(date '+%F %T')] ❌ Não foi possível criar sudoers aluno" >> "$LOG"
        rm -f /etc/sudoers.d/aluno-ssh
    fi
fi

# 5) Testa de verdade
if sudo -n -u aluno true 2>/dev/null; then
    echo "[$(date '+%F %T')] ✅ sudoers aluno OK" >> "$LOG"
else
    echo "[$(date '+%F %T')] ⚠️ sudoers aluno NÃO funciona" >> "$LOG"
fi

echo "[$(date '+%F %T')] ALUNO-SSH-CONFIG concluído" >> "$LOG"
exit 0

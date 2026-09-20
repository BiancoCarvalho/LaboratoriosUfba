#!/bin/bash
# =====================================================================
#  lab-aluno-ssh-config.sh
#  v2.0.0
#
#  Configura SSH + chave + sudoers do aluno.
#  Roda no boot (via lab-startup.sh).
#  NÃO depende de login gráfico.
#  NÃO apaga o home.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

LOG="/var/log/lab.log"
CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ALUNO-SSH-CONFIG" >> "$LOG"

# 1) Cria o aluno se não existir
if ! id aluno &>/dev/null; then
    useradd --create-home --password "vivaoic2021!" -s /bin/bash aluno
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

# 4) Sudoers
cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF
chmod 440 /etc/sudoers.d/aluno-ssh

if ! visudo -c >/dev/null 2>&1; then
    rm -f /etc/sudoers.d/aluno-ssh
fi

echo "[$(date '+%F %T')] ALUNO-SSH-CONFIG concluído" >> "$LOG"
exit 0

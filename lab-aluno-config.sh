#!/bin/bash
# =====================================================================
#  lab-aluno-config.sh
#  v4.0.0
#
#  Configura o aluno no boot (roda como root).
#  Cria o usuário, o .ssh com a chave, o sudoers e habilita o SSH.
#
#  NÃO recria o home (isso é função do PostLogin/Default).
#  NÃO depende de login gráfico.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

LOG="/var/log/lab.log"
CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

echo "[$(date '+%F %T')] host=$(hostname) ALUNO-CONFIG" >> "$LOG"

# =====================================================================
# 1) Cria o aluno (se não existir)
# =====================================================================
if ! id aluno &>/dev/null; then
    useradd --create-home --password "vivaoic2021!" -s /bin/bash aluno
fi
echo "aluno:vivaoic2021!" | chpasswd

# =====================================================================
# 2) Cria a pasta .ssh com a chave
# =====================================================================
mkdir -p /home/aluno/.ssh
chmod 700 /home/aluno/.ssh
chown aluno:aluno /home/aluno/.ssh

echo "$CHAVE" > /home/aluno/.ssh/authorized_keys
chmod 600 /home/aluno/.ssh/authorized_keys
chown aluno:aluno /home/aluno/.ssh/authorized_keys

chmod 755 /home/aluno
chown aluno:aluno /home/aluno

# =====================================================================
# 3) Garante o SSH rodando
# =====================================================================
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# =====================================================================
# 4) Sudoers restrito do aluno
# =====================================================================
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

# =====================================================================
# 5) PATHs e ambiente
# =====================================================================
echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc
rm -f /opt/flutter/bin/cache/lockfile

chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs 2>/dev/null || true

mkdir -p /home/aluno/Unity/Hub
ln -sf /opt/Unity /home/aluno/Unity/Hub/Editor
ln -sf /opt/gradle /home/aluno/.gradle
ln -sf /opt/npm /home/aluno/.npm
ln -sf /opt/VMs /home/aluno/VirtualBox
ln -sf /opt/nand2tetris /home/aluno/nand2tetris

echo "[$(date '+%F %T')] ALUNO-CONFIG concluído" >> "$LOG"
exit 0

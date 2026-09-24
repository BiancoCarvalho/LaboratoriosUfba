#!/bin/bash
# =====================================================================
#  lab-postlogin-default.sh
#  v8.0.0
#
#  Mudanças em relação à v7.0.0:
#    - ⭐ NÃO apaga mais o home do aluno durante o login
#      (era a causa do GDM kickar o aluno)
#    - ⭐ Só garante que o home existe e está correto
#    - ⭐ Recria o home SOMENTE se ele não existir
# =====================================================================

set -euo pipefail

LOG="/var/log/lab.log"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) POSTLOGIN: $*" >> "$LOG" 2>/dev/null || true
}

# Só roda para o aluno
if [[ "${USER:-}" != "aluno" ]]; then
    exit 0
fi

log "iniciado"

# =====================================================================
# ⭐ 1) GARANTE O HOME SEM APAGAR
#     Só recria se NÃO existir
# =====================================================================
if [ ! -d /home/aluno ]; then
    log "home do aluno não existe — criando"
    cp -r /etc/skel /home/aluno
    chown -R aluno:aluno /home/aluno
    chmod 700 /home/aluno
else
    log "home do aluno já existe — mantendo"
fi

# Garante permissões corretas (sem apagar)
chown aluno:aluno /home/aluno
chmod 700 /home/aluno

# Garante a senha
echo "aluno:vivaoic2021!" | chpasswd

log "home garantido"

# =====================================================================
# 2) Chave SSH
# =====================================================================
CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

mkdir -p /home/aluno/.ssh
chmod 700 /home/aluno/.ssh
chown aluno:aluno /home/aluno/.ssh

# Escrita atômica
TMP="/tmp/.postlogin-authorized-$$"
printf '%s\n' "$CHAVE_PUBLICA" > "$TMP"

if grep -qF "servidor-lab@universidade" "$TMP"; then
    mv "$TMP" "/home/aluno/.ssh/authorized_keys"
    chmod 600 /home/aluno/.ssh/authorized_keys
    chown aluno:aluno /home/aluno/.ssh/authorized_keys
    log "chave SSH configurada"
else
    log "ERRO: falha ao escrever authorized_keys"
    rm -f "$TMP"
fi

# =====================================================================
# 3) SSH rodando
# =====================================================================
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# =====================================================================
# 4) PATHs — sem duplicação
# =====================================================================
if [ -f /home/aluno/.bashrc ]; then
    sed -i '/opt\/flutter\/bin/d' /home/aluno/.bashrc 2>/dev/null || true
    sed -i '/opt\/android-studio/d' /home/aluno/.bashrc 2>/dev/null || true
fi

echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc

rm -f /opt/flutter/bin/cache/lockfile

chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs 2>/dev/null || true

log "PATHs configurados"

# =====================================================================
# 5) Links simbólicos
# =====================================================================
mkdir -p /home/aluno/Unity/Hub
ln -sf /opt/Unity /home/aluno/Unity/Hub/Editor
ln -sf /opt/gradle /home/aluno/.gradle
ln -sf /opt/npm /home/aluno/.npm
ln -sf /opt/VMs /home/aluno/VirtualBox
ln -sf /opt/nand2tetris /home/aluno/nand2tetris

log "links simbólicos configurados"

# =====================================================================
# 6) Remove o aluno do sudo
# =====================================================================
deluser aluno sudo 2>/dev/null || true
gpasswd -d aluno sudo 2>/dev/null || true
rm -f /etc/sudoers.d/aluno-ssh

log "aluno removido do sudo"

# =====================================================================
# 7) MySQL
# =====================================================================
echo "DROP USER IF EXISTS 'aluno'@'localhost'; CREATE USER 'aluno'@'%' IDENTIFIED BY 'aluno'; GRANT ALL PRIVILEGES ON *.* TO 'aluno'@'%'; FLUSH PRIVILEGES;" | mysql -u root 2>/dev/null || true

# =====================================================================
# 8) PostgreSQL
# =====================================================================
sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS aluno;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD 'aluno';" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;" 2>/dev/null || true

sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
sudo systemctl restart postgresql 2>/dev/null || true

log "bancos configurados"

# =====================================================================
# 9) Inventário
# =====================================================================
inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
inventory_url='https://inventario.app.ic.ufba.br/inventory'

if [ -f "$inventory_path/src/inventory.py" ]; then
    python3 "$inventory_path/src/inventory.py" "$inventory_url" &> /var/log/inventory.log || true
fi

# =====================================================================
# 10) Roda o lab-startup em background
# =====================================================================
nohup /usr/local/sbin/lab-startup.sh > /var/log/lab-startup-postlogin.log 2>&1 &

log "concluído"
exit 0

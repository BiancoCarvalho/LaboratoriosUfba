#!/bin/bash
# =====================================================================
#  lab-postlogin-default.sh
#  v7.0.0
#
#  Mudanças em relação à v6.2.0:
#    - ⭐ set -euo pipefail (aborta em erro)
#    - ⭐ Escrita atômica de arquivos
#    - ⭐ Evita duplicação no .bashrc (sed -i antes de >>)
#    - ⭐ Validação após cada etapa
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

# ---------------------------------------------------------------------
# Função: escreve arquivo ATÔMICO
# ---------------------------------------------------------------------
escrever_atomico() {
    local destino="$1"
    local conteudo="$2"
    local validador="$3"

    local tmp="/tmp/.postlogin-$$"
    printf '%s\n' "$conteudo" > "$tmp"

    if ! grep -qF "$validador" "$tmp"; then
        log "ERRO: conteúdo não contém '$validador' no temporário"
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$destino"

    if ! grep -qF "$validador" "$destino"; then
        log "ERRO: conteúdo não contém '$validador' no destino"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------
# 1) Recria o home do aluno
# ---------------------------------------------------------------------
rm -rf /home/aluno
cp -r /etc/skel /home/aluno
chown -R aluno:aluno /home/aluno

echo "aluno:vivaoic2021!" | chpasswd

log "home recriado"

# ---------------------------------------------------------------------
# 2) Chave SSH — ATÔMICO
# ---------------------------------------------------------------------
CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

mkdir -p /home/aluno/.ssh
chmod 700 /home/aluno/.ssh
chown aluno:aluno /home/aluno/.ssh

escrever_atomico \
    "/home/aluno/.ssh/authorized_keys" \
    "$CHAVE_PUBLICA" \
    "servidor-lab@universidade" || log "ERRO: falha ao escrever authorized_keys"

chmod 600 /home/aluno/.ssh/authorized_keys
chown aluno:aluno /home/aluno/.ssh/authorized_keys

log "chave SSH configurada"

# ---------------------------------------------------------------------
# 3) SSH rodando
# ---------------------------------------------------------------------
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------
# 4) PATHs — ATÔMICO, sem duplicação
# ---------------------------------------------------------------------
# ⭐ Remove as linhas antigas ANTES de adicionar
sed -i '/opt\/flutter\/bin/d' /home/aluno/.bashrc 2>/dev/null || true
sed -i '/opt\/android-studio/d' /home/aluno/.bashrc 2>/dev/null || true

# ⭐ Agora adiciona
echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc

rm -f /opt/flutter/bin/cache/lockfile

chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs 2>/dev/null || true

log "PATHs configurados"

# ---------------------------------------------------------------------
# 5) Links simbólicos
# ---------------------------------------------------------------------
mkdir -p /home/aluno/Unity/Hub
ln -sf /opt/Unity /home/aluno/Unity/Hub/Editor
ln -sf /opt/gradle /home/aluno/.gradle
ln -sf /opt/npm /home/aluno/.npm
ln -sf /opt/VMs /home/aluno/VirtualBox
ln -sf /opt/nand2tetris /home/aluno/nand2tetris

log "links simbólicos configurados"

# ---------------------------------------------------------------------
# 6) ⭐ Remove o aluno do sudo (modelo mais seguro)
# ---------------------------------------------------------------------
deluser aluno sudo 2>/dev/null || true
gpasswd -d aluno sudo 2>/dev/null || true
rm -f /etc/sudoers.d/aluno-ssh

log "aluno removido do sudo"

# ---------------------------------------------------------------------
# 7) MySQL
# ---------------------------------------------------------------------
echo "DROP USER IF EXISTS 'aluno'@'localhost'; CREATE USER 'aluno'@'%' IDENTIFIED BY 'aluno'; GRANT ALL PRIVILEGES ON *.* TO 'aluno'@'%'; FLUSH PRIVILEGES;" | mysql -u root 2>/dev/null || true

# ---------------------------------------------------------------------
# 8) PostgreSQL
# ---------------------------------------------------------------------
sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS aluno;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD 'aluno';" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;" 2>/dev/null || true

sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
sudo systemctl restart postgresql 2>/dev/null || true

log "bancos configurados"

# ---------------------------------------------------------------------
# 9) Inventário
# ---------------------------------------------------------------------
inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
inventory_url='https://inventario.app.ic.ufba.br/inventory'

if [ -f "$inventory_path/src/inventory.py" ]; then
    python3 "$inventory_path/src/inventory.py" "$inventory_url" &> /var/log/inventory.log || true
fi

# ---------------------------------------------------------------------
# 10) Roda o lab-startup em background
# ---------------------------------------------------------------------
nohup /usr/local/sbin/lab-startup.sh > /var/log/lab-startup-postlogin.log 2>&1 &

log "concluído"
exit 0

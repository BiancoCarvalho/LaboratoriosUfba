#!/bin/bash
# =====================================================================
#  lab-postlogin-default.sh
#  v8.1.0
#
#  Mudanças em relação à v8.0.0:
#    - ⭐ REMOVIDO `set -euo pipefail` (abortava o login)
#    - ⭐ Adicionado `set +e` explícito (NÃO aborta)
#    - ⭐ Comandos pesados movidos para BACKGROUND
#    - ⭐ Timeout de 5s em cada comando crítico
#    - ⭐ Log de tudo (para diagnóstico)
#    - ⭐ NÃO apaga o home (como já era)
# =====================================================================

set +e    # ⭐ NÃO aborta em erro
set +u    # ⭐ NÃO aborta em variável não definida
set +o pipefail

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
# ⭐ TUDO em BACKGROUND — o login do aluno NÃO espera
# =====================================================================
(
    # ⭐ Timeout global: se demorar mais que 120s, mata
    timeout 120 bash -c '
        LOG="/var/log/lab.log"
        log() { echo "[$(date "+%F %T")] host=$(hostname) POSTLOGIN-BG: $*" >> "$LOG" 2>/dev/null || true; }

        log "background iniciado"

        # -------------------------------------------------------------
        # 1) Home do aluno (SEM apagar)
        # -------------------------------------------------------------
        if [ ! -d /home/aluno ]; then
            log "home do aluno não existe — criando"
            cp -r /etc/skel /home/aluno 2>/dev/null
            chown -R aluno:aluno /home/aluno 2>/dev/null
            chmod 700 /home/aluno 2>/dev/null
        fi

        chown aluno:aluno /home/aluno 2>/dev/null
        chmod 700 /home/aluno 2>/dev/null

        # Garante a senha (com timeout)
        echo "aluno:vivaoic2021!" | timeout 5 chpasswd 2>/dev/null || true

        log "home garantido"

        # -------------------------------------------------------------
        # 2) Chave SSH
        # -------------------------------------------------------------
        CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

        mkdir -p /home/aluno/.ssh 2>/dev/null
        chmod 700 /home/aluno/.ssh 2>/dev/null
        chown aluno:aluno /home/aluno/.ssh 2>/dev/null

        TMP="/tmp/.postlogin-authorized-$$"
        printf "%s\n" "$CHAVE_PUBLICA" > "$TMP"

        if grep -qF "servidor-lab@universidade" "$TMP"; then
            mv "$TMP" "/home/aluno/.ssh/authorized_keys"
            chmod 600 /home/aluno/.ssh/authorized_keys
            chown aluno:aluno /home/aluno/.ssh/authorized_keys
            log "chave SSH configurada"
        else
            log "ERRO: falha ao escrever authorized_keys"
            rm -f "$TMP"
        fi

        # -------------------------------------------------------------
        # 3) SSH rodando
        # -------------------------------------------------------------
        systemctl enable ssh >/dev/null 2>&1 || true
        systemctl start ssh  >/dev/null 2>&1 || true

        # -------------------------------------------------------------
        # 4) PATHs (sem duplicação)
        # -------------------------------------------------------------
        if [ -f /home/aluno/.bashrc ]; then
            sed -i "/opt\/flutter\/bin/d" /home/aluno/.bashrc 2>/dev/null || true
            sed -i "/opt\/android-studio/d" /home/aluno/.bashrc 2>/dev/null || true
        fi

        echo "export PATH=\"/opt/flutter/bin:\$PATH\"" >> /home/aluno/.bashrc 2>/dev/null
        echo "export PATH=\"/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:\$PATH\"" >> /home/aluno/.bashrc 2>/dev/null

        rm -f /opt/flutter/bin/cache/lockfile 2>/dev/null

        # chown -R pode demorar — coloca em background e NÃO espera
        (
            chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs 2>/dev/null || true
        ) &
        disown

        log "PATHs configurados"

        # -------------------------------------------------------------
        # 5) Links simbólicos
        # -------------------------------------------------------------
        mkdir -p /home/aluno/Unity/Hub 2>/dev/null
        ln -sf /opt/Unity /home/aluno/Unity/Hub/Editor 2>/dev/null
        ln -sf /opt/gradle /home/aluno/.gradle 2>/dev/null
        ln -sf /opt/npm /home/aluno/.npm 2>/dev/null
        ln -sf /opt/VMs /home/aluno/VirtualBox 2>/dev/null
        ln -sf /opt/nand2tetris /home/aluno/nand2tetris 2>/dev/null

        log "links simbólicos configurados"

        # -------------------------------------------------------------
        # 6) Remove o aluno do sudo
        # -------------------------------------------------------------
        deluser aluno sudo 2>/dev/null || true
        gpasswd -d aluno sudo 2>/dev/null || true
        rm -f /etc/sudoers.d/aluno-ssh 2>/dev/null

        log "aluno removido do sudo"

        # -------------------------------------------------------------
        # 7) MySQL (com timeout)
        # -------------------------------------------------------------
        echo "DROP USER IF EXISTS \x27aluno\x27@\x27localhost\x27; CREATE USER \x27aluno\x27@\x27%\x27 IDENTIFIED BY \x27aluno\x27; GRANT ALL PRIVILEGES ON *.* TO \x27aluno\x27@\x27%\x27; FLUSH PRIVILEGES;" | timeout 10 mysql -u root 2>/dev/null || true

        # -------------------------------------------------------------
        # 8) PostgreSQL (com timeout)
        # -------------------------------------------------------------
        timeout 5 sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;" 2>/dev/null || true
        timeout 5 sudo -u postgres psql -c "DROP USER IF EXISTS aluno;" 2>/dev/null || true
        timeout 5 sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD \x27aluno\x27;" 2>/dev/null || true
        timeout 5 sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;" 2>/dev/null || true
        timeout 5 sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;" 2>/dev/null || true

        timeout 5 sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
        timeout 5 sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
        timeout 5 sudo systemctl restart postgresql 2>/dev/null || true

        log "bancos configurados"

        # -------------------------------------------------------------
        # 9) Inventário (com timeout)
        # -------------------------------------------------------------
        inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
        inventory_url="https://inventario.app.ic.ufba.br/inventory"

        if [ -f "$inventory_path/src/inventory.py" ]; then
            timeout 30 python3 "$inventory_path/src/inventory.py" "$inventory_url" &> /var/log/inventory.log || true
        fi

        # -------------------------------------------------------------
        # 10) Roda o lab-startup em background
        # -------------------------------------------------------------
        nohup /usr/local/sbin/lab-startup.sh > /var/log/lab-startup-postlogin.log 2>&1 &

        log "concluído"
    ' >> "$LOG" 2>&1
) &

# ⭐ O script principal SAI IMEDIATAMENTE
# O GDM não espera o background
exit 0

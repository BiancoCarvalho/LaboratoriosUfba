#!/bin/bash
# =====================================================================
#  lab-postlogin-default.sh
#  v5.0.0
#
#  Copiado para /etc/gdm3/PostLogin/Default pelo lab-startup.sh
#  Roda A CADA LOGIN do aluno.
#  - Recria o home do aluno
#  - Configura chave SSH
#  - Sudoers restrito
#  - MySQL / PostgreSQL
#  - PATHs e links simbólicos
# =====================================================================

if [[ "$USER" == "aluno" ]]; then
    rm -rf /home/$USER
    cp -r /etc/skel /home/$USER
    chown -R $USER:$USER /home/$USER
    echo "aluno:vivaoic2021!" | chpasswd

    # -----------------------------------------------------------------
    # Chave publica SSH (mesma do labadmin.pub)
    # -----------------------------------------------------------------
    CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

    mkdir -p /home/$USER/.ssh
    chmod 700 /home/$USER/.ssh
    chown $USER:$USER /home/$USER/.ssh

    echo "$CHAVE_PUBLICA" > /home/$USER/.ssh/authorized_keys
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown $USER:$USER /home/$USER/.ssh/authorized_keys

    # Garante SSH rodando
    systemctl enable ssh >/dev/null 2>&1 || true
    systemctl start ssh  >/dev/null 2>&1 || true

    # -----------------------------------------------------------------
    # PATHs
    # -----------------------------------------------------------------
    echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
    echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc
    rm -f /opt/flutter/bin/cache/lockfile

    chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs

    # -----------------------------------------------------------------
    # Links simbólicos
    # -----------------------------------------------------------------
    mkdir -p /home/$USER/Unity/Hub
    ln -sf /opt/Unity /home/$USER/Unity/Hub/Editor

    ln -sf /opt/gradle /home/$USER/.gradle
    ln -sf /opt/npm /home/$USER/.npm
    ln -sf /opt/VMs /home/$USER/VirtualBox
    ln -sf /opt/nand2tetris /home/$USER/nand2tetris

    # -----------------------------------------------------------------
    # Sudoers restrito (via /etc/sudoers.d)
    # -----------------------------------------------------------------
    rm -f /etc/sudoers.d/aluno-ssh

    cat > /etc/sudoers.d/aluno-ssh <<'EOF'
# aluno - permite apenas comandos especificos
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF

    chmod 440 /etc/sudoers.d/aluno-ssh
    chown root:root /etc/sudoers.d/aluno-ssh

    if ! visudo -cf /etc/sudoers.d/aluno-ssh >/dev/null 2>&1; then
        cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: ALL
EOF
        chmod 440 /etc/sudoers.d/aluno-ssh
        chown root:root /etc/sudoers.d/aluno-ssh
    fi

    # -----------------------------------------------------------------
    # MySQL
    # -----------------------------------------------------------------
    echo "DROP USER IF EXISTS 'aluno'@'localhost'; CREATE USER 'aluno'@'%' IDENTIFIED BY 'aluno'; GRANT ALL PRIVILEGES ON *.* TO 'aluno'@'%'; FLUSH PRIVILEGES;" | mysql -u root 2>/dev/null || true

    # -----------------------------------------------------------------
    # PostgreSQL
    # -----------------------------------------------------------------
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS aluno;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD 'aluno';" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;" 2>/dev/null || true

    sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
    sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
    sudo systemctl restart postgresql 2>/dev/null || true

    # -----------------------------------------------------------------
    # Inventário
    # -----------------------------------------------------------------
    inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
    inventory_url='https://inventario.app.ic.ufba.br/inventory'

    if [ -f "$inventory_path/src/inventory.py" ]; then
        python3 "$inventory_path/src/inventory.py" "$inventory_url" &> /var/log/inventory.log
    fi

    # -----------------------------------------------------------------
    # Roda o lab-startup em background (para instalar programas novos)
    # -----------------------------------------------------------------
    nohup /usr/local/sbin/lab-startup.sh > /var/log/lab-startup-postlogin.log 2>&1 &
fi

exit 0

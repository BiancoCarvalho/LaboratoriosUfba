#!/bin/bash

if [[ "$USER" == "aluno" ]]; then

    # =================================================================
    # 1) Recria o home do aluno
    # =================================================================
    rm -rf /home/$USER
    cp -r /etc/skel /home/$USER
    chown -R $USER:$USER /home/$USER
    echo "aluno:vivaoic2021!" | chpasswd

    # =================================================================
    # 2) Recria a pasta .ssh com a chave FIXA do servidor C#
    # =================================================================
    CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

    mkdir -p /home/$USER/.ssh
    chmod 700 /home/$USER/.ssh
    chown $USER:$USER /home/$USER/.ssh

    echo "$CHAVE" > /home/$USER/.ssh/authorized_keys
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown $USER:$USER /home/$USER/.ssh/authorized_keys

    # =================================================================
    # 3) Garante o SSH rodando
    # =================================================================
    systemctl enable ssh >/dev/null 2>&1 || true
    systemctl start ssh  >/dev/null 2>&1 || true

    # =================================================================
    # 4) Sudoers restrito do aluno
    # =================================================================
    cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF

    chmod 440 /etc/sudoers.d/aluno-ssh

    if ! visudo -c >/dev/null 2>&1; then
        rm -f /etc/sudoers.d/aluno-ssh
    fi

    # =================================================================
    # 5) PATHs e ambiente
    # =================================================================
    echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
    echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc
    rm -f /opt/flutter/bin/cache/lockfile

    chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs

    mkdir -p /home/$USER/Unity/Hub
    ln -s /opt/Unity /home/$USER/Unity/Hub/Editor

    ln -s /opt/gradle /home/$USER/.gradle
    ln -s /opt/npm /home/$USER/.npm
    ln -s /opt/VMs /home/$USER/VirtualBox
    ln -s /opt/nand2tetris /home/$USER/nand2tetris

    # =================================================================
    # 6) MySQL
    # =================================================================
    echo "DROP USER IF EXISTS 'aluno'@'localhost'; CREATE USER 'aluno'@'%' IDENTIFIED BY 'aluno'; GRANT ALL PRIVILEGES ON *.* TO 'aluno'@'%'; FLUSH PRIVILEGES;" | mysql -u root

    # =================================================================
    # 7) PostgreSQL
    # =================================================================
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;"
    sudo -u postgres psql -c "DROP USER IF EXISTS aluno;"
    sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD 'aluno';"
    sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;"
    sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;"

    sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf
    sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf
    sudo systemctl restart postgresql

    # =================================================================
    # 8) Inventário
    # =================================================================
    inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
    inventory_url='https://inventario.app.ic.ufba.br/inventory'
    python3 $inventory_path/src/inventory.py $inventory_url &> /var/log/inventory.log
fi

exit 0

#!/bin/bash
# =====================================================================
#  lab-postlogin-default.sh
#  v3.0.0
#
#  Este arquivo é copiado pelo lab-startup.sh para:
#      /etc/gdm3/PostLogin/Default
#
#  Ele roda A CADA LOGIN do usuário 'aluno'.
# =====================================================================

if [[ "$USER" == "aluno" ]]; then

    rm -rf /home/$USER
    cp -r /etc/skel /home/$USER
    chown -R $USER:$USER /home/$USER
    echo "aluno:vivaoic2021!" | chpasswd

    CHAVE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

    mkdir -p /home/$USER/.ssh
    chmod 700 /home/$USER/.ssh
    chown $USER:$USER /home/$USER/.ssh
    echo "$CHAVE" > /home/$USER/.ssh/authorized_keys
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown $USER:$USER /home/$USER/.ssh/authorized_keys

    systemctl enable ssh >/dev/null 2>&1 || true
    systemctl start ssh  >/dev/null 2>&1 || true

    cat > /etc/sudoers.d/aluno-ssh <<'EOF'
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
aluno ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF
    chmod 440 /etc/sudoers.d/aluno-ssh
    visudo -c >/dev/null 2>&1 || rm -f /etc/sudoers.d/aluno-ssh

    echo 'export PATH="/opt/flutter/bin:$PATH"' >> /home/aluno/.bashrc
    echo 'export PATH="/opt/android-studio/bin:/opt/Android/Sdk/platform-tools:$PATH"' >> /home/aluno/.bashrc
    rm -f /opt/flutter/bin/cache/lockfile

    chown -R aluno:aluno /opt/flutter /opt/nand2tetris /opt/VMs 2>/dev/null || true

    mkdir -p /home/$USER/Unity/Hub
    ln -sf /opt/Unity /home/$USER/Unity/Hub/Editor
    ln -sf /opt/gradle /home/$USER/.gradle
    ln -sf /opt/npm /home/$USER/.npm
    ln -sf /opt/VMs /home/$USER/VirtualBox
    ln -sf /opt/nand2tetris /home/$USER/nand2tetris

    if [ -n "$DISPLAY" ] && command -v dbus-launch &>/dev/null; then
        dbus-launch dconf write /org/gnome/shell/favorite-apps \
            "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']" \
            2>/dev/null || true
    fi

    echo "DROP USER IF EXISTS 'aluno'@'localhost'; CREATE USER 'aluno'@'%' IDENTIFIED BY 'aluno'; GRANT ALL PRIVILEGES ON *.* TO 'aluno'@'%'; FLUSH PRIVILEGES;" | mysql -u root 2>/dev/null || true

    sudo -u postgres psql -c "DROP DATABASE IF EXISTS aluno;" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS aluno;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER aluno WITH PASSWORD 'aluno';" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER USER aluno WITH SUPERUSER;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE aluno OWNER aluno;" 2>/dev/null || true

    sudo sed -i "s/local\s*all\s*postgres\s*peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
    sudo sed -i "s/local\s*all\s*all\s*peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
    sudo systemctl restart postgresql 2>/dev/null || true

    inventory_path="/etc/gdm3/PostLogin/inventory_script-master"
    inventory_url='https://inventario.app.ic.ufba.br/inventory'
    if [ -f "$inventory_path/src/inventory.py" ]; then
        python3 $inventory_path/src/inventory.py $inventory_url &> /var/log/inventory.log
    fi

    # Dispara a atualização dos scripts em background
    nohup sudo /root/labstartup.sh > /var/log/lab-startup-login.log 2>&1 &
fi

exit 0

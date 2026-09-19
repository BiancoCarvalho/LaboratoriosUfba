#!/bin/bash
# Lab Prova Install
# v1.0.0
# Instala o modo prova (quiosque JUDE) na máquina

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-INSTALL" >> "$LOG"

# 1) cria o usuário 'prova' (sem sudo)
/usr/local/sbin/lab-prova-profile-config.sh

# 2) instala policies.json + user.js do Firefox
/usr/local/sbin/lab-prova-config.sh

# 3) libera sudo para o 'labadmin' rodar os scripts de bloqueio/destrave
cat > /etc/sudoers.d/lab <<EOF
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-profile-config.sh
EOF
chmod 440 /etc/sudoers.d/lab

if ! visudo -c >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ERRO: sudoers inválido" >> "$LOG"
    rm -f /etc/sudoers.d/lab
    exit 1
fi

echo "[$(date '+%F %T')] PROVA-INSTALL concluído" >> "$LOG"
exit 0

#!/bin/bash
# =====================================================================
#  lab-prova-install.sh
#  v2.0.0
#
#  Instala os scripts do modo prova e configura o sudoers do 'labadmin'.
#  Roda uma vez na máquina.
#
#  Localização: /usr/local/sbin/lab-prova-install.sh
#  Uso: sudo /usr/local/sbin/lab-prova-install.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-INSTALL" >> "$LOG"

# 1) Confere que os scripts existem
for f in lab-block.sh lab-unblock.sh lab-prova-profile-config.sh lab-prova-config.sh; do
    if [ ! -f "/usr/local/sbin/$f" ]; then
        echo "[$(date '+%F %T')] ERRO: $f não existe" >> "$LOG"
        exit 1
    fi
    chmod 755 "/usr/local/sbin/$f"
done

# 2) Configura o sudoers do 'labadmin'
cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-profile-config.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-config.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF

chmod 440 /etc/sudoers.d/labadmin

if ! visudo -c >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ERRO: sudoers inválido" >> "$LOG"
    rm -f /etc/sudoers.d/labadmin
    exit 1
fi

echo "[$(date '+%F %T')] PROVA-INSTALL concluído" >> "$LOG"
exit 0

#!/bin/bash
# =====================================================================
#  lab-prova-install.sh
#  v3.0.0
#
#  Configura o sudoers do 'labadmin'.
#  Não cria mais usuário 'prova'.
#
#  Localização: /usr/local/sbin/lab-prova-install.sh
#  Uso: sudo /usr/local/sbin/lab-prova-install.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-INSTALL" >> "$LOG"

# Confere que os scripts existem
for f in lab-block.sh lab-unblock.sh; do
    if [ ! -f "/usr/local/sbin/$f" ]; then
        echo "[$(date '+%F %T')] ERRO: $f não existe" >> "$LOG"
        exit 1
    fi
    chmod 755 "/usr/local/sbin/$f"
done

# Configura o sudoers do 'labadmin'
cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
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

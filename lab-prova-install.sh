#!/bin/bash
# =====================================================================
#  lab-prova-install.sh
#  v4.0.0
#
#  Garante o sudoers do 'labadmin'.
# =====================================================================

LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) PROVA-INSTALL" >> "$LOG"

# Confere que os scripts existem
for f in lab-block.sh lab-block-sites.sh lab-unblock.sh; do
    if [ -f "/usr/local/sbin/$f" ]; then
        chmod 755 "/usr/local/sbin/$f"
    else
        echo "[$(date '+%F %T')] ⚠️ $f não existe em /usr/local/sbin/" >> "$LOG"
    fi
done

# Configura o sudoers do 'labadmin'
rm -f /etc/sudoers.d/labadmin

cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
labadmin ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
EOF

chmod 440 /etc/sudoers.d/labadmin
chown root:root /etc/sudoers.d/labadmin

# ⭐ Valida SÓ o arquivo criado
if ! visudo -cf /etc/sudoers.d/labadmin >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] ⚠️ sudoers labadmin inválido — fallback" >> "$LOG"

    cat > /etc/sudoers.d/labadmin <<'EOF'
labadmin ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/labadmin
    chown root:root /etc/sudoers.d/labadmin
fi

echo "[$(date '+%F %T')] PROVA-INSTALL concluído" >> "$LOG"
exit 0

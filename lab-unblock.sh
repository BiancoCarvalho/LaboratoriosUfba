#!/bin/bash
# =====================================================================
#  lab-unblock.sh  v6.0.0
#  Restaura tudo: sites liberados novamente + programas desbloqueados.
# =====================================================================

set +e
LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK (full)" >> "$LOG"

# ---------------------------------------------------------------------
# 1) SITES — remove policies dos navegadores
# ---------------------------------------------------------------------
rm -rf /var/snap/firefox/common/policies                  2>/dev/null
rm -rf /etc/firefox/policies                              2>/dev/null
rm -f  /usr/lib/firefox/distribution/policies.json        2>/dev/null

rm -rf /etc/opt/chrome/policies/managed                   2>/dev/null
rm -rf /etc/opt/chromium/policies/managed                 2>/dev/null
rm -rf /etc/chromium/policies/managed                     2>/dev/null

# ---------------------------------------------------------------------
# 2) PROGRAMAS — restaura permissões originais
# ---------------------------------------------------------------------
if [ -f /etc/lab/orig-perms.txt ]; then
  while read -r path mode; do
    [ -e "$path" ] || continue
    chmod "$mode" "$path" 2>/dev/null || true
    chown root:root "$path" 2>/dev/null || true
  done < /etc/lab/orig-perms.txt

  rm -f /etc/lab/orig-perms.txt
fi

# Garante 755 nos binários de navegadores
for b in firefox chrome chromium google-chrome; do
  for p in /usr/bin/"$b" /usr/local/bin/"$b" /snap/bin/"$b"; do
    [ -e "$p" ] && chmod 0755 "$p" 2>/dev/null
  done
done

# Remove usuários do grupo
for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
  gpasswd -d "$u" lab-browsers 2>/dev/null
done

rm -f /etc/lab/.programs-locked

# ---------------------------------------------------------------------
# 3) MATA NAVEGADORES para forçar releitura
# ---------------------------------------------------------------------
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

for u in $USUARIOS_HUMANOS; do
  sudo -u "$u" pkill -TERM firefox        2>/dev/null
  sudo -u "$u" pkill -TERM chrome         2>/dev/null
  sudo -u "$u" pkill -TERM google-chrome  2>/dev/null
  sudo -u "$u" pkill -TERM chromium       2>/dev/null
done
pkill -TERM firefox        2>/dev/null
pkill -TERM chrome         2>/dev/null
pkill -TERM google-chrome  2>/dev/null
pkill -TERM chromium       2>/dev/null

sleep 2

for u in $USUARIOS_HUMANOS; do
  sudo -u "$u" pkill -KILL firefox        2>/dev/null
  sudo -u "$u" pkill -KILL chrome         2>/dev/null
  sudo -u "$u" pkill -KILL google-chrome  2>/dev/null
  sudo -u "$u" pkill -KILL chromium       2>/dev/null
done
pkill -KILL firefox        2>/dev/null
pkill -KILL chrome         2>/dev/null
pkill -KILL google-chrome  2>/dev/null
pkill -KILL chromium       2>/dev/null

echo "[$(date '+%F %T')] UNBLOCK concluído" >> "$LOG"
exit 0

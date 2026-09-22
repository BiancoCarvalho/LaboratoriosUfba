#!/bin/bash
# =====================================================================
#  lab-unblock.sh  v7.0.0
#  Restaura tudo: sites liberados + programas desbloqueados (AppArmor).
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
# 2) PROGRAMAS — remove perfil AppArmor ativo
# ---------------------------------------------------------------------
ATIVO="/etc/apparmor.d/lab-restrict.ativo"

if [ -f "$ATIVO" ]; then
  apparmor_parser -R "$ATIVO" 2>/dev/null
  rm -f "$ATIVO"
fi

# Garante que o perfil base também não está carregado
apparmor_parser -R /etc/apparmor.d/lab-restrict 2>/dev/null

# Remove alunos do grupo labusers
for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
  gpasswd -d "$u" labusers 2>/dev/null
done

# Compatibilidade: se a v10 deixou resquícios de chmod, limpa
if [ -f /etc/lab/orig-perms.txt ]; then
  while read -r path mode; do
    [ -e "$path" ] || continue
    chmod "$mode" "$path" 2>/dev/null
    chown root:root "$path" 2>/dev/null
  done < /etc/lab/orig-perms.txt
  rm -f /etc/lab/orig-perms.txt
fi

for b in firefox chrome chromium google-chrome; do
  for p in /usr/bin/"$b" /usr/local/bin/"$b" /snap/bin/"$b"; do
    [ -e "$p" ] && chmod 0755 "$p" 2>/dev/null
  done
done

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

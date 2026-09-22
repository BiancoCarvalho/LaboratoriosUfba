#!/bin/bash
# =====================================================================
#  lab-unblock.sh
#  v6.0.0
#
#  Remove TODAS as politicas de bloqueio (Firefox, Chrome, Chromium)
#  e MATA os navegadores para forcar releitura.
#
#  v6.0.0:
#    - Usa 'pkill -f' para matar processos filhos
#    - Usa 'pkill -u' para matar por usuario
#    - Para o snap do Firefox
#    - Verifica se as politicas foram removidas
#    - Verifica se sobrou algum navegador
# =====================================================================

set +e

LOG="/var/log/lab.log"
echo "[$(date '+%F %T')] host=$(hostname) UNBLOCK" >> "$LOG"

# ---------------------------------------------------------------------
# 1. Remove TODAS as politicas
# ---------------------------------------------------------------------
echo "==> Removendo politicas..."

# Firefox Snap
rm -rf /var/snap/firefox/common/policies 2>/dev/null

# Firefox .deb (PPA)
rm -rf /etc/firefox/policies 2>/dev/null

# Firefox .deb (interno)
rm -f /usr/lib/firefox/distribution/policies.json 2>/dev/null

# Chrome
rm -rf /etc/opt/chrome/policies/managed 2>/dev/null

# Chromium
rm -rf /etc/opt/chromium/policies/managed 2>/dev/null

# Chromium (alternativo)
rm -rf /etc/chromium/policies/managed 2>/dev/null

# ---------------------------------------------------------------------
# 2. Mata navegadores
# ---------------------------------------------------------------------
echo "==> Fechando navegadores..."

NAVEGADORES="firefox firefox-esr chrome google-chrome chromium chromium-browser"

# 1. TERM (educado)
for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    for nav in $NAVEGADORES; do
        pkill -TERM -u "$u" -f "$nav" 2>/dev/null || true
    done
done

for nav in $NAVEGADORES; do
    pkill -TERM -f "$nav" 2>/dev/null || true
done

sleep 3

# 2. KILL (forca)
for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    for nav in $NAVEGADORES; do
        pkill -KILL -u "$u" -f "$nav" 2>/dev/null || true
    done
done

for nav in $NAVEGADORES; do
    pkill -KILL -f "$nav" 2>/dev/null || true
done

# 3. Snap do Firefox
if snap list firefox &>/dev/null; then
    snap stop firefox 2>/dev/null || true
fi

sleep 1

# ---------------------------------------------------------------------
# 3. Verifica se sobrou navegador
# ---------------------------------------------------------------------
if pgrep -f "firefox|chrome|chromium" &>/dev/null; then
    echo "[AVISO] Ainda tem navegadores rodando:"
    pgrep -af "firefox|chrome|chromium"
    echo "[$(date '+%F %T')] [AVISO] Navegadores ainda rodando" >> "$LOG"
else
    echo "[OK] Navegadores fechados"
    echo "[$(date '+%F %T')] Navegadores fechados" >> "$LOG"
fi

# ---------------------------------------------------------------------
# 4. Verifica se as politicas foram removidas
# ---------------------------------------------------------------------
echo "==> Verificando politicas..."

POLITICAS_RESTANTES=0

[ -d /var/snap/firefox/common/policies ] && POLITICAS_RESTANTES=$((POLITICAS_RESTANTES + 1))
[ -d /etc/firefox/policies ] && POLITICAS_RESTANTES=$((POLITICAS_RESTANTES + 1))
[ -d /etc/opt/chrome/policies/managed ] && POLITICAS_RESTANTES=$((POLITICAS_RESTANTES + 1))
[ -d /etc/opt/chromium/policies/managed ] && POLITICAS_RESTANTES=$((POLITICAS_RESTANTES + 1))

if [ "$POLITICAS_RESTANTES" -gt 0 ]; then
    echo "[AVISO] Ainda tem $POLITICAS_RESTANTES pasta(s) de politicas"
    echo "[$(date '+%F %T')] [AVISO] Politicas ainda existem" >> "$LOG"
else
    echo "[OK] Todas as politicas removidas"
    echo "[$(date '+%F %T')] Politicas removidas" >> "$LOG"
fi

echo "[$(date '+%F %T')] UNBLOCK concluido" >> "$LOG"
exit 0

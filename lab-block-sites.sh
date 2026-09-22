#!/bin/bash
# =====================================================================
#  lab-block-sites.sh
#  v2.0.0
#
#  Bloqueia uma lista de sites recebida como argumento.
#  Uso: sudo /usr/local/sbin/lab-block-sites.sh "youtube.com,instagram.com"
#
#  Localizacao: /usr/local/sbin/lab-block-sites.sh
#
#  v2.0.0:
#    - Usa 'pkill -f' para matar processos filhos
#    - Usa 'pkill -u' para matar por usuario
#    - Para o snap do Firefox
#    - Verifica se sobrou algum navegador
# =====================================================================

SITES="$1"
LOG="/var/log/lab.log"

if [ -z "$SITES" ]; then
    echo "[$(date '+%F %T')] lab-block-sites: nenhum site informado" >> "$LOG"
    exit 1
fi

echo "[$(date '+%F %T')] host=$(hostname) BLOCK-SITES: $SITES" >> "$LOG"

# Converte "a.com,b.com" em array
IFS=',' read -ra LISTA <<< "$SITES"

# ---------------------------------------------------------------------
# Monta JSON do Firefox
# ---------------------------------------------------------------------
BLOCK_JSON=""
for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)   # trim
    [ -z "$s" ] && continue
    BLOCK_JSON="$BLOCK_JSON\"*://*.$s/*\",\"*://$s/*\","
done
BLOCK_JSON="${BLOCK_JSON%,}"

FIREFOX_POLICIES=$(cat <<EOF
{
  "policies": {
    "WebsiteFilter": {
      "Block": [$BLOCK_JSON]
    },
    "BlockAboutAddons": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "DisableDeveloperTools": true,
    "DisablePrivateBrowsing": true,
    "DisableSafeMode": true,
    "DisableSafeBrowsing": true,
    "InstallAddonsPermission": {
      "Default": false
    },
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": ""
  }
}
EOF
)

# ---------------------------------------------------------------------
# Aplica politicas do Firefox (Snap e .deb)
# ---------------------------------------------------------------------
if [ -d /snap/firefox ] || snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$FIREFOX_POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
fi

if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
fi

# ---------------------------------------------------------------------
# Monta blocklist do Chrome
# ---------------------------------------------------------------------
CHROME_BLOCK=""
for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
    [ -z "$s" ] && continue
    CHROME_BLOCK="$CHROME_BLOCK\"*://*.$s/*\",\"*://$s/*\","
done
CHROME_BLOCK="${CHROME_BLOCK%,}"

CHROME_POLICIES=$(cat <<EOF
{
  "URLBlocklist": [$CHROME_BLOCK],
  "IncognitoModeAvailability": 1,
  "DeveloperToolsAvailability": 2,
  "ExtensionInstallBlocklist": ["*"],
  "BrowserGuestModeEnabled": false
}
EOF
)

# ---------------------------------------------------------------------
# Aplica politicas do Chrome / Chromium
# ---------------------------------------------------------------------
if [ -d /opt/google/chrome ] || command -v google-chrome &>/dev/null; then
    mkdir -p /etc/opt/chrome/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chrome/policies/managed/policies.json
    chmod 644 /etc/opt/chrome/policies/managed/policies.json
fi

if [ -d /usr/lib/chromium ] || command -v chromium &>/dev/null; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
fi

# =====================================================================
# Mata navegadores (v2.0.0 - com -f)
# =====================================================================
echo "==> Fechando navegadores..."

NAVEGADORES="firefox firefox-esr chrome google-chrome chromium chromium-browser"

# 1. TERM (educado) - TODOS os usuarios humanos
for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    for nav in $NAVEGADORES; do
        pkill -TERM -u "$u" -f "$nav" 2>/dev/null || true
    done
done

# TERM como root
for nav in $NAVEGADORES; do
    pkill -TERM -f "$nav" 2>/dev/null || true
done

sleep 3

# 2. KILL (forca) - TODOS
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

# 4. Verifica
if pgrep -f "firefox|chrome|chromium" &>/dev/null; then
    echo "[AVISO] Ainda tem navegadores rodando:"
    pgrep -af "firefox|chrome|chromium"
else
    echo "[OK] Navegadores fechados"
fi

echo "[$(date '+%F %T')] BLOCK-SITES concluido" >> "$LOG"
exit 0

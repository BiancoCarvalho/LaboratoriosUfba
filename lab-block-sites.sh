#!/bin/bash
# =====================================================================
#  lab-block-sites.sh
#  v1.1.0
#
#  Bloqueia uma lista ADICIONAL de sites (somado ao lab-block.sh).
#  Uso: sudo /usr/local/sbin/lab-block-sites.sh "youtube.com,instagram.com"
#
#  CORREÇÕES v1.1.0:
#    - Valida argumento
#    - Kill de browsers com verificação
#    - Log estruturado
# =====================================================================

set -u

SITES="${1:-}"
LOG="/var/log/lab.log"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) BLOCK-SITES: $*" >> "$LOG"
}

if [ -z "$SITES" ]; then
    log "ERRO: nenhum site informado"
    exit 1
fi

log "iniciado (sites: $SITES)"

IFS=',' read -ra LISTA <<< "$SITES"

# Monta JSON
BLOCK_JSON=""
for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
    [ -z "$s" ] && continue
    BLOCK_JSON="$BLOCK_JSON\"*://*.$s/*\",\"*://$s/*\","
done
BLOCK_JSON="${BLOCK_JSON%,}"

if [ -z "$BLOCK_JSON" ]; then
    log "ERRO: lista vazia após sanitização"
    exit 1
fi

FIREFOX_POLICIES=$(cat <<EOF
{
  "policies": {
    "WebsiteFilter": {
      "Block": [$BLOCK_JSON]
    },
    "DisableDeveloperTools": true,
    "DisablePrivateBrowsing": true,
    "DisableSafeBrowsing": true,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": ""
  }
}
EOF
)

# Firefox Snap
if [ -d /snap/firefox ] || snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$FIREFOX_POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
fi

# Firefox .deb
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
fi

# Chrome
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
  "DeveloperToolsAvailability": 2
}
EOF
)

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

# Mata navegadores
BROWSERS=(firefox firefox-esr chrome google-chrome chromium chromium-browser)

for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null || true
done

sleep 2

for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null || true
done

log "concluído"
exit 0

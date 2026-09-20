#!/bin/bash
# =====================================================================
#  lab-block-sites.sh
#  v1.0.0
#
#  Bloqueia uma lista de sites recebida como argumento.
#  Uso: sudo /usr/local/sbin/lab-block-sites.sh "youtube.com,instagram.com"
#
#  Localização: /usr/local/sbin/lab-block-sites.sh
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

# Monta JSON do Firefox
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

# Mata navegadores para forçar releitura
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -TERM firefox   2>/dev/null
    sudo -u "$u" pkill -TERM chrome    2>/dev/null
    sudo -u "$u" pkill -TERM chromium  2>/dev/null
done

sleep 2

for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -KILL firefox   2>/dev/null
    sudo -u "$u" pkill -KILL chrome    2>/dev/null
    sudo -u "$u" pkill -KILL chromium  2>/dev/null
done

echo "[$(date '+%F %T')] BLOCK-SITES concluído" >> "$LOG"
exit 0

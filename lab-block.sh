#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v10.1.0
# =====================================================================

set -u

LOG="/var/log/lab.log"
LIBERADOS_ARG="${1:-jude.dcc.ufba.br,*.dcc.ufba.br}"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK (liberados: $LIBERADOS_ARG)" >> "$LOG"

# Sanitização
SANITIZAR='s/[^a-zA-Z0-9.\-*,]//g'
IFS=',' read -ra LISTA_RAW <<< "$LIBERADOS_ARG"
LISTA=()
for s in "${LISTA_RAW[@]}"; do
    s=$(echo "$s" | xargs | sed "$SANITIZAR")
    [ -z "$s" ] && continue
    s="${s%.}"; s="${s#.}"
    [ -z "$s" ] && continue
    LISTA+=("$s")
done

if [ ${#LISTA[@]} -eq 0 ]; then
    LISTA=("jude.dcc.ufba.br" "*.dcc.ufba.br")
fi

# Exceções Firefox
EXCECOES=""
adicionar_excecao() { EXCECOES="$EXCECOES\"$1\","; }

for s in "${LISTA[@]}"; do
    if echo "$s" | grep -q '\*'; then
        adicionar_excecao "https://$s/*"
        adicionar_excecao "http://$s/*"
    else
        adicionar_excecao "https://$s"
        adicionar_excecao "http://$s"
        adicionar_excecao "https://$s/*"
        adicionar_excecao "http://$s/*"
        adicionar_excecao "https://*.$s/*"
        adicionar_excecao "http://*.$s/*"
        adicionar_excecao "https://www.$s/*"
        adicionar_excecao "http://www.$s/*"
    fi
done
EXCECOES="${EXCECOES%,}"

FIREFOX_POLICIES=$(cat <<EOF
{
  "policies": {
    "WebsiteFilter": {
      "Block": ["<all_urls>"],
      "Exceptions": [$EXCECOES]
    },
    "BlockAboutAddons": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "DisableDeveloperTools": true,
    "DisableFirefoxAccounts": true,
    "DisableFormHistory": true,
    "DisablePocket": true,
    "DisablePrivateBrowsing": true,
    "DisableSafeMode": true,
    "DisableProfileRefresh": true,
    "DisableProfileImport": true,
    "DisableFirefoxStudies": true,
    "DisableTelemetry": true,
    "DontCheckDefaultBrowser": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "NoDefaultBookmarks": true,
    "InstallAddonsPermission": { "Default": false },
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true },
      "Camera": { "BlockNewRequests": true },
      "Microphone": { "BlockNewRequests": true }
    },
    "Preferences": {
      "network.trr.mode":                         { "Value": 5,     "Status": "locked" },
      "network.proxy.type":                       { "Value": 0,     "Status": "locked" },
      "network.protocol-handler.external.irc":    { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.ftp":    { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.mailto": { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.file":   { "Value": false, "Status": "locked" }
    }
  }
}
EOF
)

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

# Chrome
ALLOWLIST=""
for s in "${LISTA[@]}"; do
    if echo "$s" | grep -q '\*'; then
        ALLOWLIST="$ALLOWLIST\"$s\","
    else
        ALLOWLIST="$ALLOWLIST\"$s\",\"*.$s\","
    fi
done
ALLOWLIST="${ALLOWLIST%,}"

CHROME_POLICIES=$(cat <<EOF
{
  "URLBlocklist": ["*"],
  "URLAllowlist": [$ALLOWLIST],
  "DeveloperToolsAvailability": 2,
  "IncognitoModeAvailability": 1,
  "BrowserSignin": 0,
  "BrowserGuestModeEnabled": false,
  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "PrintingEnabled": false,
  "BookmarkBarEnabled": false,
  "PromotionalTabsEnabled": false,
  "DefaultBrowserSettingEnabled": false,
  "MetricsReportingEnabled": false,
  "SafeBrowsingProtectionLevel": 0,
  "SyncDisabled": true,
  "BackgroundModeEnabled": false,
  "TaskManagerEndProcessEnabled": false,
  "ExtensionInstallBlocklist": ["*"],
  "ImportBookmarks": false,
  "ImportHistory": false,
  "ImportSavedPasswords": false,
  "ImportSearchEngine": false,
  "ClearBrowsingDataOnExit": false,
  "RegisteredProtocolHandlers": []
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

# USB
USB_CONF="/etc/modprobe.d/lab-usb.conf"
{
    echo "# Bloqueio de armazenamento USB — gerado por lab-block.sh"
    echo "install usb-storage /bin/false"
    echo "blacklist usb-storage"
} > "$USB_CONF"
chmod 644 "$USB_CONF"

if lsmod | grep -q '^usb_storage'; then
    modprobe -r usb-storage 2>/dev/null || true
fi

# update-initramfs é lento. Só na primeira configuração:
# sudo update-initramfs -u

# Mata navegadores (força releitura das políticas)
BROWSERS=(firefox firefox-esr chrome google-chrome chromium chromium-browser falkon epiphany midori qutebrowser surf)

for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null || true
done

sleep 1

for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null || true
done

echo "[$(date '+%F %T')] BLOCK concluído — liberados: ${LISTA[*]}" >> "$LOG"
exit 0

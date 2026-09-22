#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v10.0.0
#
#  Bloqueia TUDO no Firefox/Chrome, exceto os dominios passados.
#  v10.0.0: mata navegadores com pkill -f (pega processos filhos)
# =====================================================================

LOG="/var/log/lab.log"
LIBERADOS_ARG="$1"

if [ -z "$LIBERADOS_ARG" ]; then
    LIBERADOS_ARG="jude.dcc.ufba.br,*.dcc.ufba.br"
fi

echo "[$(date '+%F %T')] host=$(hostname) BLOCK (liberados: $LIBERADOS_ARG)" >> "$LOG"

IFS=',' read -ra LISTA <<< "$LIBERADOS_ARG"

# Monta JSON de excecoes do Firefox
EXCECOES=""
for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
    [ -z "$s" ] && continue

    if echo "$s" | grep -q '\*'; then
        EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\","
    else
        EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\",\"https://*.$s/*\",\"http://*.$s/*\","
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
    "DontCheckDefaultBrowser": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "NoDefaultBookmarks": true,
    "DisableSafeBrowsing": true,
    "InstallAddonsPermission": {
      "Default": false
    },
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true },
      "Camera": { "BlockNewRequests": true },
      "Microphone": { "BlockNewRequests": true }
    }
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

# Chrome / Chromium
ALLOWLIST=""
for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
    [ -z "$s" ] && continue
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

# =====================================================================
# Mata navegadores (v10.0.0 - com -f para pegar processos filhos)
# =====================================================================
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

# 4. Verifica
if pgrep -f "firefox|chrome|chromium" &>/dev/null; then
    echo "[AVISO] Ainda tem navegadores rodando:"
    pgrep -af "firefox|chrome|chromium"
else
    echo "[OK] Navegadores fechados"
fi

echo "[$(date '+%F %T')] BLOCK concluido" >> "$LOG"
exit 0

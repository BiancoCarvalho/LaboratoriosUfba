#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v6.0.0
#
#  Ativa o modo prova:
#    - Bloqueia Firefox (Snap ou .deb)
#    - Bloqueia Chrome
#    - Mata os navegadores para forçar releitura das policies
#
#  Localização: /usr/local/sbin/lab-block.sh
#  Uso: sudo /usr/local/sbin/lab-block.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# =====================================================================
# FIREFOX
# =====================================================================
FIREFOX_POLICIES='{
  "policies": {
    "WebsiteFilter": {
      "Block": ["<all_urls>"],
      "Exceptions": [
        "https://jude.dcc.ufba.br/*",
        "https://*.dcc.ufba.br/*"
      ]
    },
    "BlockAboutConfig": true,
    "DisableDeveloperTools": true,
    "DisableFirefoxAccounts": true,
    "DisableFormHistory": true,
    "DisablePocket": true,
    "DisablePrivateBrowsing": true,
    "DontCheckDefaultBrowser": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "NoDefaultBookmarks": true,
    "DisableProfileImport": true,
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true }
    }
  }
}'

# Aplica no Firefox Snap
if [ -d /snap/firefox ] || snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$FIREFOX_POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
    echo "[$(date '+%F %T')] Firefox Snap policies aplicadas" >> "$LOG"
fi

# Aplica no Firefox .deb
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
    echo "[$(date '+%F %T')] Firefox .deb policies aplicadas" >> "$LOG"
fi

# =====================================================================
# CHROME
# =====================================================================
CHROME_POLICIES='{
  "URLBlocklist": ["*"],
  "URLAllowlist": [
    "https://jude.dcc.ufba.br/*",
    "https://*.dcc.ufba.br/*"
  ],
  "DeveloperToolsAvailability": 2,
  "IncognitoModeAvailability": 1,
  "BrowserSignin": 0,
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
  "HomepageLocation": "https://jude.dcc.ufba.br/auth/login",
  "HomepageIsNewTabPage": false,
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["https://jude.dcc.ufba.br/auth/login"],
  "TaskManagerEndProcessEnabled": false
}'

# Aplica no Chrome
if [ -d /opt/google/chrome ] || command -v google-chrome &>/dev/null; then
    mkdir -p /etc/opt/chrome/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chrome/policies/managed/policies.json
    chmod 644 /etc/opt/chrome/policies/managed/policies.json
    echo "[$(date '+%F %T')] Chrome policies aplicadas" >> "$LOG"

    # Chrome via Snap (caso esteja instalado como snap em algumas máquinas)
    if snap list chromium &>/dev/null; then
        mkdir -p /etc/opt/chromium/policies/managed
        echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
        chmod 644 /etc/opt/chromium/policies/managed/policies.json
    fi
fi

# Aplica no Chromium (caso exista)
if [ -d /usr/lib/chromium ] || command -v chromium &>/dev/null; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
    echo "[$(date '+%F %T')] Chromium policies aplicadas" >> "$LOG"
fi

# =====================================================================
# MATA OS NAVEGADORES (para forçar releitura das policies)
# =====================================================================
pkill -9 firefox 2>/dev/null || true
pkill -9 chrome 2>/dev/null || true
pkill -9 google-chrome 2>/dev/null || true
pkill -9 chromium 2>/dev/null || true

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

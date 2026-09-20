#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v6.5.0
#
#  Ativa o modo prova:
#    - Bloqueia Firefox (Snap ou .deb)
#    - Bloqueia Chrome / Chromium (formato correto de URLAllowlist)
#    - Fecha os navegadores
#    - Abre o Firefox no JUDE automaticamente
#    - Desativa avisos de "site de risco"
#
#  Localização: /usr/local/sbin/lab-block.sh
#  Uso: sudo /usr/local/sbin/lab-block.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"
USUARIO_LOGADO="aluno"
URL_JUDE="https://jude.dcc.ufba.br/auth/login"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# =====================================================================
# FIREFOX — policies
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
    "DisableSafeBrowsing": true,
    "DisableSecurityBypass": {
      "InvalidCertificate": true,
      "SafeBrowsing": true
    },
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true }
    },
    "Preferences": {
      "browser.safebrowsing.malware.enabled": { "Value": false, "Status": "locked" },
      "browser.safebrowsing.phishing.enabled": { "Value": false, "Status": "locked" },
      "browser.safebrowsing.downloads.enabled": { "Value": false, "Status": "locked" },
      "browser.safebrowsing.downloads.remote.enabled": { "Value": false, "Status": "locked" },
      "security.certerrors.mitm.auto_enable_enterprise_roots": { "Value": true, "Status": "locked" }
    }
  }
}'

# Firefox Snap
if [ -d /snap/firefox ] || snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$FIREFOX_POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
    echo "[$(date '+%F %T')] Firefox Snap: policies aplicadas" >> "$LOG"
fi

# Firefox .deb
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
    echo "[$(date '+%F %T')] Firefox .deb: policies aplicadas" >> "$LOG"
fi

# =====================================================================
# CHROME — policies (FORMATO CORRETO)
# =====================================================================
CHROME_POLICIES='{
  "URLBlocklist": ["*"],
  "URLAllowlist": [
    "jude.dcc.ufba.br",
    "*.dcc.ufba.br"
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
  "TaskManagerEndProcessEnabled": false,
  "HomepageLocation": "https://jude.dcc.ufba.br/auth/login",
  "HomepageIsNewTabPage": false,
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["https://jude.dcc.ufba.br/auth/login"]
}'

# Chrome
if [ -d /opt/google/chrome ] || command -v google-chrome &>/dev/null; then
    mkdir -p /etc/opt/chrome/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chrome/policies/managed/policies.json
    chmod 644 /etc/opt/chrome/policies/managed/policies.json
    echo "[$(date '+%F %T')] Chrome: policies aplicadas" >> "$LOG"
fi

# Chromium
if [ -d /usr/lib/chromium ] || command -v chromium &>/dev/null; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
    echo "[$(date '+%F %T')] Chromium: policies aplicadas" >> "$LOG"
fi

# =====================================================================
# FECHA OS NAVEGADORES
# =====================================================================
pkill -TERM firefox 2>/dev/null || true
pkill -TERM chrome 2>/dev/null || true
pkill -TERM google-chrome 2>/dev/null || true
pkill -TERM chromium 2>/dev/null || true

sleep 3

pkill -9 firefox 2>/dev/null || true
pkill -9 chrome 2>/dev/null || true
pkill -9 google-chrome 2>/dev/null || true
pkill -9 chromium 2>/dev/null || true

sleep 1

# =====================================================================
# ABRE O FIREFOX NO JUDE
# =====================================================================
USUARIO_LOGADO=$(who | grep "(:0)" | awk '{print $1}' | head -n1)

if [ -z "$USUARIO_LOGADO" ]; then
    USUARIO_LOGADO="aluno"
fi

echo "[$(date '+%F %T')] Abrindo Firefox no JUDE como $USUARIO_LOGADO" >> "$LOG"

sudo -u "$USUARIO_LOGADO" \
    DISPLAY=:0 \
    nohup firefox "$URL_JUDE" >/dev/null 2>&1 &

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

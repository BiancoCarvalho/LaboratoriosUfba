#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v7.1.0
#
#  Ativa o modo prova:
#    - Bloqueia Firefox (Snap ou .deb)
#    - Bloqueia Chrome / Chromium
#    - Fecha os navegadores de TODOS os usuários
# =====================================================================

LOG="/var/log/lab.log"

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

# =====================================================================
# CHROME — policies
# =====================================================================
CHROME_POLICIES='{
  "URLBlocklist": ["*"],
  "URLAllowlist": ["jude.dcc.ufba.br", "*.dcc.ufba.br"],
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
  "TaskManagerEndProcessEnabled": false
}'

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
# MATA OS NAVEGADORES — MÉTODO AGRESSIVO
# =====================================================================
# 1) Descobre todos os usuários humanos logados (UID >= 1000)
USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

# 2) Mata os processos do Firefox/Chrome/Chromium de CADA usuário
for u in $USUARIOS_HUMANOS; do
    # Tenta TERM (educado)
    sudo -u "$u" pkill -TERM firefox 2>/dev/null || true
    sudo -u "$u" pkill -TERM chrome 2>/dev/null || true
    sudo -u "$u" pkill -TERM google-chrome 2>/dev/null || true
    sudo -u "$u" pkill -TERM chromium 2>/dev/null || true
done

# 3) Também mata como root (cobre casos de processos do sistema)
pkill -TERM firefox 2>/dev/null || true
pkill -TERM chrome 2>/dev/null || true
pkill -TERM google-chrome 2>/dev/null || true
pkill -TERM chromium 2>/dev/null || true

sleep 3

# 4) Força (KILL) se ainda estiver rodando
for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -KILL firefox 2>/dev/null || true
    sudo -u "$u" pkill -KILL chrome 2>/dev/null || true
    sudo -u "$u" pkill -KILL google-chrome 2>/dev/null || true
    sudo -u "$u" pkill -KILL chromium 2>/dev/null || true
done

pkill -KILL firefox 2>/dev/null || true
pkill -KILL chrome 2>/dev/null || true
pkill -KILL google-chrome 2>/dev/null || true
pkill -KILL chromium 2>/dev/null || true

# 5) Confirma no log
sleep 1
PROCESSOS_RESTANTES=$(pgrep -a firefox; pgrep -a chrome; pgrep -a google-chrome; pgrep -a chromium)
if [ -z "$PROCESSOS_RESTANTES" ]; then
    echo "[$(date '+%F %T')] Todos os navegadores foram fechados" >> "$LOG"
else
    echo "[$(date '+%F %T')] AVISO: ainda há processos: $PROCESSOS_RESTANTES" >> "$LOG"
fi

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

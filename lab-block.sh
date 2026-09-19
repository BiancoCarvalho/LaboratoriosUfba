#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v5.0.0
#
#  Ativa o modo prova: aplica policies.json GLOBAL.
#  Bloqueia TODOS os usuários da máquina.
#  Só o JUDE funciona.
#
#  Funciona com Firefox Snap E .deb.
#
#  Localização: /usr/local/sbin/lab-block.sh
#  Uso: sudo /usr/local/sbin/lab-block.sh
# =====================================================================

set -e

LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# ---------------------------------------------------------------------
# Policies JSON
# ---------------------------------------------------------------------
POLICIES='{
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

# ---------------------------------------------------------------------
# 1) Aplica no Firefox Snap
# ---------------------------------------------------------------------
if [ -d /snap/firefox ] || snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
    echo "[$(date '+%F %T')] Policies aplicadas no Snap" >> "$LOG"
fi

# ---------------------------------------------------------------------
# 2) Aplica no Firefox .deb (caso exista)
# ---------------------------------------------------------------------
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
    echo "[$(date '+%F %T')] Policies aplicadas no .deb" >> "$LOG"
fi

# ---------------------------------------------------------------------
# 3) Mata o Firefox para forçar releitura das policies
# ---------------------------------------------------------------------
pkill -9 firefox 2>/dev/null || true

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

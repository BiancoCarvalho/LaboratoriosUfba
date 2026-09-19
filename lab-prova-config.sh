#!/bin/bash
# Lab Prova Config
# v2.0.0
# Aplica policies.json e user.js SOMENTE no perfil do usuário 'prova'
# NÃO mexe em /etc/firefox/policies/ (que afeta TODOS os usuários)

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-CONFIG" >> "$LOG"

# 1) Usuário precisa existir
if ! id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] ERRO: usuário $USUARIO não existe" >> "$LOG"
    exit 1
fi

# 2) Remove policies GLOBAIS (que afetariam todos os usuários)
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true
rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true

# 3) Descobre o perfil do Firefox do 'prova'
PERFIL=$(ls -d /home/$USUARIO/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)

if [ -z "$PERFIL" ]; then
    PERFIL=$(ls -d /home/$USUARIO/snap/firefox/common/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)
fi

# 4) Se não existe perfil, cria abrindo o Firefox uma vez
if [ -z "$PERFIL" ]; then
    echo "[$(date '+%F %T')] Criando perfil do Firefox para $USUARIO" >> "$LOG"

    sudo -u "$USUARIO" DISPLAY=:0 firefox --headless --screenshot /tmp/x.png about:blank 2>/dev/null || true
    sleep 5
    pkill -KILL -f "firefox.*headless" 2>/dev/null || true
    pkill -KILL -u "$USUARIO" 2>/dev/null || true
    sleep 1

    PERFIL=$(ls -d /home/$USUARIO/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)
    if [ -z "$PERFIL" ]; then
        PERFIL=$(ls -d /home/$USUARIO/snap/firefox/common/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)
    fi
fi

if [ -z "$PERFIL" ]; then
    echo "[$(date '+%F %T')] ERRO: não foi possível criar perfil" >> "$LOG"
    exit 1
fi

echo "[$(date '+%F %T')] Perfil encontrado: $PERFIL" >> "$LOG"

# 5) policies.json — SOMENTE no perfil do 'prova'
cat > "$PERFIL/policies.json" <<'EOF'
{
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
    "DisableAppUpdate": true,
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true }
    }
  }
}
EOF

chown -R "$USUARIO:$USUARIO" "$PERFIL/policies.json"
chmod 644 "$PERFIL/policies.json"

# 6) user.js — SOMENTE no perfil do 'prova'
cat > "$PERFIL/user.js" <<'EOF'
// Lab Prova - travas do Firefox
user_pref("browser.fullscreen.animate", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.tabs.closeWindowWithLastTab", false);
user_pref("dom.event.contextmenu.enabled", false);
user_pref("browser.fullscreen.autohide", false);
user_pref("devtools.enabled", false);
user_pref("devtools.policy.disabled", true);
user_pref("general.warnOnAboutConfig", true);
EOF

chown "$USUARIO:$USUARIO" "$PERFIL/user.js"
chmod 644 "$PERFIL/user.js"

echo "[$(date '+%F %T')] PROVA-CONFIG concluído (perfil: $PERFIL)" >> "$LOG"
exit 0

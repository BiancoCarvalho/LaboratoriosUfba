#!/bin/bash
# Lab Prova Config
# v2.0.0
# Aplica policies.json SOMENTE no perfil do usuário 'prova'
# Não mexe em /etc/firefox/policies/ (que afeta todos os usuários)

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-CONFIG" >> "$LOG"

# 1) Garante que o usuário existe
if ! id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] ERRO: usuário $USUARIO não existe" >> "$LOG"
    exit 1
fi

# 2) Remove qualquer policies GLOBAL (que afetaria todos)
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true
rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true

# 3) Descobre o perfil do Firefox do 'prova'
#    Se não existir ainda, abre uma vez rapidamente pra criar
PERFIL=$(ls -d /home/$USUARIO/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)

if [ -z "$PERFIL" ]; then
    echo "[$(date '+%F %T')] Criando perfil do Firefox para $USUARIO" >> "$LOG"

    # Abre o Firefox em modo headless rapidamente pra criar o perfil
    sudo -u "$USUARIO" DISPLAY=:0 firefox --headless --screenshot /tmp/x.png about:blank 2>/dev/null || true
    sleep 3
    pkill -KILL -f "firefox.*headless" 2>/dev/null || true

    PERFIL=$(ls -d /home/$USUARIO/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)
fi

if [ -z "$PERFIL" ]; then
    echo "[$(date '+%F %T')] ERRO: não foi possível criar perfil do Firefox" >> "$LOG"
    exit 1
fi

echo "[$(date '+%F %T')] Perfil encontrado: $PERFIL" >> "$LOG"

# 4) Aplica policies.json SOMENTE no perfil do 'prova'
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

# 5) Aplica user.js SOMENTE no perfil do 'prova'
cat > "$PERFIL/user.js" <<'EOF'
// Lab Prova — travas do Firefox
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

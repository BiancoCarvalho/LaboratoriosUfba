#!/bin/bash
# =====================================================================
#  lab-prova-config.sh
#  v3.0.0
#
#  Aplica policies.json SOMENTE no perfil do usuário 'prova'.
#  - Bloqueia todos os sites, exceto JUDE e domínios da UFBA
#  - Suprime popups ("Bem-vindo", "Set as default", etc)
#  - NÃO mexe em /etc/firefox/policies/ (global)
#
#  Localização: /usr/local/sbin/lab-prova-config.sh
#  Uso: sudo /usr/local/sbin/lab-prova-config.sh
# =====================================================================

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-CONFIG" >> "$LOG"

# 1) Usuário precisa existir
if ! id "$USUARIO" &>/dev/null; then
    echo "[$(date '+%F %T')] ERRO: usuário $USUARIO não existe" >> "$LOG"
    exit 1
fi

# 2) Remove policies GLOBAIS (evita bloquear todos os usuários)
rm -f /etc/firefox/policies/policies.json 2>/dev/null || true
rm -f /var/snap/firefox/common/policies/policies.json 2>/dev/null || true

# 3) Descobre o perfil do Firefox do 'prova'
PERFIL=$(ls -d /home/$USUARIO/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)

if [ -z "$PERFIL" ]; then
    PERFIL=$(ls -d /home/$USUARIO/snap/firefox/common/.mozilla/firefox/*.default-release 2>/dev/null | head -n1)
fi

# 4) Se não existe, cria a estrutura mínima
if [ -z "$PERFIL" ]; then
    echo "[$(date '+%F %T')] Criando estrutura de perfil" >> "$LOG"

    mkdir -p /home/$USUARIO/.mozilla/firefox
    chown -R $USUARIO:$USUARIO /home/$USUARIO/.mozilla

    cat > /home/$USUARIO/.mozilla/firefox/profiles.ini <<'EOP'
[Profile0]
Name=default
IsRelative=1
Path=default
Default=1

[General]
StartWithLastProfile=1
Version=2
EOP

    mkdir -p /home/$USUARIO/.mozilla/firefox/default
    chown -R $USUARIO:$USUARIO /home/$USUARIO/.mozilla/firefox/default

    PERFIL=/home/$USUARIO/.mozilla/firefox/default
fi

echo "[$(date '+%F %T')] Perfil: $PERFIL" >> "$LOG"

# 5) Aplica policies.json
cat > "$PERFIL/policies.json" <<'EOP'
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
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "NoDefaultBookmarks": true,
    "DisableProfileImport": true,
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true }
    }
  }
}
EOP

chown -R "$USUARIO:$USUARIO" "$PERFIL/policies.json"
chmod 644 "$PERFIL/policies.json"

# 6) Aplica user.js (prefs adicionais)
cat > "$PERFIL/user.js" <<'EOP'
// Lab Prova - prefs de bloqueio
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.homepage_override.buildID", "");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("startup.homepage_override_url", "");
user_pref("browser.messaging-system.whatsNewPanel.enabled", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.shell.skipDefaultBrowserCheckOnFirstRun", true);
user_pref("browser.warnOnQuit", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("dom.event.contextmenu.enabled", false);
user_pref("devtools.enabled", false);
user_pref("devtools.policy.disabled", true);
user_pref("general.warnOnAboutConfig", true);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
user_pref("app.update.auto", false);
EOP

chown "$USUARIO:$USUARIO" "$PERFIL/user.js"
chmod 644 "$PERFIL/user.js"

echo "[$(date '+%F %T')] PROVA-CONFIG concluído" >> "$LOG"
exit 0

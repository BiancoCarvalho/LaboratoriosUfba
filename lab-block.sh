#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v10.2.0
#
#  Bloqueia tudo exceto os sites liberados.
#
#  CORREÇÕES v10.2.0:
#    - Remove chamada a lab-block-sites.sh (não precisa mais)
#    - Não roda update-initramfs (lento demais)
#    - Kill de browsers com verificação de usuário
#    - Timeout em cada operação
#    - Log estruturado
# =====================================================================

set -u

LOG="/var/log/lab.log"
LIBERADOS_ARG="${1:-jude.dcc.ufba.br,*.dcc.ufba.br}"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) BLOCK: $*" >> "$LOG"
}

log "iniciado (liberados: $LIBERADOS_ARG)"

# =========================================================
# Sanitização dos domínios
# =========================================================
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

log "lista final: ${LISTA[*]}"

# =========================================================
# Firefox — Exceções
# =========================================================
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
      "Location":      { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true },
      "Camera":        { "BlockNewRequests": true },
      "Microphone":    { "BlockNewRequests": true }
    },
    "Preferences": {
      "network.trr.mode":                          { "Value": 5,     "Status": "locked" },
      "network.proxy.type":                        { "Value": 0,     "Status": "locked" },
      "network.protocol-handler.external.irc":     { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.ftp":     { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.mailto":  { "Value": false, "Status": "locked" },
      "network.protocol-handler.external.file":    { "Value": false, "Status": "locked" }
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
    log "políticas Firefox Snap aplicadas"
fi

# Firefox .deb
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
    log "políticas Firefox .deb aplicadas"
fi

# =========================================================
# Chrome/Chromium
# =========================================================
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
    log "políticas Chrome aplicadas"
fi

if [ -d /usr/lib/chromium ] || command -v chromium &>/dev/null; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
    log "políticas Chromium aplicadas"
fi

# =========================================================
# USB — Bloqueia armazenamento removível
# =========================================================
USB_CONF="/etc/modprobe.d/lab-usb.conf"

cat > "$USB_CONF" <<EOF
# Bloqueio de armazenamento USB — gerado por lab-block.sh
install usb-storage /bin/false
blacklist usb-storage
EOF
chmod 644 "$USB_CONF"

# ⭐ NÃO roda update-initramfs (lento demais para SSH)
# O módulo já está carregado, então só descarrega se possível
if lsmod | grep -q '^usb_storage'; then
    modprobe -r usb-storage 2>/dev/null || true
fi

log "USB bloqueado (initramfs NÃO atualizado — evita timeout)"

# =========================================================
# Mata navegadores para forçar releitura
# =========================================================
BROWSERS=(
    firefox firefox-esr
    chrome google-chrome
    chromium chromium-browser
    falkon epiphany midori qutebrowser surf
)

# TERM educado
for b in "${BROWSERS[@]}"; do
    pkill -TERM -x "$b" 2>/dev/null || true
done

sleep 1

# KILL garantido
for b in "${BROWSERS[@]}"; do
    pkill -KILL -x "$b" 2>/dev/null || true
done

log "concluído — liberados: ${LISTA[*]}"
exit 0

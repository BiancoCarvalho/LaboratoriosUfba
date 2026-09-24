#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v11.0.0
#
#  Bloqueia TUDO exceto os sites liberados.
#
#  Uso:
#    sudo /usr/local/sbin/lab-block.sh "jude.dcc.ufba.br,uol.com.br,hotmail.com"
#    sudo /usr/local/sbin/lab-block.sh              # usa fallback
#
#  O que faz:
#    - Bloqueia Firefox (.deb) via policies.json
#    - Bloqueia Firefox (Snap) via policies.json
#    - Bloqueia Chrome via policies.json
#    - Bloqueia Chromium via policies.json
#    - Bloqueia armazenamento USB
#    - Mata navegadores abertos (para recarregar políticas)
#
#  O que NÃO faz:
#    - Não roda update-initramfs (evita timeout SSH)
#    - Não descarta domínios válidos (bug corrigido na v11)
#
#  Localização: /usr/local/sbin/lab-block.sh
# =====================================================================

set -u

LOG="/var/log/lab.log"
LIBERADOS_ARG="${1:-jude.dcc.ufba.br,*.dcc.ufba.br}"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) BLOCK: $*" >> "$LOG"
}

log "iniciado (liberados: $LIBERADOS_ARG)"

# =========================================================
# Sanitização robusta
# =========================================================
# Remove \r (Windows) e normaliza espaços
LIBERADOS_ARG=$(echo "$LIBERADOS_ARG" | tr -d '\r' | tr -s ' ')

IFS=',' read -ra LISTA_RAW <<< "$LIBERADOS_ARG"
LISTA=()

for s in "${LISTA_RAW[@]}"; do
    # Trim de espaços
    s=$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Pula vazios
    [ -z "$s" ] && continue

    # Remove caracteres perigosos (mantém letras, números, pontos, hífens, asteriscos)
    s=$(echo "$s" | sed 's/[^a-zA-Z0-9.*-]//g')

    # Pula se ficou vazio
    [ -z "$s" ] && continue

    # Remove pontos no começo/fim
    s="${s%.}"
    s="${s#.}"

    # Pula se ficou vazio
    [ -z "$s" ] && continue

    # Valida que tem pelo menos 1 ponto OU asterisco (domínio válido)
    if echo "$s" | grep -qE '\.|\*'; then
        LISTA+=("$s")
        log "aceito: $s"
    else
        log "REJEITADO (sem ponto): $s"
    fi
done

# Se nada passou, usa fallback
if [ ${#LISTA[@]} -eq 0 ]; then
    LISTA=("jude.dcc.ufba.br" "*.dcc.ufba.br")
    log "lista vazia, usando fallback"
fi

log "lista final: ${LISTA[*]}"
echo "Lista final: ${LISTA[*]}"

# =========================================================
# Firefox — Exceções
# =========================================================
EXCECOES=""
adicionar_excecao() { EXCECOES="$EXCECOES\"$1\","; }

for s in "${LISTA[@]}"; do
    if echo "$s" | grep -q '\*'; then
        # Wildcard: só adiciona com /*
        adicionar_excecao "https://$s/*"
        adicionar_excecao "http://$s/*"
    else
        # Domínio normal: adiciona todas as variações
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
    echo "✅ Firefox Snap bloqueado"
fi

# Firefox .deb
if [ -f /usr/lib/firefox/firefox ] || [ -f /usr/lib/firefox/firefox.sh ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
    log "políticas Firefox .deb aplicadas"
    echo "✅ Firefox .deb bloqueado"
fi

# =========================================================
# Chrome / Chromium
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
    echo "✅ Chrome bloqueado"
fi

if [ -d /usr/lib/chromium ] || command -v chromium &>/dev/null; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
    log "políticas Chromium aplicadas"
    echo "✅ Chromium bloqueado"
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

# NÃO roda update-initramfs (evita timeout SSH)
# O módulo já está carregado, então só descarrega se possível
if lsmod | grep -q '^usb_storage'; then
    modprobe -r usb-storage 2>/dev/null || true
fi

log "USB bloqueado"
echo "✅ USB bloqueado"

# =========================================================
# Mata navegadores para forçar releitura das políticas
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

# =========================================================
# Finalização
# =========================================================
log "concluído — liberados: ${LISTA[*]}"
echo ""
echo "✅ Bloqueio aplicado — liberados: ${LISTA[*]}"
exit 0

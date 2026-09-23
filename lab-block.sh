#!/bin/bash
# =====================================================================
#  lab-block.sh  v10.0.0
#
#  Bloqueio em camadas:
#   1) policies.json (Firefox Snap/.deb + Chrome/Chromium)
#   2) iptables (contenção real de rede)
#   3) reinicia kiosk do Firefox
#   4) watchdog systemd (persistência)
#
#  Uso:
#    sudo /usr/local/sbin/lab-block.sh
#    sudo /usr/local/sbin/lab-block.sh "jude.dcc.ufba.br,google.com"
# =====================================================================

set -u

LOG="/var/log/lab.log"
KIOSK_URL="https://jude.dcc.ufba.br/auth/login"

LIBERADOS_ARG="${1:-jude.dcc.ufba.br,www.dcc.ufba.br}"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK (liberados: $LIBERADOS_ARG)" >> "$LOG"

IFS=',' read -ra LISTA <<< "$LIBERADOS_ARG"

# ---------------------------------------------------------------------
# 1) Resolve IPs dos domínios liberados (para usar no iptables)
# ---------------------------------------------------------------------
IPS_LIBERADOS=()
for s in "${LISTA[@]}"; do
    s="$(echo "$s" | xargs)"
    [ -z "$s" ] && continue
    # remove wildcards
    host="${s#\*.}"
    ips=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u)
    for ip in $ips; do
        IPS_LIBERADOS+=("$ip")
    done
done

# ---------------------------------------------------------------------
# 2) Firefox policies
# ---------------------------------------------------------------------
EXCECOES=""
for s in "${LISTA[@]}"; do
    s="$(echo "$s" | xargs)"
    [ -z "$s" ] && continue

    # Firefox WebsiteFilter NÃO suporta wildcard no host.
    # Enumeramos o domínio exato e o www.
    if echo "$s" | grep -q '\*'; then
        # NÃO usar wildcard no Firefox; pula
        continue
    fi
    EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\","
    # adiciona www se não for subdomínio
    case "$s" in
        www.*) ;;
        *) EXCECOES="$EXCECOES\"https://www.$s/*\",\"http://www.$s/*\"," ;;
    esac
done
EXCECOES="${EXCECOES%,}"

FIREFOX_POLICIES=$(cat <<EOF
{
  "policies": {
    "WebsiteFilter": {
      "Block": ["<all_urls>"],
      "Exceptions": [$EXCECOES]
    },
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
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
    "DisableFirefoxScreenshots": true,
    "DisableMasterPasswordCreation": true,
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

# Firefox Snap — corrigido o bug do ||
if [ -d /snap/firefox ] || ( command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1 ); then
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

# ---------------------------------------------------------------------
# 3) Chrome / Chromium policies
# ---------------------------------------------------------------------
ALLOWLIST=""
for s in "${LISTA[@]}"; do
    s="$(echo "$s" | xargs)"
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
}
EOF
)

if [ -d /opt/google/chrome ] || command -v google-chrome >/dev/null 2>&1; then
    mkdir -p /etc/opt/chrome/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chrome/policies/managed/policies.json
    chmod 644 /etc/opt/chrome/policies/managed/policies.json
fi

if [ -d /usr/lib/chromium ] || command -v chromium >/dev/null 2>&1; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
    chmod 644 /etc/opt/chromium/policies/managed/policies.json
fi

# ---------------------------------------------------------------------
# 4) iptables — contenção real de rede
# ---------------------------------------------------------------------
# Preserva SSH (gestão) e o que está liberado
iptables -F OUTPUT 2>/dev/null
iptables -P OUTPUT ACCEPT

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT          # SSH gestão
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT          # DNS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT         # NTP

# IPs liberados
for ip in "${IPS_LIBERADOS[@]}"; do
    [ -z "$ip" ] && continue
    iptables -A OUTPUT -d "$ip" -j ACCEPT
done

# Bloqueia todo o resto de saída
iptables -A OUTPUT -j DROP

# Persiste
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1
elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4
fi

# ---------------------------------------------------------------------
# 5) Mata navegadores proibidos
# ---------------------------------------------------------------------
NAVEGADORES_PROIBIDOS=(
    "firefox" "firefox-esr" "firefox-bin"
    "chrome" "google-chrome" "google-chrome-stable"
    "chromium" "chromium-browser"
    "epiphany" "epiphany-browser"
    "falkon" "midori" "surf" "qutebrowser"
    "w3m" "lynx" "links" "elinks"
)

USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

# TERM primeiro
for u in $USUARIOS_HUMANOS; do
    for n in "${NAVEGADORES_PROIBIDOS[@]}"; do
        sudo -u "$u" pkill -TERM -x "$n" 2>/dev/null
    done
done
for n in "${NAVEGADORES_PROIBIDOS[@]}"; do
    pkill -TERM -x "$n" 2>/dev/null
done

sleep 2

# KILL depois
for u in $USUARIOS_HUMANOS; do
    for n in "${NAVEGADORES_PROIBIDOS[@]}"; do
        sudo -u "$u" pkill -KILL -x "$n" 2>/dev/null
    done
done
for n in "${NAVEGADORES_PROIBIDOS[@]}"; do
    pkill -KILL -x "$n" 2>/dev/null
done

# ---------------------------------------------------------------------
# 6) Reabre Firefox em kiosk para cada sessão gráfica
# ---------------------------------------------------------------------
for u in $USUARIOS_HUMANOS; do
    # descobre DISPLAY do usuário
    disp=$(sudo -u "$u" bash -lc 'echo $DISPLAY' 2>/dev/null)
    [ -z "$disp" ] && continue
    # só se houver X/Wayland ativo
    if sudo -u "$u" bash -lc "[ -n \"\$(pgrep -u $u -x gnome-session || pgrep -u $u -x xfce4-session || pgrep -u $u -x plasma_session || pgrep -u $u -x mate-session)\" ]" 2>/dev/null; then
        sudo -u "$u" env DISPLAY="$disp" \
            firefox --kiosk "$KIOSK_URL" >/dev/null 2>&1 &
    fi
done

# ---------------------------------------------------------------------
# 7) Ativa watchdog (se ainda não estiver)
# ---------------------------------------------------------------------
if systemctl list-unit-files | grep -q '^lab-watchdog.timer'; then
    systemctl enable --now lab-watchdog.timer >/dev/null 2>&1
fi

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

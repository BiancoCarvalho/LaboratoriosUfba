#!/bin/bash
# =====================================================================
#  lab-block.sh v11.0.0
#
#  Mudanças em relação à v10:
#    - getent com timeout 2s e limite de 5 IPs por domínio
#    - iptables aplicado em background (não bloqueia resposta)
#    - pkill em background
#    - retorna em <2s sempre
#    - não trava mais com uol.com.br e similares
# =====================================================================

set -u

LOG="/var/log/lab.log"
KIOSK_URL="https://jude.dcc.ufba.br/auth/login"

LIBERADOS_ARG="${1:-jude.dcc.ufba.br,www.dcc.ufba.br}"

echo "[$(date '+%F %T')] BLOCK (liberados: $LIBERADOS_ARG)" >> "$LOG"

IFS=',' read -ra LISTA <<< "$LIBERADOS_ARG"

# =====================================================================
# 1) Firefox policies (rápido)
# =====================================================================
EXCECOES=""
for s in "${LISTA[@]}"; do
    s="$(echo "$s" | xargs)"
    [ -z "$s" ] && continue

    # Firefox não suporta wildcard no host
    case "$s" in
        \**) continue ;;
    esac

    EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\","
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
    "DisableDeveloperTools": true,
    "DisablePrivateBrowsing": true,
    "DisableFirefoxScreenshots": true
  }
}
EOF
)

if [ -d /snap/firefox ]; then
    mkdir -p /var/snap/firefox/common/policies
    echo "$FIREFOX_POLICIES" > /var/snap/firefox/common/policies/policies.json
    chmod 644 /var/snap/firefox/common/policies/policies.json
fi

if [ -f /usr/lib/firefox/firefox ]; then
    mkdir -p /etc/firefox/policies
    echo "$FIREFOX_POLICIES" > /etc/firefox/policies/policies.json
    chmod 644 /etc/firefox/policies/policies.json
fi

# =====================================================================
# 2) Chrome policies (rápido)
# =====================================================================
ALLOWLIST=""
for s in "${LISTA[@]}"; do
    s="$(echo "$s" | xargs)"
    [ -z "$s" ] && continue
    ALLOWLIST="$ALLOWLIST\"$s\",\"*.$s\","
done
ALLOWLIST="${ALLOWLIST%,}"

CHROME_POLICIES=$(cat <<EOF
{
  "URLBlocklist": ["*"],
  "URLAllowlist": [$ALLOWLIST],
  "DeveloperToolsAvailability": 2,
  "IncognitoModeAvailability": 1
}
EOF
)

if [ -d /opt/google/chrome ]; then
    mkdir -p /etc/opt/chrome/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chrome/policies/managed/policies.json
fi

if [ -d /usr/lib/chromium ]; then
    mkdir -p /etc/opt/chromium/policies/managed
    echo "$CHROME_POLICIES" > /etc/opt/chromium/policies/managed/policies.json
fi

# =====================================================================
# 3) Mata navegadores em background (não bloqueia resposta)
# =====================================================================
(
    USUARIOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

    for u in $USUARIOS; do
        for n in firefox firefox-esr chrome google-chrome chromium chromium-browser; do
            sudo -u "$u" timeout 2 pkill -TERM -x "$n" 2>/dev/null
        done
    done
    sleep 2
    for u in $USUARIOS; do
        for n in firefox firefox-esr chrome google-chrome chromium chromium-browser; do
            sudo -u "$u" timeout 2 pkill -KILL -x "$n" 2>/dev/null
        done
    done
) &

# =====================================================================
# 4) iptables em background com timeout por getent
# =====================================================================
(
    iptables -F OUTPUT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

    IP_COUNT=0

    for s in "${LISTA[@]}"; do
        s="$(echo "$s" | xargs)"
        [ -z "$s" ] && continue

        # remove wildcard
        host="${s#\*.}"

        # ⭐ timeout de 2s + limite de 5 IPs por domínio
        ips=$(timeout 2 getent ahostsv4 "$host" 2>/dev/null \
              | awk '{print $1}' | sort -u | head -5)

        for ip in $ips; do
            iptables -A OUTPUT -d "$ip" -j ACCEPT
            IP_COUNT=$((IP_COUNT+1))
        done
    done

    if [ "$IP_COUNT" -gt 0 ]; then
        iptables -A OUTPUT -j DROP
        echo "[$(date '+%F %T')] iptables aplicado — $IP_COUNT IPs liberados" >> "$LOG"
    else
        echo "[$(date '+%F %T')] [WARN] nenhum IP resolvido — iptables não aplicado" >> "$LOG"
    fi

    if command -v netfilter-persistent >/dev/null 2>&1; then
        timeout 10 netfilter-persistent save >/dev/null 2>&1
    fi
) &

# =====================================================================
# 5) Ativa watchdog (rápido)
# =====================================================================
if systemctl list-unit-files 2>/dev/null | grep -q '^lab-watchdog.timer'; then
    timeout 3 systemctl enable --now lab-watchdog.timer >/dev/null 2>&1
fi

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

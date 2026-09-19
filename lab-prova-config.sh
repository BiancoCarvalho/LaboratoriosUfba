#!/bin/bash
# Lab Prova Config
# v1.0.0
# Instala policies.json e user.js do Firefox para o modo prova

export DEBIAN_FRONTEND=noninteractive

LOG="/var/log/lab.log"
REPO_RAW="https://raw.githubusercontent.com/graco-ufba/lab-scripts/main"

echo "[$(date '+%F %T')] host=$(hostname) PROVA-CONFIG" >> "$LOG"

# --- 1) policies.json ---
mkdir -p /etc/firefox/policies
if [ -f /usr/local/sbin/policies-prova.json ]; then
    cp /usr/local/sbin/policies-prova.json /etc/firefox/policies/policies.json
else
    wget -q "$REPO_RAW/policies-prova.json" -O /etc/firefox/policies/policies.json
fi
chmod 644 /etc/firefox/policies/policies.json

# Snap do Firefox?
if snap list firefox &>/dev/null; then
    mkdir -p /var/snap/firefox/common/policies
    cp /etc/firefox/policies/policies.json \
       /var/snap/firefox/common/policies/policies.json
fi

# --- 2) user.js no perfil do Firefox do aluno ---
PERFIL_DIR=$(ls -d /home/aluno/.mozilla/firefox/*.default-release 2>/dev/null | head -n1 || true)

if [ -n "$PERFIL_DIR" ]; then
    cat > "$PERFIL_DIR/user.js" <<'EOF'
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
    chown aluno:aluno "$PERFIL_DIR/user.js"
    chmod 644 "$PERFIL_DIR/user.js"
fi

echo "[$(date '+%F %T')] PROVA-CONFIG concluído" >> "$LOG"
exit 0

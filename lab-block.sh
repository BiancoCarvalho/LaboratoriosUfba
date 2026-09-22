#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v10.0.0
#
#  Modos:
#    --sites-only         Bloqueia sites (exceto liberados). Programas livres.
#    --programs-only      Bloqueia todos os programas, exceto navegadores. Sites livres.
#    --sites-and-programs Bloqueia sites (exceto liberados) E programas (exceto navegadores).
#
#  Uso:
#    sudo /usr/local/sbin/lab-block.sh --sites-only
#    sudo /usr/local/sbin/lab-block.sh --sites-only --sites "a.com,b.com"
#    sudo /usr/local/sbin/lab-block.sh --programs-only --browsers "firefox,chrome"
#    sudo /usr/local/sbin/lab-block.sh --sites-and-programs --sites "a.com" --browsers "firefox"
# =====================================================================

set -euo pipefail

LOG="/var/log/lab.log"

MODE=""
SITES=""
BROWSERS="firefox,chrome,chromium"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sites-only)          MODE="sites-only";          shift ;;
    --programs-only)       MODE="programs-only";       shift ;;
    --sites-and-programs)  MODE="sites-and-programs";  shift ;;
    --sites)               SITES="$2";    shift 2 ;;
    --browsers)            BROWSERS="$2"; shift 2 ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

# Modo padrão (compatibilidade com chamadas antigas)
if [[ -z "$MODE" ]]; then
  MODE="sites-only"
fi

# Se veio um site solto como primeiro arg (chamada antiga), trata como sites-only
if [[ "$MODE" == "sites-only" && -z "$SITES" && $# -gt 0 ]]; then
  SITES="$1"
fi

if [[ -z "$SITES" ]]; then
  SITES="jude.dcc.ufba.br,*.dcc.ufba.br"
fi

echo "[$(date '+%F %T')] host=$(hostname) BLOCK mode=$MODE sites='$SITES' browsers='$BROWSERS'" >> "$LOG"

# =====================================================================
#  HELPERS
# =====================================================================

aplicar_sites() {
  echo "[sites] aplicando bloqueio de sites. Liberados: $SITES"

  IFS=',' read -ra LISTA <<< "$SITES"

  # ---------- Firefox ----------
  EXCECOES=""
  for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
    [ -z "$s" ] && continue
    if echo "$s" | grep -q '\*'; then
      EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\","
    else
      EXCECOES="$EXCECOES\"https://$s/*\",\"http://$s/*\",\"https://*.$s/*\",\"http://*.$s/*\","
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
    "Permissions": {
      "Location": { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true }
    }
  }
}
EOF
)

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

  # ---------- Chrome / Chromium ----------
  ALLOWLIST=""
  for s in "${LISTA[@]}"; do
    s=$(echo "$s" | xargs)
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
}

matar_navegadores() {
  USUARIOS_HUMANOS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)

  for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -TERM firefox          2>/dev/null || true
    sudo -u "$u" pkill -TERM chrome           2>/dev/null || true
    sudo -u "$u" pkill -TERM google-chrome    2>/dev/null || true
    sudo -u "$u" pkill -TERM chromium         2>/dev/null || true
  done

  pkill -TERM firefox        2>/dev/null || true
  pkill -TERM chrome         2>/dev/null || true
  pkill -TERM google-chrome  2>/dev/null || true
  pkill -TERM chromium       2>/dev/null || true

  sleep 3

  for u in $USUARIOS_HUMANOS; do
    sudo -u "$u" pkill -KILL firefox          2>/dev/null || true
    sudo -u "$u" pkill -KILL chrome           2>/dev/null || true
    sudo -u "$u" pkill -KILL google-chrome    2>/dev/null || true
    sudo -u "$u" pkill -KILL chromium         2>/dev/null || true
  done

  pkill -KILL firefox        2>/dev/null || true
  pkill -KILL chrome         2>/dev/null || true
  pkill -KILL google-chrome  2>/dev/null || true
  pkill -KILL chromium       2>/dev/null || true
}

# =====================================================================
#  BLOQUEIO DE PROGRAMAS
#
#  Estratégia: grupo "lab-browsers" + chmod 0750 nos navegadores.
#  Todos os outros binários de /usr/bin ficam 0700 (root-only).
#  Usuários humanos NÃO entram em root, então não conseguem executar.
#  Navegadores pertencem ao grupo lab-browsers (usuários entram nele).
#
#  ⚠️  Os binários essenciais ficam numa whitelist para não travar SSH/bash.
# =====================================================================

APLICAR_PROGRAMAS() {
  echo "[programs] bloqueando todos os programas exceto: $BROWSERS"

  # 1) Grupo
  getent group lab-browsers >/dev/null || groupadd lab-browsers

  # 2) Adiciona usuários humanos ao grupo
  for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    usermod -aG lab-browsers "$u" 2>/dev/null || true
  done

  # 3) Prepara pasta de backup da whitelist essencial
  WHITELIST_DIR="/etc/lab"
  WHITELIST_FILE="$WHITELIST_DIR/essential-bins.txt"
  mkdir -p "$WHITELIST_DIR"

  # Gera whitelist essencial na primeira execução
  if [ ! -f "$WHITELIST_FILE" ]; then
    cat > "$WHITELIST_FILE" <<'EOF'
bash
sh
dash
ls
cat
echo
sudo
ssh
sshd
login
su
passwd
mount
umount
systemctl
journalctl
ip
ifconfig
ping
grep
awk
sed
tar
gzip
vi
vim
nano
nohup
env
printenv
which
whereis
whoami
id
groups
ps
top
kill
killall
sleep
date
hostname
uptime
chmod
chown
apt
dpkg
snap
EOF
  fi

  # 4) Marca como "protegido" (root-only) todo binário de /usr/bin
  #    que NÃO esteja na whitelist essencial nem seja navegador.
  PROTECTED_FLAG="/etc/lab/.programs-locked"
  if [ ! -f "$PROTECTED_FLAG" ]; then
    # salva estado atual para restore
    find /usr/bin -maxdepth 1 -type f -exec stat -c '%n %a' {} \; \
      > /etc/lab/orig-perms.txt 2>/dev/null || true

    touch "$PROTECTED_FLAG"
  fi

  # IFS com vírgula para browsers
  IFS=',' read -ra BRS <<< "$BROWSERS"
  declare -A BROWSER_SET=()
  for b in "${BRS[@]}"; do
    b="$(echo "$b" | xargs)"
    [ -z "$b" ] && continue
    BROWSER_SET["$b"]=1
  done

  # Aplica permissões
  while IFS= read -r binpath; do
    name="$(basename "$binpath")"

    # pula whitelist essencial
    if grep -Fxq "$name" "$WHITELIST_FILE"; then
      continue
    fi

    # navegador permitido → 0750 root:lab-browsers
    if [[ -n "${BROWSER_SET[$name]:-}" ]]; then
      chmod 0750 "$binpath" 2>/dev/null || true
      chown root:lab-browsers "$binpath" 2>/dev/null || true
      continue
    fi

    # resto → 0700 root:root
    chmod 0700 "$binpath" 2>/dev/null || true
    chown root:root "$binpath" 2>/dev/null || true

  done < <(find /usr/bin -maxdepth 1 -type f)

  # Também trata /usr/local/bin (exceto scripts do lab)
  while IFS= read -r binpath; do
    name="$(basename "$binpath")"
    [[ "$name" == lab-* ]] && continue
    chmod 0700 "$binpath" 2>/dev/null || true
    chown root:root "$binpath" 2>/dev/null || true
  done < <(find /usr/local/bin -maxdepth 1 -type f 2>/dev/null || true)

  echo "[programs] bloqueio aplicado."
}

REVERTER_PROGRAMAS() {
  echo "[programs] revertendo bloqueio de programas"

  PROTECTED_FLAG="/etc/lab/.programs-locked"

  if [ -f /etc/lab/orig-perms.txt ]; then
    while read -r path mode; do
      [ -e "$path" ] || continue
      chmod "$mode" "$path" 2>/dev/null || true
      chown root:root "$path" 2>/dev/null || true
    done < /etc/lab/orig-perms.txt

    rm -f /etc/lab/orig-perms.txt
  fi

  # Garante que binários de navegadores voltem a 755
  IFS=',' read -ra BRS <<< "$BROWSERS"
  for b in "${BRS[@]}"; do
    b="$(echo "$b" | xargs)"
    for p in /usr/bin/"$b" /usr/local/bin/"$b" /snap/bin/"$b"; do
      [ -e "$p" ] && chmod 0755 "$p" 2>/dev/null || true
    done
  done

  # Remove usuários do grupo
  for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    gpasswd -d "$u" lab-browsers 2>/dev/null || true
  done

  rm -f "$PROTECTED_FLAG"
  echo "[programs] revertido."
}

# =====================================================================
#  EXECUÇÃO CONFORME O MODO
# =====================================================================
case "$MODE" in
  sites-only)
    aplicar_sites
    matar_navegadores
    ;;

  programs-only)
    REVERTER_PROGRAMAS   # garante estado limpo antes
    APLICAR_PROGRAMAS
    matar_navegadores
    ;;

  sites-and-programs)
    aplicar_sites
    REVERTER_PROGRAMAS
    APLICAR_PROGRAMAS
    matar_navegadores
    ;;

  *)
    echo "Modo inválido: $MODE" >&2
    exit 2
    ;;
esac

echo "[$(date '+%F %T')] BLOCK concluído (mode=$MODE)" >> "$LOG"
exit 0

#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v11.0.0
#
#  Modos:
#    --sites-only         Bloqueia sites (exceto liberados). Programas livres.
#    --programs-only      Bloqueia todos os programas, exceto navegadores. Sites livres.
#    --sites-and-programs Bloqueia sites (exceto liberados) E programas (exceto navegadores).
#
#  Mudança da v10 → v11:
#    - Bloqueio de programas agora usa APPARMOR (kernel-level)
#      em vez de chmod, que era burlável em /snap, /opt, /usr/lib.
#    - Mantém toda a estrutura da v10 (sites via policies Firefox/Chrome).
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
#  BLOQUEIO DE PROGRAMAS — APPARMOR
#
#  Estratégia:
#    1) Grupo "labusers" agrupa todos os alunos.
#    2) Perfil AppArmor /etc/apparmor.d/lab-restrict define que
#       SOMENTE os navegadores listados podem ser executados.
#    3) pam_apparmor faz o login do aluno já cair dentro do perfil.
#
#  Vantagens vs chmod:
#    - Bloqueia em /snap, /opt, /usr/lib, /home, AppImage
#    - Kernel-level: aluno sem sudo NÃO consegue burlar
#    - Não mexe em permissões de arquivo
#
#  Requisitos (instalados pelo lab-startup.sh):
#    - apparmor, apparmor-utils, pam_apparmor
#    - /etc/apparmor.d/lab-restrict (perfil base)
#    - /etc/apparmor.d/pam_apparmor (mapa grupo → perfil)
#    - linha "session required pam_apparmor.so" em /etc/pam.d/common-session
# =====================================================================

APLICAR_PROGRAMAS() {
  echo "[programs] aplicando AppArmor (lab-restrict)"

  # 0) Sanidade — AppArmor instalado?
  if ! command -v apparmor_parser &>/dev/null; then
    echo "[programs][ERRO] AppArmor não está instalado. Rode lab-startup.sh primeiro." >&2
    return 1
  fi

  # 1) Grupo dos alunos
  getent group labusers >/dev/null || groupadd labusers

  for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    usermod -aG labusers "$u" 2>/dev/null || true
  done

  # 2) Garante que existe o perfil base
  BASE_PROFILE="/etc/apparmor.d/lab-restrict"
  if [ ! -f "$BASE_PROFILE" ]; then
    echo "[programs][ERRO] $BASE_PROFILE não existe. Rode lab-startup.sh primeiro." >&2
    return 1
  fi

  # 3) Gera o perfil "ativo" reescrevendo o bloco de navegadores
  ATIVO="/etc/apparmor.d/lab-restrict.ativo"

  IFS=',' read -ra BRS <<< "$BROWSERS"
  REGRAS_BROWSER=""
  for b in "${BRS[@]}"; do
    b="$(echo "$b" | xargs)"
    [ -z "$b" ] && continue
    REGRAS_BROWSER+="  /usr/bin/$b        ixr,\n"
    REGRAS_BROWSER+="  /usr/local/bin/$b  ixr,\n"
    REGRAS_BROWSER+="  /snap/bin/$b       ixr,\n"
  done

  # Reescreve o perfil copiando tudo, mas substituindo o bloco de
  # navegadores entre "# Navegadores permitidos" e "# Bloqueia execução"
  awk -v regras="$REGRAS_BROWSER" '
    /# Navegadores permitidos/ {
      print
      printf "%b", regras
      skip = 1
      next
    }
    /# Bloqueia execução/ {
      skip = 0
    }
    skip { next }
    { print }
  ' "$BASE_PROFILE" > "$ATIVO"

  chmod 644 "$ATIVO"

  # 4) Carrega (ou recarrega) no kernel
  apparmor_parser -r "$ATIVO"

  # 5) Coloca alunos no grupo labusers
  for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    usermod -aG labusers "$u" 2>/dev/null || true
  done

  echo "[programs] AppArmor ativo. Navegadores permitidos: $BROWSERS"
}

REVERTER_PROGRAMAS() {
  echo "[programs] removendo AppArmor (lab-restrict)"

  ATIVO="/etc/apparmor.d/lab-restrict.ativo"

  # 1) Remove o perfil ativo do kernel
  if [ -f "$ATIVO" ]; then
    apparmor_parser -R "$ATIVO" 2>/dev/null || true
    rm -f "$ATIVO"
  fi

  # 2) Garante que o perfil base também não está carregado
  apparmor_parser -R /etc/apparmor.d/lab-restrict 2>/dev/null || true

  # 3) Remove alunos do grupo
  for u in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    gpasswd -d "$u" labusers 2>/dev/null || true
  done

  echo "[programs] AppArmor removido."
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

#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v8.0.0
#
#  Baixa os scripts do GitHub, compara com os locais, e executa
#  apenas o que mudou. Sem depender de done.txt.
# =====================================================================

set +e

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
LOG="/var/log/lab-startup.log"

mkdir -p /var/log
log() { echo "[$(date '+%F %T')] $1" | tee -a "$LOG"; }

log "========================================="
log " lab-startup.sh v8.0.0"
log "========================================="

# =====================================================================
# Lista de arquivos (removi o lab-aluno-ssh-config.sh que não existe)
# =====================================================================
ARQUIVOS=(
    lab-profile-config.sh
    lab-aluno-config.sh
    lab-programs.sh
    lab-eula-programs.sh
    lab-program-config.sh
    lab-inventory.sh
    lab-admin-profile-config.sh
    lab-block.sh
    lab-block-sites.sh
    lab-unblock.sh
    lab-postlogin-default.sh
    labsecurity-agent.sh
)

# =====================================================================
# 1. Baixa cada arquivo (com validação)
# =====================================================================
log ""
log "==> Baixando scripts do repositório..."

FALHAS=0
for f in "${ARQUIVOS[@]}"; do
    destino="/tmp/$f"
    rm -f "$destino"

    if wget -q "$REPO/$f" -O "$destino" 2>/dev/null; then
        if [ -s "$destino" ]; then
            log "  ✅ $f"
        else
            log "  ❌ $f (vazio)"
            FALHAS=$((FALHAS + 1))
        fi
    else
        log "  ❌ $f (falha no download)"
        FALHAS=$((FALHAS + 1))
    fi
done

# labadmin.pub (opcional)
rm -f /tmp/labadmin.pub
if wget -q "$REPO/labadmin.pub" -O /tmp/labadmin.pub 2>/dev/null; then
    log "  ✅ labadmin.pub"
fi

if [ "$FALHAS" -gt 0 ]; then
    log "⚠️  $FALHAS arquivo(s) falharam no download"
fi

# =====================================================================
# 2. Compara com os locais (sempre, sem depender de done.txt)
# =====================================================================
log ""
log "==> Comparando com os locais..."

PRECISA_ATUALIZAR=false
MUDARAM=()

for f in "${ARQUIVOS[@]}"; do
    if [ ! -f "/tmp/$f" ]; then
        continue
    fi

    local_file="/usr/local/sbin/$f"

    if [ ! -f "$local_file" ]; then
        log "  ➕ NOVO: $f"
        PRECISA_ATUALIZAR=true
        MUDARAM+=("$f")
    elif ! cmp -s "$local_file" "/tmp/$f"; then
        log "  🔄 MUDOU: $f"
        PRECISA_ATUALIZAR=true
        MUDARAM+=("$f")
    else
        log "  ✅ igual: $f"
    fi
done

if [ "$PRECISA_ATUALIZAR" = false ]; then
    log ""
    log "✅ Nada mudou — pulando execução"
    exit 0
fi

# =====================================================================
# 3. Copia
# =====================================================================
log ""
log "==> Atualizando ${#MUDARAM[@]} arquivo(s)..."

for f in "${ARQUIVOS[@]}"; do
    if [ -f "/tmp/$f" ]; then
        cp "/tmp/$f" "/usr/local/sbin/$f"
        chmod 755 "/usr/local/sbin/$f"
    fi
done

# labadmin.pub
if [ -f /tmp/labadmin.pub ]; then
    cp /tmp/labadmin.pub /usr/local/sbin/labadmin.pub
    chmod 644 /usr/local/sbin/labadmin.pub
fi

log "  ✅ Copiados"

# =====================================================================
# 4. PostLogin
# =====================================================================
if [ -f /usr/local/sbin/lab-postlogin-default.sh ]; then
    mkdir -p /etc/gdm3/PostLogin
    cp /usr/local/sbin/lab-postlogin-default.sh /etc/gdm3/PostLogin/Default
    chmod a+x /etc/gdm3/PostLogin/Default
    log "  ✅ PostLogin atualizado"
fi

# =====================================================================
# 5. Executa os scripts
# =====================================================================
log ""
log "==> Executando scripts de configuração..."

for s in lab-profile-config lab-aluno-config lab-programs \
         lab-eula-programs lab-program-config lab-inventory \
         lab-admin-profile-config; do

    if [ -x "/usr/local/sbin/$s.sh" ]; then
        log "▶️  Executando $s.sh"
        "/usr/local/sbin/$s.sh" >> "$LOG" 2>&1
        log "  exit=$?"
    else
        log "⚠️  $s.sh não existe — pulando"
    fi
done

# =====================================================================
# 6. LabSecurity Agent
# =====================================================================
if [ -f /usr/local/sbin/labsecurity-agent.sh ]; then
    log ""
    log "==> Configurando LabSecurity Agent..."

    cat > /etc/systemd/system/labsecurity-agent.service << 'EOF'
[Unit]
Description=LabSecurity Monitoring Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/sbin/labsecurity-agent.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable labsecurity-agent.service 2>/dev/null
    systemctl restart labsecurity-agent.service 2>/dev/null

    if systemctl is-active --quiet labsecurity-agent.service; then
        log "  ✅ LabSecurity Agent rodando"
    else
        log "  ⚠️ LabSecurity Agent falhou"
    fi
fi

log ""
log "========================================="
log " ✅ lab-startup.sh concluído"
log "========================================="

exit 0

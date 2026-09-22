#!/bin/bash
# =====================================================================
#  lab-startup.sh
#  v9.0.0
#
#  SEMPRE roda o lab-programs.sh (que tem selos).
#  O lab-programs.sh decide o que precisa ser instalado.
# =====================================================================

set +e

REPO="https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main"
LOG="/var/log/lab-startup.log"

mkdir -p /var/log
log() { echo "[$(date '+%F %T')] $1" | tee -a "$LOG"; }

log "========================================="
log " lab-startup.sh v9.0.0"
log "========================================="

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
# 1. Baixa os scripts
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

if [ "$FALHAS" -gt 0 ]; then
    log "⚠️  $FALHAS arquivo(s) falharam no download"
fi

# =====================================================================
# 2. Copia os que mudaram (mas não decide nada)
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

    if [ ! -f "$local_file" ] || ! cmp -s "$local_file" "/tmp/$f"; then
        log "  🔄 $f"
        PRECISA_ATUALIZAR=true
        MUDARAM+=("$f")
    fi
done

if [ "$PRECISA_ATUALIZAR" = true ]; then
    log ""
    log "==> Atualizando ${#MUDARAM[@]} arquivo(s)..."

    for f in "${ARQUIVOS[@]}"; do
        if [ -f "/tmp/$f" ]; then
            cp "/tmp/$f" "/usr/local/sbin/$f"
            chmod 755 "/usr/local/sbin/$f"
        fi
    done
    log "  ✅ Copiados"
fi

# =====================================================================
# 3. PostLogin
# =====================================================================
if [ -f /usr/local/sbin/lab-postlogin-default.sh ]; then
    mkdir -p /etc/gdm3/PostLogin
    cp /usr/local/sbin/lab-postlogin-default.sh /etc/gdm3/PostLogin/Default
    chmod a+x /etc/gdm3/PostLogin/Default
fi

# =====================================================================
# 4. ⭐ SEMPRE roda o lab-programs.sh
# =====================================================================
#  O lab-programs.sh tem selos. Ele só instala o que falta.
#  Se um programa falhou no boot anterior, o selo não existe,
#  então ele tenta de novo AGORA.

log ""
log "==> Rodando lab-programs.sh (sempre — selos decidem o que instalar)"
log "    Isso garante que programas que falharam sejam retentados."

if [ -x /usr/local/sbin/lab-programs.sh ]; then
    /usr/local/sbin/lab-programs.sh >> "$LOG" 2>&1
    log "  lab-programs.sh exit=$?"
else
    log "  ⚠️ lab-programs.sh não existe"
fi

# =====================================================================
# 5. Roda os outros scripts (só os de configuração)
# =====================================================================
log ""
log "==> Executando scripts de configuração..."

for s in lab-profile-config lab-aluno-config \
         lab-eula-programs lab-program-config lab-inventory \
         lab-admin-profile-config; do

    if [ -x "/usr/local/sbin/$s.sh" ]; then
        log "▶️  $s.sh"
        "/usr/local/sbin/$s.sh" >> "$LOG" 2>&1
    fi
done

# =====================================================================
# 6. LabSecurity Agent
# =====================================================================
if [ -f /usr/local/sbin/labsecurity-agent.sh ]; then
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
fi

log ""
log "========================================="
log " ✅ lab-startup.sh concluído"
log "========================================="

exit 0

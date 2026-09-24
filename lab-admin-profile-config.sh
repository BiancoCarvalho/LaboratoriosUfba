#!/bin/bash
# =====================================================================
#  lab-admin-profile-config.sh
#  v4.0.0
#
#  Mudanças em relação à v3.2.0:
#    - ⭐ set -euo pipefail (aborta em erro)
#    - ⭐ Escrita atômica de arquivos (mv em vez de >)
#    - ⭐ Validação após cada etapa
#    - ⭐ Verifica permissões do .ssh e authorized_keys
#    - ⭐ Log estruturado
# =====================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

USUARIO="nati"
SENHA='@PNZ!2026'
LOG="/var/log/lab.log"

CHAVE_PUBLICA="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohJ7/PEW4OlfVwLcI0pZMmK0nsy05PLfYPiPCGSl6c servidor-lab@universidade"

log() {
    echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE: $*" >> "$LOG"
}

erro() {
    echo "[$(date '+%F %T')] host=$(hostname) ADMIN-PROFILE ERRO: $*" >> "$LOG"
    echo "ERRO: $*" >&2
}

# ---------------------------------------------------------------------
# Função helper: escreve arquivo de forma ATÔMICA e valida
# ---------------------------------------------------------------------
escrever_atomico() {
    local destino="$1"
    local conteudo="$2"
    local validador="$3"  # string que DEVE estar no arquivo

    local tmp="/tmp/.atomic-$$"

    # Escreve no temporário
    printf '%s\n' "$conteudo" > "$tmp"

    # Valida o temporário
    if ! grep -qF "$validador" "$tmp"; then
        erro "conteúdo não contém '$validador' no temporário"
        rm -f "$tmp"
        return 1
    fi

    # Move (atômico) para o destino
    mv "$tmp" "$destino"

    # Valida o destino
    if ! grep -qF "$validador" "$destino"; then
        erro "conteúdo não contém '$validador' no destino"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------
# Função helper: aplica permissões e VERIFICA
# ---------------------------------------------------------------------
aplicar_permissoes() {
    local arquivo="$1"
    local perm="$2"
    local dono="$3"

    chmod "$perm" "$arquivo" || { erro "chmod $perm em $arquivo"; return 1; }
    chown "$dono" "$arquivo" || { erro "chown $dono em $arquivo"; return 1; }

    # Verifica
    local perm_real=$(stat -c%a "$arquivo")
    local dono_real=$(stat -c%U "$arquivo")

    if [ "$perm_real" != "$perm" ]; then
        erro "$arquivo: permissão $perm_real, esperado $perm"
        return 1
    fi

    if [ "$dono_real" != "${dono%:*}" ]; then
        erro "$arquivo: dono $dono_real, esperado ${dono%:*}"
        return 1
    fi

    return 0
}

log "iniciado"

# ---------------------------------------------------------------------
# 1) Cria o usuário SOMENTE se não existir
# ---------------------------------------------------------------------
if id "$USUARIO" &>/dev/null; then
    log "usuário $USUARIO já existe"
else
    log "criando usuário $USUARIO..."
    useradd --create-home --shell /bin/bash "$USUARIO" || { erro "falha ao criar $USUARIO"; exit 1; }
    log "usuário $USUARIO criado"
fi

# Garante senha
echo "$USUARIO:$SENHA" | chpasswd || { erro "falha ao definir senha"; exit 1; }

# Garante grupo sudo
usermod -aG sudo "$USUARIO" 2>/dev/null || true

# ---------------------------------------------------------------------
# 2) Chave SSH do nati — ATÔMICO e VALIDADO
# ---------------------------------------------------------------------
log "configurando chave SSH do $USUARIO"

mkdir -p "/home/$USUARIO/.ssh"
aplicar_permissoes "/home/$USUARIO/.ssh" "700" "$USUARIO:$USUARIO" || exit 1

# Escreve ATÔMICO e VALIDA
escrever_atomico \
    "/home/$USUARIO/.ssh/authorized_keys" \
    "$CHAVE_PUBLICA" \
    "servidor-lab@universidade" || exit 1

aplicar_permissoes "/home/$USUARIO/.ssh/authorized_keys" "600" "$USUARIO:$USUARIO" || exit 1

# Home acessível
aplicar_permissoes "/home/$USUARIO" "755" "$USUARIO:$USUARIO" || exit 1

# Garante SSH rodando
systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true

# ⭐ Valida que o SSH está rodando
if ! systemctl is-active --quiet ssh; then
    erro "SSH não está rodando"
    exit 1
fi

log "chave SSH configurada e validada"

# ---------------------------------------------------------------------
# 3) Sudoers do nati — ATÔMICO e VALIDADO
# ---------------------------------------------------------------------
log "configurando sudoers do $USUARIO"

SUDOERS_FILE="/etc/sudoers.d/nati-lab"
rm -f /etc/sudoers.d/NATI /etc/sudoers.d/nati-admin /etc/sudoers.d/nati-lab

SUDOERS_CONTENT=$(cat <<EOF
# $USUARIO - administrador do laboratorio
Defaults:$USUARIO !requiretty

# Pacotes (apt)
$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg

# Scripts do ServidorLab
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-sites.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-status.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-ipset-update.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-block-terminal.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-unblock-terminal.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-prova-install.sh
$USUARIO ALL=(ALL) NOPASSWD: /usr/local/sbin/lab-startup.sh
EOF
)

# Escreve ATÔMICO
TMP_SUDOERS="/tmp/.sudoers-$$"
printf '%s\n' "$SUDOERS_CONTENT" > "$TMP_SUDOERS"

# ⭐ Valida ANTES de mover
if ! visudo -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
    erro "sudoers inválido — não será aplicado"
    rm -f "$TMP_SUDOERS"
    exit 1
fi

# Move (atômico)
mv "$TMP_SUDOERS" "$SUDOERS_FILE"
aplicar_permissoes "$SUDOERS_FILE" "440" "root:root" || exit 1

# ⭐ Valida DEPOIS
if ! visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
    erro "sudoers inválido após mover"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

log "sudoers configurado e validado"

# ---------------------------------------------------------------------
# 4) Remove o ALUNO do sudo
# ---------------------------------------------------------------------
deluser aluno sudo 2>/dev/null || true
gpasswd -d aluno sudo 2>/dev/null || true
rm -f /etc/sudoers.d/aluno-ssh

log "aluno removido do sudo"

# ---------------------------------------------------------------------
# 5) Remove 'suporte' se existir
# ---------------------------------------------------------------------
if id "suporte" &>/dev/null; then
    pkill -9 -u "suporte" 2>/dev/null || true
    userdel -r "suporte" 2>/dev/null || true
    log "usuário suporte removido"
fi

# ---------------------------------------------------------------------
# 6) Validação final — tudo funciona?
# ---------------------------------------------------------------------
log "=== VALIDAÇÃO FINAL ==="

# 6.1 — authorized_keys do nati
if ! grep -qF "servidor-lab@universidade" "/home/$USUARIO/.ssh/authorized_keys"; then
    erro "authorized_keys do nati não tem a chave"
    exit 1
fi
log "OK: authorized_keys do nati tem a chave"

# 6.2 — permissões
PERM=$(stat -c%a "/home/$USUARIO/.ssh/authorized_keys")
if [ "$PERM" != "600" ]; then
    erro "authorized_keys do nati tem permissão $PERM"
    exit 1
fi
log "OK: authorized_keys do nati tem permissão 600"

# 6.3 — sudoers
if ! sudo -n -l -U "$USUARIO" >/dev/null 2>&1; then
    erro "sudoers do nati não funciona"
    exit 1
fi
log "OK: sudoers do nati funciona"

# 6.4 — aluno NÃO tem sudo
if groups aluno 2>/dev/null | grep -q sudo; then
    erro "aluno AINDA está no grupo sudo"
    exit 1
fi
log "OK: aluno NÃO tem sudo"

log "concluído com sucesso"
exit 0

#!/bin/bash
# =====================================================================
#  lab-block.sh
#  v4.0.0
#
#  Ativa o "modo prova":
#    - Cria o usuário 'prova' (se não existe)
#    - Aplica policies.json no perfil do 'prova'
#    - Bloqueia todos os sites, exceto o JUDE
#
#  NÃO abre o Firefox. O aluno abre normalmente quando quiser.
#
#  Localização: /usr/local/sbin/lab-block.sh
#  Uso: sudo /usr/local/sbin/lab-block.sh
# =====================================================================

set -e

USUARIO="prova"
LOG="/var/log/lab.log"

echo "[$(date '+%F %T')] host=$(hostname) BLOCK" >> "$LOG"

# 1) Cria o usuário 'prova' (ou recria)
/usr/local/sbin/lab-prova-profile-config.sh

# 2) Aplica as policies no perfil do 'prova'
/usr/local/sbin/lab-prova-config.sh

echo "[$(date '+%F %T')] BLOCK concluído" >> "$LOG"
exit 0

#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

USUARIO="NATI"
SENHA="@PNZ!2026"

# Verifica se o usuário já existe
if id "$USUARIO" &>/dev/null; then
    echo "O usuário $USUARIO já existe. Removendo..."
    sudo pkill -u "$USUARIO"
    sudo userdel -r "$USUARIO"
    sleep 2
fi

echo "Criando usuário $USUARIO..."
sudo useradd --create-home --shell /bin/bash "$USUARIO"
echo "$USUARIO:$SENHA" | sudo chpasswd
sudo usermod -aG sudo "$USUARIO"
echo "Usuário $USUARIO criado e adicionado ao grupo sudo."

# Adiciona regras no sudoers para restringir comandos
grep -q "$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/dpkg" /etc/sudoers || \
    echo "$USUARIO ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/dpkg" | sudo tee -a /etc/sudoers

grep -q "$USUARIO ALL=(ALL) !/usr/sbin/useradd, !/usr/sbin/userdel" /etc/sudoers || \
    echo "$USUARIO ALL=(ALL) !/usr/sbin/useradd, !/usr/sbin/userdel" | sudo tee -a /etc/sudoers

# Remove usuário suporte se existir
if id "suporte" &>/dev/null; then
    sudo userdel -r suporte
    echo "Usuário suporte removido."
fi

exit 0

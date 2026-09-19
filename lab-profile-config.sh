#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

#########
# Desativa IPv6

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

#configura dns ipv4

device=$(nmcli -t -f Name c show --active)
nmcli connection modify "$device" ipv4.method auto
nmcli connection modify "$device" ipv4.dns ""
echo "Conexão:${device}"

# Configura rotação de logs teste

cat <<EOF > /etc/logrotate.d/custom_logs
/var/log/syslog /var/log/kern.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 0644 root root
    size 200M
    sharedscripts
    postrotate
    endscript
}
EOF
logrotate -f /etc/logrotate.d/custom_logs

echo "Logrotate configuration has been set up successfully."

############### Criação do usuário aluno ###############

#Removendo lixo
if [ -f /etc/skel/set-wallpaper.sh ]; then
rm /etc/skel/set-wallpaper.sh
fi

if  [ -f /etc/profile.d/autologout.sh ]; then
sudo rm -f /etc/profile.d/autologout.sh
fi

if [ -f /etc/profile.d/confif_display.sh ]; then
sudo rm /etc/profile.d/confif_display.sh
fi

#Configuração do display
if ! [ -f /usr/share/backgrounds/tomorrow.png ]; then
wget "https://drive.google.com/uc?export=download&id=1wafIeHXEffGtEbRNfBcsNisgLdNXoqWq" -O /usr/share/backgrounds/tomorrow.png
fi

if ! [ -f /etc/profile.d/config_display.sh ]; then
echo "gsettings set org.gnome.desktop.background picture-uri file:///usr/share/backgrounds/tomorrow.png
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'logout'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 7200
gsettings set org.gnome.desktop.session idle-delay 0
" > /etc/profile.d/config_display.sh
chmod a+x /etc/profile.d/config_display.sh
fi

#Configuração de desligamento das máquinas
PATH_TO_SHUTDOWN=$(which shutdown)
TARGET_HOUR="33 22 * * * root "$PATH_TO_SHUTDOWN" -h now"
FILE="/etc/crontab"

if ! grep -q -x -F "$TARGET_HOUR" "$FILE"
then
        echo "$TARGET_HOUR" >> /etc/crontab
fi


# Pula configuração do Ubuntu pelo usuário novo
rm -f /usr/share/applications/gnome-online-accounts-panel.desktop
mkdir -p /etc/skel/.config
echo 'yes' > /etc/skel/.config/gnome-initial-setup-done


# Cria usuário aluno e define senha
if id aluno &> /dev/null; then
  echo ok
else
  useradd --create-home --password "vivaoic2021!" -s /bin/bash aluno
fi
echo "aluno:vivaoic2021!" | chpasswd

exit 0
echo '#!/bin/sh
wget https://raw.githubusercontent.com/graco-ufba/lab-scripts/main/lab-startup.sh -O /tmp/startup.sh
chmod a+x /tmp/startup.sh
/tmp/startup.sh
exit 0
' > /root/labstartup.sh
chmod a+x /root/labstartup.sh

echo '[Unit]
Description=Atualiza instalacao dos labs
Wants=network-online.target
After=network.target network-online.target

[Service]
ExecStart=/root/labstartup.sh
Type=oneshot
Restart=on-failure
RestartSec=20

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/labstartup.service

sudo systemctl daemon-reload
sudo systemctl enable labstartup.service

#!/bin/bash

export DEBIAN_FRONTEND=noninteractive


#Configuração de libs do R
if [[ -f /usr/lib/R/site-library/done.txt || -f /usr/local/lib/R/site-library/done.txt ]]; then
sudo apt install libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev -y
sudo chmod 777 /usr/lib/R/site-library
Rscript -e 'install.packages("tidyverse")'
Rscript -e 'install.packages("shiny")'
Rscript -e 'install.packages("shinydashboard")'
sudo touch /usr/lib/R/site-library/done.txt
sudo touch /usr/local/lib/R/site-library/done.txt
fi

#podman-compose
sudo -H pip install podman-compose

#virtualbox
sudo mkdir -p /opt/VMs
vboxmanage setproperty machinefolder "/opt/VMs"

#unityhub
if ! [ -d /opt/Unity ]; then
sudo mkdir /opt/Unity
sudo chmod a+rwx /opt/Unity
fi


exit 0

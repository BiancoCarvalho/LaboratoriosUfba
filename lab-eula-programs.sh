#!/bin/bash

export DEBIAN_FRONTEND=noninteractive


# VirtualBox
#sudo apt-get install mokutil
#SBDISABLED=$(mokutil --sb)
#if [ "$SBDISABLED" = "SecureBoot disabled" ]; then
#    sudo apt install virtualbox -y
#    echo virtualbox-ext-pack virtualbox-ext-pack/license select "true" | sudo debconf-set-selections
#    sudo apt install virtualbox-ext-pack -y
#fi

sudo apt-get install mokutil -y
SBDISABLED=$(mokutil --sb)

if [ "$SBDISABLED" = "SecureBoot disabled" ]; then
    echo "Removendo versões antigas do VirtualBox..."
    sudo apt remove --purge virtualbox virtualbox-6.1 virtualbox-6.0 virtualbox-5.* -y
    sudo apt autoremove -y

    echo "Adicionando repositório oficial do VirtualBox 7.x..."
    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo tee /etc/apt/trusted.gpg.d/oracle_vbox_2016.asc
    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo tee /etc/apt/trusted.gpg.d/oracle_vbox.asc
    echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list

    sudo apt update
    sudo apt install -y virtualbox-7.0

    echo "Instalando o Extension Pack do VirtualBox 7..."
    VBOX_VERSION=$(VBoxManage -v | cut -dr -f1)
    wget "https://download.virtualbox.org/virtualbox/$VBOX_VERSION/Oracle_VM_VirtualBox_Extension_Pack-$VBOX_VERSION.vbox-extpack" -O /tmp/extension_pack.vbox-extpack
    sudo VBoxManage extpack install --replace /tmp/extension_pack.vbox-extpack
    rm /tmp/extension_pack.vbox-extpack
fi

#wireshark
if ! [ -f /usr/local/sbin/wire.sh ]; then
sudo apt remove wireshark -y
sudo apt autoremove -y
echo PURGE | sudo debconf-communicate wireshark-common

sudo touch /usr/local/sbin/wire.sh
echo wireshark-common wireshark-common/install-setuid select "true" | sudo debconf-set-selections
sudo apt install wireshark -y
sudo usermod -aG wireshark aluno
sudo chmod +x /usr/bin/dumpcap
fi

#CiscoPacketTracer
if ! [ -d /opt/pt ]; then
wget "https://www.dropbox.com/scl/fi/fpexy62c8mybh10k1u5h1/Packet_Tracer822_amd64_signed.deb?rlkey=1hvmun574d7p6ud4ey32xwl2j&st=6dnoy373&dl=1" -O /opt/cisco.deb
cd /opt
echo PacketTracer PacketTracer_822_amd64/accept-eula select "true" | sudo debconf-set-selections
echo PacketTracer PacketTracer_822_amd64/show-eula select "false" | sudo debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg -i cisco.deb
sudo apt install -f -y
DEBIAN_FRONTEND=noninteractive dpkg -i cisco.deb
sudo rm cisco.deb
sudo wget "https://drive.google.com/uc?export=download&id=1L01Mg96hWRpeI9LNOqzugmsSod7vza0O" -O /etc/skel/pt.zip
cd /etc/skel
sudo unzip pt.zip
sudo rm /etc/skel/pt.zip
fi

# Instalação do Android SDK, Android Studio (via Snap) e Gradle
if ! [ -f /usr/local/sbin/android.sh ]; then
  echo "Instalando Android SDK, Android Studio e Gradle..."

  # Instala o Android SDK
  if [[ ! -d /opt/Android ]]; then
    echo "Baixando Android SDK..."
    wget https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download --no-check-certificate -O /tmp/Android.tar.bz2

    echo "Extraindo Android SDK em /opt..."
    cd /opt || exit 1
    sudo tar xjf /tmp/Android.tar.bz2
    rm /tmp/Android.tar.bz2

    echo "Criando link simbólico em /etc/skel..."
    cd /etc/skel || exit 1
    sudo unlink Android 2>/dev/null
    sudo ln -s /opt/Android Android
  fi

  # Instala o Android Studio via Snap
  if ! snap list | grep -q android-studio; then
    echo "Instalando Android Studio via Snap..."
    sudo snap install android-studio --classic
  else
    echo "Android Studio já está instalado via Snap."
  fi

  # Instala o Gradle
  if [[ ! -d /opt/gradle ]]; then
    echo "Baixando Gradle..."
    wget https://nuvem.ufba.br/s/U5anBL3tRpN2xhT/download --no-check-certificate -O /tmp/gradle.tar.bz2

    echo "Extraindo Gradle em /opt..."
    cd /opt || exit 1
    sudo tar xjf /tmp/gradle.tar.bz2
    sudo mv .gradle gradle
    sudo chown -R aluno:aluno gradle
    rm /tmp/gradle.tar.bz2
  fi

  # Marca que o Android Studio foi instalado
  sudo touch /usr/local/sbin/android.sh

  echo "Android Studio instalado com sucesso."
else
  echo "Android Studio já está instalado (/usr/local/sbin/android.sh encontrado)."
fi

exit 0

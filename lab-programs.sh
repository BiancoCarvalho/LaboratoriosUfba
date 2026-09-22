#!/bin/bash

# Configuração inicial
export DEBIAN_FRONTEND=noninteractive

# ==============================
# BLOQUEAR MÓDULO algif_aead (Copy Fail CVE-2026-31431)
# ==============================

# Função para verificar instalação
check_install() {
    if command -v $1 &>/dev/null; then
        echo "[SUCESSO] $1 instalado corretamente"
        return 0
    else
        echo "[ERRO] Falha ao instalar $1"
        return 1
    fi
}


echo "Configurando bloqueio do módulo algif_aead..."

CONF="/etc/modprobe.d/manual-disable-algif_aead.conf"

if ! grep -q "algif_aead" "$CONF" 2>/dev/null; then
    echo "install algif_aead /bin/false" > "$CONF"
    echo "blacklist algif_aead" >> "$CONF"
    update-initramfs -u
    echo "✔ Bloqueio aplicado"
else
    echo "✔ Já configurado"
fi

# aplicar imediatamente (opcional)
rmmod algif_aead 2>/dev/null || true


# Corrigir erro "check-new-release-gtk crashed with apt_pkg"
echo "Corrigindo possíveis problemas no release upgrader..."
sudo apt-get update -y
sudo apt-get install --reinstall -y ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk python3-apt
sudo apt --fix-broken install -y
sudo dpkg --configure -a
sudo apt autoremove -y

# Desabilitar popups de atualização de versão do Ubuntu
echo "Desabilitando notificações de atualização de versão do Ubuntu..."
sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
gsettings set com.ubuntu.update-notifier show-livepatch-status false 2>/dev/null || true
gsettings set com.ubuntu.update-notifier auto-launch false 2>/dev/null || true
sudo systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service
sudo -E apt-get update -y
sudo -E apt-get install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg

# Instalar Quarto
QUARTO_VERSION="1.8.24"
QUARTO_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb"
if ! command -v quarto &>/dev/null; then
    wget -O /tmp/quarto.deb "$QUARTO_URL"
    sudo dpkg -i /tmp/quarto.deb || sudo apt-get -f install -y
    rm /tmp/quarto.deb
fi
check_install quarto

# Atualização do sistema
echo "Atualizando sistema..."
sudo -E apt-get update -y
sudo -E apt-get upgrade -y
sudo -E apt-get dist-upgrade -y
sudo -E apt-get autoremove -y
sudo -E apt-get install -f -y

# Instalar ClamAV (antivirus) e ClamTK (interface gráfica)
echo "Instalando ClamAV e ClamTK..."
sudo -E apt-get update -y
sudo -E apt-get install -y clamav freshclam clamtk
sudo freshclam  # Atualiza as definições de vírus
check_install clamscan
check_install clamtk

# Instalar Termius
#TERMIUS_URL="https://www.termius.com/download/linux/Termius.deb"
#if [ ! -f ./termius_current.deb ]; then
#    wget -O termius_current.deb "$TERMIUS_URL"
#fi
#sudo dpkg -i ./termius_current.deb || sudo apt-get -f install -y
#sudo chown root:root /opt/Termius/chrome-sandbox
#sudo chmod 4755 /opt/Termius/chrome-sandbox
#check_install termius
#echo "Atualizacao finalizada."

 #SRemovendo Termius
echo "Removendo Termius..."

if dpkg -l | grep -q termius-app; then
    sudo apt-get purge -y termius-app
    sudo apt-get autoremove -y
else
    echo "Pacote termius-app não encontrado. Removendo manualmente..."
    sudo rm -rf /opt/Termius
    sudo rm -f /usr/share/applications/termius.desktop
    sudo rm -f /usr/bin/termius
fi

echo "Termius removido com sucesso."

# Instalar Jupyter
echo "Instalando Jupyter..."
pip install jupyter -q
check_install jupyter

# Instalar Docker
echo "Instalando Docker..."
# Instalar dependências necessárias
sudo apt-get install -y ca-certificates curl gnupg lsb-release
# Criar diretório para chave GPG do Docker (com permissão adequada)
sudo mkdir -p /etc/apt/keyrings
# Baixar e adicionar a chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# Adicionar o repositório oficial do Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Atualizar a lista de pacotes
sudo apt-get update -y
# Instalar os pacotes Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Adicionar o usuário correto ao grupo docker para permitir usar docker sem sudo
USERNAME=${SUDO_USER:-$USER}
sudo usermod -aG docker $USERNAME
echo "Docker instalado e usuário $USERNAME adicionado ao grupo docker. Faça logout/login para aplicar as permissões."
# Verificar instalação
check_install docker

# Instalar AVRA (Assembler para AVR)
#echo "Instalando AVRA..."
#sudo -E apt-get update -y
#sudo -E apt-get install -y avra
#check_install avra

# --- Instalar a versão 1.3.0 do SourceForge ---
echo "Instalando AVRA 1.3.0 (SourceForge)..."
sudo apt-get install -y build-essential wget bzip2
cd /tmp
wget https://downloads.sourceforge.net/project/avra/1.3.0/avra-1.3.0.tar.bz2
tar -xjf avra-1.3.0.tar.bz2
cd avra-1.3.0
make
sudo make install
check_install avra

# Instalar Ollama
echo "Instalando Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
check_install ollama


# Instalar Sublime Text
echo "Instalando Sublime Text..."
curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/sublime-text-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/sublime-text-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo -E apt-get update -y
sudo -E apt-get install -y sublime-text
check_install subl

# Instalar Neofetch
echo "Instalando Neofetch..."
sudo -E apt-get install -y neofetch
check_install neofetch

# Instalar Visual Studio Code
echo "Instalando Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo -E apt-get update -y
sudo -E apt-get install -y code
check_install code

# Instalar OBS Studio
echo "Instalando OBS Studio..."
sudo add-apt-repository -y ppa:obsproject/obs-studio
sudo -E apt-get update -y
sudo -E apt-get install -y obs-studio v4l2loopback-dkms
check_install obs

# Instalar pacotes essenciais
echo "Instalando pacotes essenciais..."
sudo -E apt-get install -y \
    python3-pip default-jre default-jdk maven swi-prolog racket elixir clisp nasm gcc-multilib \
    python3.11-full python3.10-venv \
    git flex bison vim sasm \
    mysql-server postgresql postgresql-contrib \
    arp-scan net-tools mtr dnsutils traceroute curl \
    gnupg ca-certificates podman megatools

    # Instalar GNU Octave
    echo "Instalando GNU Octave..."
    sudo -E apt-get install -y octave
    check_install octave

    # Atualizar Racket se necessário (versão oficial do site)
echo "Verificando Racket..."

LATEST_RACKET_URL=$(curl -s https://download.racket-lang.org/ | grep -oP 'https://[^"]+linux-x64.sh' | head -n 1)

if [ ! -z "$LATEST_RACKET_URL" ]; then
    echo "Baixando e instalando a versão mais recente do Racket..."
    wget -O /tmp/racket-install.sh "$LATEST_RACKET_URL"
    chmod +x /tmp/racket-install.sh
    sudo /tmp/racket-install.sh --in-place --dest /opt/racket
    sudo ln -sf /opt/racket/bin/racket /usr/local/bin/racket
    rm /tmp/racket-install.sh
fi

check_install racket

# Verificar e atualizar SWI-Prolog a partir do repositório oficial
echo "Verificando SWI-Prolog..."
sudo add-apt-repository -y ppa:swi-prolog/stable
sudo -E apt-get update -y
sudo -E apt-get install -y swi-prolog
check_install swipl


# Configurar PostgreSQL 17
echo "Instalando PostgreSQL 17..."
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo -E apt-get update -y
sudo -E apt-get install -y postgresql-17 postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
check_install psql

# Instalar pgAdmin
echo "Instalando pgAdmin..."
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo -E apt-get update -y
sudo -E apt-get install -y pgadmin4-web pgadmin4-desktop

# Instalar MySQL Workbench
echo "Instalando MySQL Workbench..."
wget http://cdn.mysql.com/Downloads/MySQLGUITools/mysql-workbench-community_8.0.34-1ubuntu22.04_amd64.deb -O /tmp/mysql-workbench.deb
sudo -E dpkg -i /tmp/mysql-workbench.deb || sudo -E apt-get -f install -y
rm /tmp/mysql-workbench.deb
check_install mysql-workbench

# Instalar NetBeans via Snap
echo "Instalando NetBeans..."
sudo -E apt-get install -y openjdk-17-jdk
sudo snap install netbeans --classic
check_install netbeans

# Instalar Greenfoot via Snap
echo "Instalando Greenfoot..."
sudo snap install greenfoot
check_install greenfoot

# Instalar SimulIDE
echo "Instalando SimulIDE..."
sudo -E apt-get install -y fuse libfuse2 libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5svg5 qtbase5-dev qttools5-dev-tools libqt5serialport5 libqt5serialport5-dev
if [ ! -f /usr/local/bin/simulide ]; then
    megadl "https://mega.nz/file/8akRDCYJ#8Fvn6U9RIJ-sX_f49fCsn05YTUr5ySNycoFlxVFX-iE" -o /tmp/SimulIDE.tar.gz
    tar -xzvf /tmp/SimulIDE.tar.gz -C /opt
    chmod +x /opt/SimulIDE_1.1.0-SR1_Lin64/simulide
    ln -sf /opt/SimulIDE_1.1.0-SR1_Lin64/simulide /usr/local/bin/simulide
    rm /tmp/SimulIDE.tar.gz
fi
check_install simulide

# Instalar Arduino IDE
echo "Instalando Arduino IDE..."
sudo snap install arduino
sudo usermod -a -G dialout $USER
check_install arduino

# Instalar Wine
echo "Instalando Wine..."
sudo -E apt-get install -y wine64
check_install wine

# Instalar MongoDB
echo "Instalando MongoDB..."
if ! [ -f /etc/mongod.conf ]; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo -E apt-get update -y
    sudo -E apt-get install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
fi
check_install mongo

# Instalar R e RStudio
echo "Instalando R e RStudio..."
sudo -E apt-get install -y --no-install-recommends software-properties-common dirmngr
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
sudo -E apt-get update -y
sudo -E apt-get install -y --no-install-recommends r-base r-base-dev
wget https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.04.2-764-amd64.deb -O /tmp/rstudio.deb
sudo -E gdebi -n /tmp/rstudio.deb
rm /tmp/rstudio.deb
check_install R
check_install rstudio

# Instalar Node.js
echo "Instalando Node.js..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo -E apt-get update -y
sudo -E apt-get install -y nodejs
mkdir -p /opt/npm
chown -R $USER:$USER /opt/npm
npm install -g @angular/cli
check_install node

# Configurar Python
echo "Configurando Python..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
sudo -E apt-get install -y python3.10-venv python3.11-venv

# Instalar snaps
echo "Instalando snaps..."
sudo snap install eclipse --classic
sudo snap install intellij-idea-community --classic
sudo snap install mongo33
sudo snap install bluej

# Instalar Flutter
echo "Instalando Flutter..."
if [ ! -d "/opt/flutter" ]; then
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.5-stable.tar.xz -O /tmp/flutter.tar.xz
    tar xf /tmp/flutter.tar.xz -C /opt
    chown -R $USER:$USER /opt/flutter
    rm /tmp/flutter.tar.xz
    echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
fi
check_install flutter

# Instalar Nand2Tetris
echo "Instalando Nand2Tetris..."
if [ ! -d "/opt/nand2tetris" ]; then
    wget --no-check-certificate https://nuvem.ufba.br/s/ykUB6F81M5z2Ef1/download -O /tmp/nand2tetris.zip
    unzip /tmp/nand2tetris.zip -d /opt
    rm /tmp/nand2tetris.zip
fi

# Instalar Google Chrome
echo "Instalando Google Chrome..."
if ! command -v google-chrome &>/dev/null; then
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo -E dpkg -i /tmp/chrome.deb || sudo -E apt-get -f install -y
    rm /tmp/chrome.deb
fi
check_install google-chrome

# Instalar Android Studio e SDK
echo "Instalando Android Studio..."
if ! [ -f /usr/local/sbin/android.sh ]; then
    # Android SDK
    if [[ ! -d /opt/Android ]]; then
        wget https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download -O /tmp/Android.tar.bz2
        tar xjf /tmp/Android.tar.bz2 -C /opt
        rm /tmp/Android.tar.bz2
        ln -sf /opt/Android $HOME/Android
    fi

    # Android Studio via Snap
    if ! snap list | grep -q android-studio; then
        sudo snap install android-studio --classic
    fi

    # Gradle
    if [[ ! -d /opt/gradle ]]; then
        wget https://nuvem.ufba.br/s/U5anBL3tRpN2xhT/download -O /tmp/gradle.tar.bz2
        tar xjf /tmp/gradle.tar.bz2 -C /opt
        mv /opt/.gradle /opt/gradle
        chown -R $USER:$USER /opt/gradle
        rm /tmp/gradle.tar.bz2
    fi

    sudo touch /usr/local/sbin/android.sh
fi
check_install android-studio

# Instalar Unity Hub
echo "Instalando Unity Hub..."
sudo add-apt-repository -y ppa:dotnet/backports
wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'
sudo -E apt-get update -y
sudo -E apt-get install -y unityhub dotnet-sdk-9.0
check_install unityhub

# Instalar Frame0
echo "Instalando Frame0..."
if ! dpkg -l | grep -q frame0; then
    wget https://files.frame0.app/releases/linux/x64/frame0_1.0.0~beta.8_amd64.deb -O /tmp/frame0.deb
    sudo -E dpkg -i /tmp/frame0.deb || sudo -E apt-get -f install -y
    rm /tmp/frame0.deb
fi
check_install frame0

echo "Instalação concluída!"

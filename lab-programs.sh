#!/bin/bash
# =====================================================================
#  lab-programs.sh
#  v11.0.0
#
#  Instala todos os programas do laboratorio.
#
#  v11.0.0 - Correcao do SWI-Prolog:
#    - Remove 'swi-prolog' da lista de pacotes essenciais
#    - Remove o PPA 'ppa:swi-prolog/stable' (causa conflito)
#    - Instala o swi-prolog do repositorio oficial do Ubuntu
#    - Se falhar, conserta o apt e tenta de novo
# =====================================================================

# Configuracao inicial
export DEBIAN_FRONTEND=noninteractive

# ==============================
# BLOQUEAR MODULO algif_aead (Copy Fail CVE-2026-31431)
# ==============================


# Funcao para verificar instalacao
check_install() {
    if command -v $1 &>/dev/null; then
        echo "[SUCESSO] $1 instalado corretamente"
        return 0
    else
        echo "[ERRO] Falha ao instalar $1"
        return 1
    fi
}


echo "Configurando bloqueio do modulo algif_aead..."

CONF="/etc/modprobe.d/manual-disable-algif_aead.conf"

if ! grep -q "algif_aead" "$CONF" 2>/dev/null; then
    echo "install algif_aead /bin/false" > "$CONF"
    echo "blacklist algif_aead" >> "$CONF"
    update-initramfs -u
    echo "OK Bloqueio aplicado"
else
    echo "OK Ja configurado"
fi

# aplicar imediatamente (opcional)
rmmod algif_aead 2>/dev/null || true


# Corrigir erro "check-new-release-gtk crashed with apt_pkg"
echo "Corrigindo possiveis problemas no release upgrader..."
sudo apt-get update -y
sudo apt-get install --reinstall -y ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk python3-apt
sudo apt --fix-broken install -y
sudo dpkg --configure -a
sudo apt autoremove -y

# Desabilitar popups de atualizacao de versao do Ubuntu
echo "Desabilitando notificacoes de atualizacao de versao do Ubuntu..."
sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
gsettings set com.ubuntu.update-notifier show-livepatch-status false 2>/dev/null || true
gsettings set com.ubuntu.update-notifier auto-launch false 2>/dev/null || true
sudo systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service
sudo -E apt-get update -y
sudo -E apt-get install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg

# Instalar Quarto (atualizado para 1.11.3)
QUARTO_VERSION="1.11.3"
QUARTO_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb"
if ! command -v quarto &>/dev/null; then
    wget -O /tmp/quarto.deb "$QUARTO_URL"
    sudo dpkg -i /tmp/quarto.deb || sudo apt-get -f install -y
    rm /tmp/quarto.deb
fi
check_install quarto

# Atualizacao do sistema
echo "Atualizando sistema..."
sudo -E apt-get update -y
sudo -E apt-get upgrade -y
sudo -E apt-get dist-upgrade -y
sudo -E apt-get autoremove -y
sudo -E apt-get install -f -y



# =====================================================================
# 0) SSH (instalar e configurar)
# =====================================================================
echo "Instalando SSH..."
sudo apt-get update -y
sudo apt-get install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
sleep 1

if systemctl is-active --quiet ssh; then
    echo "[SUCESSO] SSH rodando"
elif ss -tlnp 2>/dev/null | grep -q ":22 "; then
    echo "[SUCESSO] SSH escutando na porta 22"
elif [ -x /usr/sbin/sshd ]; then
    echo "[SUCESSO] sshd existe"
else
    echo "[ERRO] Falha ao instalar SSH"
fi


# Instalar ClamAV (antivirus) e ClamTK (interface grafica)
echo "Instalando ClamAV e ClamTK..."
sudo -E apt-get update -y
sudo -E apt-get install -y clamav clamtk
sudo freshclam  # Atualiza as definicoes de virus
check_install clamscan
check_install clamtk

# Removendo Termius
echo "Removendo Termius..."

if dpkg -l | grep -q termius-app; then
    sudo apt-get purge -y termius-app
    sudo apt-get autoremove -y
else
    echo "Pacote termius-app nao encontrado. Removendo manualmente..."
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
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
USERNAME=${SUDO_USER:-$USER}
sudo usermod -aG docker $USERNAME
echo "Docker instalado e usuario $USERNAME adicionado ao grupo docker. Faca logout/login para aplicar as permissoes."
check_install docker

# Instalar AVRA 1.3.0 (SourceForge + GitHub fallback)
echo "Instalando AVRA 1.3.0..."
sudo apt-get install -y build-essential wget bzip2
rm -rf /tmp/avra-*
cd /tmp

if wget -q --timeout=30 --tries=2 "https://downloads.sourceforge.net/project/avra/1.3.0/avra-1.3.0.tar.bz2" -O avra-1.3.0.tar.bz2 && [ -s avra-1.3.0.tar.bz2 ]; then
    tar -xjf avra-1.3.0.tar.bz2
    cd avra-1.3.0
elif wget -q --timeout=30 --tries=2 "https://github.com/Ro5bert/avra/archive/refs/tags/1.3.0.tar.gz" -O avra-1.3.0.tar.gz && [ -s avra-1.3.0.tar.gz ]; then
    tar -xzf avra-1.3.0.tar.gz
    cd avra-1.3.0
fi

if [ -f Makefile ]; then
    make
    sudo make install
    cd /
    rm -rf /tmp/avra-*
fi
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

# Instalar pacotes essenciais (SEM swi-prolog)
echo "Instalando pacotes essenciais..."
sudo -E apt-get install -y \
    python3-pip default-jre default-jdk maven racket elixir clisp nasm gcc-multilib \
    python3.11-full python3.10-venv \
    git flex bison vim sasm \
    mysql-server postgresql postgresql-contrib \
    arp-scan net-tools mtr dnsutils traceroute curl \
    gnupg ca-certificates podman megatools

# Instalar GNU Octave
echo "Instalando GNU Octave..."
sudo -E apt-get install -y octave
check_install octave

# Atualizar Racket se necessario (versao oficial do site)
echo "Verificando Racket..."

LATEST_RACKET_URL=$(curl -s https://download.racket-lang.org/ | grep -oP 'https://[^"]+linux-x64.sh' | head -n 1)

if [ ! -z "$LATEST_RACKET_URL" ]; then
    echo "Baixando e instalando a versao mais recente do Racket..."
    wget -O /tmp/racket-install.sh "$LATEST_RACKET_URL"
    chmod +x /tmp/racket-install.sh
    sudo /tmp/racket-install.sh --in-place --dest /opt/racket
    sudo ln -sf /opt/racket/bin/racket /usr/local/bin/racket
    rm /tmp/racket-install.sh
fi

check_install racket

# =====================================================================
# SWI-Prolog (v11.0.0 - SEM PPA, sem conflito)
# =====================================================================
echo "Verificando SWI-Prolog..."

# Se o swipl ja esta instalado, pula
if command -v swipl &>/dev/null; then
    echo "[SUCESSO] SWI-Prolog ja instalado: $(swipl --version 2>/dev/null | head -1)"
else
    echo "Instalando SWI-Prolog (versao do Ubuntu, sem PPA)..."

    # Remove o PPA antigo do swi-prolog (causa conflito com swi-prolog-core)
    if ls /etc/apt/sources.list.d/*swi-prolog* 2>/dev/null; then
        echo "Removendo PPA antigo do swi-prolog..."
        sudo add-apt-repository -r -y ppa:swi-prolog/stable 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/*swi-prolog* 2>/dev/null
        sudo rm -f /etc/apt/trusted.gpg.d/*swi-prolog* 2>/dev/null
    fi

    # Remove residuos do swi-prolog
    sudo apt-get remove -y swi-prolog swi-prolog-nox swi-prolog-core \
        swi-prolog-core-packages swi-prolog-doc 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true

    # Atualiza
    sudo -E apt-get update -y

    # Instala do Ubuntu
    if ! sudo -E apt-get install -y swi-prolog; then
        echo "[AVISO] Primeira tentativa falhou - consertando apt..."
        sudo apt-get --fix-broken install -y 2>/dev/null
        sudo dpkg --configure -a 2>/dev/null
        sudo -E apt-get update -y
        sudo -E apt-get install -y swi-prolog || true
    fi
fi

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

# =====================================================================
# MySQL Workbench (v12.0.0 - via snap)
# =====================================================================
echo "Instalando MySQL Workbench..."

# Tenta snap primeiro (mais confiavel)
if ! snap list mysql-workbench-community &>/dev/null; then
    sudo snap install mysql-workbench-community 2>/dev/null || true
fi

if snap list mysql-workbench-community &>/dev/null; then
    echo "[SUCESSO] mysql-workbench via snap"
else
    # Fallback: .deb
    wget -q --timeout=60 --tries=2 \
        "https://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-workbench-community_8.0.34-1ubuntu22.04_amd64.deb" \
        -O /tmp/mysql-workbench.deb
    if [ -s /tmp/mysql-workbench.deb ]; then
        sudo -E dpkg -i /tmp/mysql-workbench.deb || sudo -E apt-get -f install -y
        rm /tmp/mysql-workbench.deb
    fi
fi
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

# =====================================================================
# SimulIDE (v12.0.0 - 3 URLs)
# =====================================================================
echo "Instalando SimulIDE..."
sudo -E apt-get install -y fuse libfuse2 libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5svg5 qtbase5-dev qttools5-dev-tools libqt5serialport5 libqt5serialport5-dev

if [ ! -f /usr/local/bin/simulide ]; then
    cd /opt
    for URL in \
        "https://github.com/SimulIDE/SimulIDE/releases/download/1.1.0-SR2/SimulIDE_1.1.0-SR2_Lin64.tar.gz" \
        "https://github.com/SimulIDE/SimulIDE/releases/download/1.1.0/SimulIDE_1.1.0-SR1_Lin64.tar.gz" \
        "https://github.com/SimulIDE/SimulIDE/releases/download/1.0.0/SimulIDE_1.0.0-SR0_Lin64.tar.gz"; do

        echo "Tentando: $URL"
        wget -q --timeout=60 --tries=2 "$URL" -O /tmp/SimulIDE.tar.gz
        if [ -s /tmp/SimulIDE.tar.gz ]; then
            echo "[OK] Baixou"
            break
        fi
        rm -f /tmp/SimulIDE.tar.gz
    done

    if [ -s /tmp/SimulIDE.tar.gz ]; then
        sudo tar -xzf /tmp/SimulIDE.tar.gz -C /opt
        sudo chmod +x /opt/SimulIDE*/simulide 2>/dev/null
        sudo ln -sf /opt/SimulIDE*/simulide /usr/local/bin/simulide 2>/dev/null
        rm /tmp/SimulIDE.tar.gz
    fi
fi
check_install simulide

# Instalar Arduino IDE
echo "Instalando Arduino IDE..."
sudo snap install arduino
sudo usermod -a -G dialout $USER
check_install arduino

# Instalar Wine
echo "Instalando Wine..."
sudo -E apt-get install -y wine
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
sudo -E apt-get install -y --no-install-recommends software-properties-common dirmngr gdebi-core
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
    if [[ ! -d /opt/Android ]]; then
        wget https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download -O /tmp/Android.tar.bz2
        tar xjf /tmp/Android.tar.bz2 -C /opt
        rm /tmp/Android.tar.bz2
        ln -sf /opt/Android $HOME/Android
    fi

    if ! snap list | grep -q android-studio; then
        sudo snap install android-studio --classic
    fi

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

echo "Instalacao concluida!"

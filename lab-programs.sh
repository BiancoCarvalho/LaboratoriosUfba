#!/bin/bash
# =====================================================================
#  lab-programs.sh
#  v3.0.0
#
#  Instala todos os programas do laboratório.
#  Inclui openssh-server.
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

# Função utilitária
check_install() {
    if command -v "$1" &>/dev/null; then
        echo "[SUCESSO] $1 instalado corretamente"
        return 0
    else
        echo "[ERRO] Falha ao instalar $1"
        return 1
    fi
}

# =====================================================================
# 0) SSH
# =====================================================================
echo "==> Instalando openssh-server..."
if ! dpkg -l | grep -q "^ii  openssh-server"; then
    sudo apt-get update -y
    sudo apt-get install -y openssh-server
fi
sudo systemctl enable ssh 2>/dev/null || true
sudo systemctl start ssh  2>/dev/null || true
if systemctl is-active --quiet ssh; then
    echo "[SUCESSO] SSH rodando"
else
    echo "[AVISO] SSH não está rodando"
fi

# =====================================================================
# 1) BLOQUEAR MÓDULO algif_aead
# =====================================================================
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
rmmod algif_aead 2>/dev/null || true

# =====================================================================
# 2) RELEASE UPGRADER
# =====================================================================
echo "Corrigindo release upgrader..."
sudo apt-get update -y
sudo apt-get install --reinstall -y ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk python3-apt
sudo apt --fix-broken install -y
sudo dpkg --configure -a
sudo apt autoremove -y

sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
gsettings set com.ubuntu.update-notifier show-livepatch-status false 2>/dev/null || true
gsettings set com.ubuntu.update-notifier auto-launch false 2>/dev/null || true
sudo systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service 2>/dev/null || true

sudo -E apt-get update -y
sudo -E apt-get install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg

# =====================================================================
# 3) QUARTO
# =====================================================================
QUARTO_VERSION="1.8.24"
QUARTO_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb"
if ! command -v quarto &>/dev/null; then
    wget -O /tmp/quarto.deb "$QUARTO_URL"
    sudo dpkg -i /tmp/quarto.deb || sudo apt-get -f install -y
    rm -f /tmp/quarto.deb
fi
check_install quarto

# =====================================================================
# 4) ATUALIZAÇÃO DO SISTEMA
# =====================================================================
echo "Atualizando sistema..."
sudo -E apt-get update -y
sudo -E apt-get upgrade -y
sudo -E apt-get dist-upgrade -y
sudo -E apt-get autoremove -y
sudo -E apt-get install -f -y

# =====================================================================
# 5) CLAMAV
# =====================================================================
echo "Instalando ClamAV e ClamTK..."
sudo -E apt-get install -y clamav freshclam clamtk
sudo freshclam || true
check_install clamscan
check_install clamtk

# =====================================================================
# 6) REMOVER TERMIUS
# =====================================================================
echo "Removendo Termius..."
if dpkg -l | grep -q termius-app; then
    sudo apt-get purge -y termius-app
    sudo apt-get autoremove -y
else
    sudo rm -rf /opt/Termius
    sudo rm -f /usr/share/applications/termius.desktop
    sudo rm -f /usr/bin/termius
fi

# =====================================================================
# 7) JUPYTER
# =====================================================================
echo "Instalando Jupyter..."
pip install jupyter -q
check_install jupyter

# =====================================================================
# 8) DOCKER
# =====================================================================
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
check_install docker

# =====================================================================
# 9) AVRA
# =====================================================================
echo "Instalando AVRA 1.3.0..."
sudo apt-get install -y build-essential wget bzip2
cd /tmp
wget -q https://downloads.sourceforge.net/project/avra/1.3.0/avra-1.3.0.tar.bz2
tar -xjf avra-1.3.0.tar.bz2
cd avra-1.3.0
make
sudo make install
cd /
check_install avra

# =====================================================================
# 10) OLLAMA
# =====================================================================
echo "Instalando Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
check_install ollama

# =====================================================================
# 11) SUBLIME TEXT
# =====================================================================
echo "Instalando Sublime Text..."
curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/sublime-text-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/sublime-text-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo -E apt-get update -y
sudo -E apt-get install -y sublime-text
check_install subl

# =====================================================================
# 12) NEOFETCH
# =====================================================================
sudo -E apt-get install -y neofetch
check_install neofetch

# =====================================================================
# 13) VS CODE
# =====================================================================
echo "Instalando VS Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f /tmp/packages.microsoft.gpg
sudo -E apt-get update -y
sudo -E apt-get install -y code
check_install code

# =====================================================================
# 14) OBS STUDIO
# =====================================================================
echo "Instalando OBS Studio..."
sudo add-apt-repository -y ppa:obsproject/obs-studio
sudo -E apt-get update -y
sudo -E apt-get install -y obs-studio v4l2loopback-dkms
check_install obs

# =====================================================================
# 15) PACOTES ESSENCIAIS (incluindo SSH)
# =====================================================================
echo "Instalando pacotes essenciais..."
sudo -E apt-get install -y \
    python3-pip default-jre default-jdk maven swi-prolog racket elixir clisp nasm gcc-multilib \
    python3.11-full python3.10-venv \
    git flex bison vim sasm \
    mysql-server postgresql postgresql-contrib \
    arp-scan net-tools mtr dnsutils traceroute curl \
    gnupg ca-certificates podman megatools \
    openssh-server

# =====================================================================
# 16) OCTAVE
# =====================================================================
echo "Instalando GNU Octave..."
sudo -E apt-get install -y octave
check_install octave

# =====================================================================
# 17) RACKET
# =====================================================================
echo "Verificando Racket..."
LATEST_RACKET_URL=$(curl -s https://download.racket-lang.org/ | grep -oP 'https://[^"]+linux-x64.sh' | head -n 1 || true)
if [ -n "$LATEST_RACKET_URL" ]; then
    wget -O /tmp/racket-install.sh "$LATEST_RACKET_URL"
    chmod +x /tmp/racket-install.sh
    sudo /tmp/racket-install.sh --in-place --dest /opt/racket
    sudo ln -sf /opt/racket/bin/racket /usr/local/bin/racket
    rm -f /tmp/racket-install.sh
fi
check_install racket

# =====================================================================
# 18) SWI-PROLOG
# =====================================================================
echo "Verificando SWI-Prolog..."
sudo add-apt-repository -y ppa:swi-prolog/stable
sudo -E apt-get update -y
sudo -E apt-get install -y swi-prolog
check_install swipl

# =====================================================================
# 19) POSTGRESQL 17
# =====================================================================
echo "Instalando PostgreSQL 17..."
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - 2>/dev/null || true
sudo -E apt-get update -y
sudo -E apt-get install -y postgresql-17 postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
check_install psql

# =====================================================================
# 20) PGADMIN
# =====================================================================
echo "Instalando pgAdmin..."
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo -E apt-get update -y
sudo -E apt-get install -y pgadmin4-web pgadmin4-desktop

# =====================================================================
# 21) MYSQL WORKBENCH
# =====================================================================
echo "Instalando MySQL Workbench..."
wget http://cdn.mysql.com/Downloads/MySQLGUITools/mysql-workbench-community_8.0.34-1ubuntu22.04_amd64.deb -O /tmp/mysql-workbench.deb || true
if [ -f /tmp/mysql-workbench.deb ]; then
    sudo -E dpkg -i /tmp/mysql-workbench.deb || sudo -E apt-get -f install -y
    rm -f /tmp/mysql-workbench.deb
fi
check_install mysql-workbench

# =====================================================================
# 22) NETBEANS
# =====================================================================
echo "Instalando NetBeans..."
sudo -E apt-get install -y openjdk-17-jdk
sudo snap install netbeans --classic || true

# =====================================================================
# 23) GREENFOOT
# =====================================================================
echo "Instalando Greenfoot..."
sudo snap install greenfoot || true

# =====================================================================
# 24) SIMULIDE
# =====================================================================
echo "Instalando SimulIDE..."
sudo -E apt-get install -y fuse libfuse2 libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5svg5 qtbase5-dev qttools5-dev-tools libqt5serialport5 libqt5serialport5-dev
if [ ! -f /usr/local/bin/simulide ]; then
    megadl "https://mega.nz/file/8akRDCYJ#8Fvn6U9RIJ-sX_f49fCsn05YTUr5ySNycoFlxVFX-iE" -o /tmp/SimulIDE.tar.gz || true
    if [ -f /tmp/SimulIDE.tar.gz ]; then
        tar -xzvf /tmp/SimulIDE.tar.gz -C /opt
        chmod +x /opt/SimulIDE_1.1.0-SR1_Lin64/simulide
        ln -sf /opt/SimulIDE_1.1.0-SR1_Lin64/simulide /usr/local/bin/simulide
        rm -f /tmp/SimulIDE.tar.gz
    fi
fi

# =====================================================================
# 25) ARDUINO
# =====================================================================
echo "Instalando Arduino IDE..."
sudo snap install arduino || true
sudo usermod -a -G dialout ${SUDO_USER:-$USER}

# =====================================================================
# 26) WINE
# =====================================================================
echo "Instalando Wine..."
sudo -E apt-get install -y wine64
check_install wine

# =====================================================================
# 27) MONGODB
# =====================================================================
echo "Instalando MongoDB..."
if [ ! -f /etc/mongod.conf ]; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo -E apt-get update -y
    sudo -E apt-get install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
fi
check_install mongod

# =====================================================================
# 28) R e RSTUDIO
# =====================================================================
echo "Instalando R e RStudio..."
sudo -E apt-get install -y --no-install-recommends software-properties-common dirmngr
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" -y
sudo -E apt-get update -y
sudo -E apt-get install -y --no-install-recommends r-base r-base-dev
wget https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.04.2-764-amd64.deb -O /tmp/rstudio.deb || true
if [ -f /tmp/rstudio.deb ]; then
    sudo -E gdebi -n /tmp/rstudio.deb || true
    rm -f /tmp/rstudio.deb
fi
check_install R
check_install rstudio

# =====================================================================
# 29) NODE.JS
# =====================================================================
echo "Instalando Node.js..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo -E apt-get update -y
sudo -E apt-get install -y nodejs
mkdir -p /opt/npm
chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/npm
npm install -g @angular/cli || true
check_install node

# =====================================================================
# 30) PYTHON
# =====================================================================
echo "Configurando Python..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
sudo -E apt-get install -y python3.10-venv python3.11-venv

# =====================================================================
# 31) SNAPS DE IDES
# =====================================================================
echo "Instalando snaps (IDEs)..."
sudo snap install eclipse --classic || true
sudo snap install intellij-idea-community --classic || true
sudo snap install mongo33 || true
sudo snap install bluej || true

# =====================================================================
# 32) FLUTTER
# =====================================================================
echo "Instalando Flutter..."
if [ ! -d "/opt/flutter" ]; then
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.5-stable.tar.xz -O /tmp/flutter.tar.xz
    tar xf /tmp/flutter.tar.xz -C /opt
    chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/flutter
    rm -f /tmp/flutter.tar.xz
fi
check_install flutter

# =====================================================================
# 33) NAND2TETRIS
# =====================================================================
echo "Instalando Nand2Tetris..."
if [ ! -d "/opt/nand2tetris" ]; then
    wget --no-check-certificate https://nuvem.ufba.br/s/ykUB6F81M5z2Ef1/download -O /tmp/nand2tetris.zip
    unzip /tmp/nand2tetris.zip -d /opt
    rm -f /tmp/nand2tetris.zip
fi

# =====================================================================
# 34) GOOGLE CHROME
# =====================================================================
echo "Instalando Google Chrome..."
if ! command -v google-chrome &>/dev/null; then
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo -E dpkg -i /tmp/chrome.deb || sudo -E apt-get -f install -y
    rm -f /tmp/chrome.deb
fi
check_install google-chrome

# =====================================================================
# 35) ANDROID STUDIO
# =====================================================================
echo "Instalando Android Studio..."
if [ ! -f /usr/local/sbin/android.sh ]; then
    if [ ! -d /opt/Android ]; then
        wget https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download -O /tmp/Android.tar.bz2
        tar xjf /tmp/Android.tar.bz2 -C /opt
        rm -f /tmp/Android.tar.bz2
        ln -sf /opt/Android ${SUDO_USER:-$USER}/Android 2>/dev/null || true
    fi
    if ! snap list | grep -q android-studio; then
        sudo snap install android-studio --classic
    fi
    if [ ! -d /opt/gradle ]; then
        wget https://nuvem.ufba.br/s/U5anBL3tRpN2xhT/download -O /tmp/gradle.tar.bz2
        tar xjf /tmp/gradle.tar.bz2 -C /opt
        mv /opt/.gradle /opt/gradle
        chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/gradle
        rm -f /tmp/gradle.tar.bz2
    fi
    sudo touch /usr/local/sbin/android.sh
fi

# =====================================================================
# 36) UNITY HUB
# =====================================================================
echo "Instalando Unity Hub..."
sudo add-apt-repository -y ppa:dotnet/backports
wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'
sudo -E apt-get update -y
sudo -E apt-get install -y unityhub dotnet-sdk-9.0
check_install unityhub

# =====================================================================
# 37) FRAME0
# =====================================================================
echo "Instalando Frame0..."
if ! dpkg -l | grep -q frame0; then
    wget https://files.frame0.app/releases/linux/x64/frame0_1.0.0~beta.8_amd64.deb -O /tmp/frame0.deb || true
    if [ -f /tmp/frame0.deb ]; then
        sudo -E dpkg -i /tmp/frame0.deb || sudo -E apt-get -f install -y
        rm -f /tmp/frame0.deb
    fi
fi

# =====================================================================
# FIM
# =====================================================================
echo ""
echo "=================================================="
echo " ✅ Instalação de programas concluída"
echo "=================================================="

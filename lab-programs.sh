#!/bin/bash
# =====================================================================
#  lab-programs.sh
#  v13.0.0
#
#  Instala todos os programas do laboratorio.
#
#  v13.0.0:
#    - Verificacao em TODOS os blocos (pula se ja instalado)
#    - Docker: verifica binario + grupo
#    - PostgreSQL 17: verifica versao especifica
#    - Jupyter: verifica via pip show
#    - SWI-Prolog sem PPA (mantido)
#    - Firefox .deb no final (mantido)
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

# =====================================================================
# Funcao para verificar instalacao
# =====================================================================
check_install() {
    if command -v $1 &>/dev/null; then
        echo "[SUCESSO] $1 instalado corretamente"
        return 0
    else
        echo "[ERRO] Falha ao instalar $1"
        return 1
    fi
}

# =====================================================================
# 0) Bloquear modulo algif_aead
# =====================================================================
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
rmmod algif_aead 2>/dev/null || true

# =====================================================================
# 1) Release upgrader
# =====================================================================
if ! dpkg -l | grep -q ubuntu-release-upgrader-gtk; then
    echo "→ Corrigindo possiveis problemas no release upgrader..."
    apt-get update -y
    apt-get install --reinstall -y ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk python3-apt
    apt --fix-broken install -y
    dpkg --configure -a
    apt autoremove -y
else
    echo "✅ Release upgrader já instalado. Pulando."
fi

sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
gsettings set com.ubuntu.update-notifier show-livepatch-status false 2>/dev/null || true
gsettings set com.ubuntu.update-notifier auto-launch false 2>/dev/null || true
systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service 2>/dev/null || true

if ! command -v curl &>/dev/null || ! command -v wget &>/dev/null; then
    apt-get update -y
    apt-get install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg
else
    echo "✅ curl/wget já instalados. Pulando."
fi

# =====================================================================
# 2) Quarto
# =====================================================================
if ! command -v quarto &>/dev/null; then
    echo "→ Instalando Quarto..."
    QUARTO_VERSION="1.11.3"
    QUARTO_URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb"
    wget -O /tmp/quarto.deb "$QUARTO_URL"
    dpkg -i /tmp/quarto.deb || apt-get -f install -y
    rm -f /tmp/quarto.deb
    check_install quarto
else
    echo "✅ Quarto já instalado. Pulando."
fi

# =====================================================================
# ipset — necessário para o lab-block.sh v16+
# =====================================================================
if ! command -v ipset >/dev/null 2>&1; then
    echo "→ Instalando ipset..."
    apt-get install -y ipset
else
    echo "✅ ipset já instalado. Pulando."
fi

# =====================================================================
# 3) Atualizacao do sistema
# =====================================================================
echo "→ Atualizando sistema..."
apt-get update -y
apt-get upgrade -y
apt-get autoremove -y
apt-get install -f -y

# =====================================================================
# 4) SSH
# =====================================================================
if ! dpkg -l | grep -q openssh-server; then
    echo "→ Instalando SSH..."
    apt-get install -y openssh-server
    systemctl enable ssh 2>/dev/null
    systemctl start ssh 2>/dev/null
else
    echo "✅ SSH já instalado. Pulando."
fi
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

# =====================================================================
# 5) ClamAV
# =====================================================================
if ! command -v clamscan &>/dev/null; then
    echo "→ Instalando ClamAV e ClamTK..."
    apt-get install -y clamav clamtk
    timeout 300 freshclam 2>/dev/null || true
    check_install clamscan
else
    echo "✅ ClamAV já instalado. Pulando."
fi
if ! dpkg -l | grep -q clamtk; then
    echo "→ Instalando ClamTK..."
    apt-get install -y clamtk
fi

# =====================================================================
# 6) Remover Termius
# =====================================================================
echo "→ Verificando Termius..."
if dpkg -l | grep -q termius-app; then
    echo "→ Removendo Termius..."
    apt-get purge -y termius-app
    apt-get autoremove -y
else
    rm -rf /opt/Termius
    rm -f /usr/share/applications/termius.desktop
    rm -f /usr/bin/termius
    echo "✅ Termius não encontrado. Nada a fazer."
fi

# =====================================================================
# 7) Jupyter
# =====================================================================
if ! pip show jupyter &>/dev/null && ! pip3 show jupyter &>/dev/null; then
    echo "→ Instalando Jupyter..."
    pip install jupyter -q 2>/dev/null || pip3 install jupyter -q 2>/dev/null || true
    check_install jupyter
else
    echo "✅ Jupyter já instalado. Pulando."
fi

# =====================================================================
# 8) Docker (verifica binario + grupo)
# =====================================================================
USERNAME=${SUDO_USER:-$USER}
DOCKER_OK=false
if command -v docker &>/dev/null; then
    if groups $USERNAME 2>/dev/null | grep -q docker; then
        DOCKER_OK=true
    fi
fi

if [ "$DOCKER_OK" = "false" ]; then
    echo "→ Instalando/configurando Docker..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update -y
    fi
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker $USERNAME 2>/dev/null || true
    check_install docker
else
    echo "✅ Docker já instalado e usuário no grupo. Pulando."
fi

# =====================================================================
# 9) AVRA
# =====================================================================
if ! command -v avra &>/dev/null; then
    echo "→ Instalando AVRA 1.3.0..."
    apt-get install -y build-essential wget bzip2
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
        make install
        cd /
        rm -rf /tmp/avra-*
    fi
    check_install avra
else
    echo "✅ AVRA já instalado. Pulando."
fi

# =====================================================================
# 10) Ollama
# =====================================================================
if ! command -v ollama &>/dev/null; then
    echo "→ Instalando Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    check_install ollama
else
    echo "✅ Ollama já instalado. Pulando."
fi

# =====================================================================
# 11) Sublime Text
# =====================================================================
if ! command -v subl &>/dev/null; then
    echo "→ Instalando Sublime Text..."
    curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor -o /usr/share/keyrings/sublime-text-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/sublime-text-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
    apt-get update -y
    apt-get install -y sublime-text
    check_install subl
else
    echo "✅ Sublime Text já instalado. Pulando."
fi

# =====================================================================
# 12) Neofetch
# =====================================================================
if ! command -v neofetch &>/dev/null; then
    echo "→ Instalando Neofetch..."
    apt-get install -y neofetch
    check_install neofetch
else
    echo "✅ Neofetch já instalado. Pulando."
fi

# =====================================================================
# 13) VS Code
# =====================================================================
if ! command -v code &>/dev/null; then
    echo "→ Instalando Visual Studio Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    rm -f packages.microsoft.gpg
    apt-get update -y
    apt-get install -y code
    check_install code
else
    echo "✅ VSCode já instalado. Pulando."
fi

# =====================================================================
# 14) OBS Studio + v4l2loopback
# =====================================================================
if ! command -v obs &>/dev/null; then
    echo "→ Instalando OBS Studio..."
    add-apt-repository -y ppa:obsproject/obs-studio
    apt-get update -y
    apt-get install -y obs-studio
    check_install obs
else
    echo "✅ OBS Studio já instalado. Pulando."
fi

if ! dkms status 2>/dev/null | grep -q v4l2loopback; then
    echo "→ Instalando v4l2loopback..."
    apt-get purge -y v4l2loopback-dkms v4l2loopback-utils 2>/dev/null || true
    rm -f /var/crash/v4l2loopback-dkms.*.crash
    apt-get install -y git dkms build-essential linux-headers-$(uname -r)
    rm -rf /tmp/v4l2loopback
    git clone https://github.com/umlaeute/v4l2loopback.git /tmp/v4l2loopback
    cd /tmp/v4l2loopback
    mkdir -p /usr/src/v4l2loopback-0.15.0
    cp -r * /usr/src/v4l2loopback-0.15.0/
    cd /usr/src/v4l2loopback-0.15.0
    dkms add -m v4l2loopback -v 0.15.0 2>/dev/null || true
    dkms build -m v4l2loopback -v 0.15.0 2>/dev/null || true
    dkms install -m v4l2loopback -v 0.15.0 2>/dev/null || true
    apt-mark hold v4l2loopback-dkms 2>/dev/null || true
    modprobe v4l2loopback exclusive_caps=1 2>/dev/null || true
else
    echo "✅ v4l2loopback já instalado. Pulando."
fi

# =====================================================================
# 15) Pacotes essenciais
# =====================================================================
if ! command -v nasm &>/dev/null || ! command -v racket &>/dev/null || ! command -v mysql &>/dev/null; then
    echo "→ Instalando pacotes essenciais..."
    apt-get install -y \
        python3-pip default-jre default-jdk maven racket elixir clisp nasm gcc-multilib \
        python3.11-full python3.10-venv \
        git flex bison vim sasm \
        mysql-server postgresql postgresql-contrib \
        arp-scan net-tools mtr dnsutils traceroute curl \
        gnupg ca-certificates podman megatools
else
    echo "✅ Pacotes essenciais já instalados. Pulando."
fi

# =====================================================================
# 16) Octave
# =====================================================================
if ! command -v octave &>/dev/null; then
    echo "→ Instalando GNU Octave..."
    apt-get install -y octave
    check_install octave
else
    echo "✅ Octave já instalado. Pulando."
fi

# =====================================================================
# 17) Racket
# =====================================================================
if ! command -v racket &>/dev/null; then
    echo "→ Instalando Racket..."
    LATEST_RACKET_URL=$(curl -s https://download.racket-lang.org/ | grep -oP 'https://[^"]+linux-x64.sh' | head -n 1)
    if [ ! -z "$LATEST_RACKET_URL" ]; then
        wget -O /tmp/racket-install.sh "$LATEST_RACKET_URL"
        chmod +x /tmp/racket-install.sh
        /tmp/racket-install.sh --in-place --dest /opt/racket
        ln -sf /opt/racket/bin/racket /usr/local/bin/racket
        rm /tmp/racket-install.sh
    fi
    check_install racket
else
    echo "✅ Racket já instalado. Pulando."
fi

# =====================================================================
# 18) SWI-Prolog (SEM PPA)
# =====================================================================
if ! command -v swipl &>/dev/null; then
    echo "→ Instalando SWI-Prolog..."
    if ls /etc/apt/sources.list.d/*swi-prolog* 2>/dev/null; then
        add-apt-repository -r -y ppa:swi-prolog/stable 2>/dev/null || true
        rm -f /etc/apt/sources.list.d/*swi-prolog* 2>/dev/null
        rm -f /etc/apt/trusted.gpg.d/*swi-prolog* 2>/dev/null
    fi
    apt-get remove -y swi-prolog swi-prolog-nox swi-prolog-core swi-prolog-core-packages swi-prolog-doc 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    apt-get update -y
    apt-get install -y swi-prolog || true
    check_install swipl
else
    echo "✅ SWI-Prolog já instalado. Pulando."
fi

# =====================================================================
# 19) PostgreSQL 17 (verifica versao especifica)
# =====================================================================
if ! dpkg -l | grep -q postgresql-17; then
    echo "→ Instalando PostgreSQL 17..."
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - 2>/dev/null || true
    apt-get update -y
    apt-get install -y postgresql-17 postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    check_install psql
else
    echo "✅ PostgreSQL 17 já instalado. Pulando."
fi

# =====================================================================
# 20) pgAdmin
# =====================================================================
if ! dpkg -l | grep -q pgadmin4; then
    echo "→ Instalando pgAdmin..."
    curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
    echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list
    apt-get update -y
    apt-get install -y pgadmin4-web pgadmin4-desktop
else
    echo "✅ pgAdmin já instalado. Pulando."
fi

# =====================================================================
# 21) MySQL Workbench
# =====================================================================
if ! snap list 2>/dev/null | grep -q mysql-workbench-community; then
    echo "→ Instalando MySQL Workbench..."
    snap install mysql-workbench-community 2>/dev/null || true
    check_install mysql-workbench
else
    echo "✅ MySQL Workbench já instalado. Pulando."
fi

# =====================================================================
# 22) NetBeans
# =====================================================================
if ! snap list 2>/dev/null | grep -q netbeans; then
    echo "→ Instalando NetBeans..."
    if ! dpkg -l | grep -q openjdk-17-jdk; then
        apt-get install -y openjdk-17-jdk
    fi
    snap install netbeans --classic
    check_install netbeans
else
    echo "✅ NetBeans já instalado. Pulando."
fi

# =====================================================================
# 23) Greenfoot
# =====================================================================
if ! snap list 2>/dev/null | grep -q greenfoot; then
    echo "→ Instalando Greenfoot..."
    snap install greenfoot
    check_install greenfoot
else
    echo "✅ Greenfoot já instalado. Pulando."
fi

# =====================================================================
# 24) SimulIDE
# =====================================================================
if [ ! -f /usr/local/bin/simulide ]; then
    echo "→ Instalando SimulIDE..."
    apt-get install -y fuse libfuse2 libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5svg5 qtbase5-dev qttools5-dev-tools libqt5serialport5 libqt5serialport5-dev
    cd /opt
    for URL in \
        "https://github.com/SimulIDE/SimulIDE/releases/download/1.1.0-SR2/SimulIDE_1.1.0-SR2_Lin64.tar.gz" \
        "https://github.com/SimulIDE/SimulIDE/releases/download/1.1.0/SimulIDE_1.1.0-SR1_Lin64.tar.gz"; do
        wget -q --timeout=60 --tries=2 "$URL" -O /tmp/SimulIDE.tar.gz
        if [ -s /tmp/SimulIDE.tar.gz ]; then break; fi
        rm -f /tmp/SimulIDE.tar.gz
    done
    if [ -s /tmp/SimulIDE.tar.gz ]; then
        tar -xzf /tmp/SimulIDE.tar.gz -C /opt
        chmod +x /opt/SimulIDE*/simulide 2>/dev/null
        ln -sf /opt/SimulIDE*/simulide /usr/local/bin/simulide 2>/dev/null
        rm /tmp/SimulIDE.tar.gz
    fi
    check_install simulide
else
    echo "✅ SimulIDE já instalado. Pulando."
fi

# =====================================================================
# 25) Arduino
# =====================================================================
if ! snap list 2>/dev/null | grep -q arduino; then
    echo "→ Instalando Arduino IDE..."
    snap install arduino
    usermod -a -G dialout $USER
    check_install arduino
else
    echo "✅ Arduino IDE já instalado. Pulando."
fi

# =====================================================================
# 26) Wine
# =====================================================================
if ! command -v wine &>/dev/null; then
    echo "→ Instalando Wine..."
    apt-get install -y wine
    check_install wine
else
    echo "✅ Wine já instalado. Pulando."
fi

# =====================================================================
# 27) MongoDB
# =====================================================================
if [ ! -f /etc/mongod.conf ]; then
    echo "→ Instalando MongoDB..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update -y
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
    check_install mongo
else
    echo "✅ MongoDB já instalado. Pulando."
fi

# =====================================================================
# 28) R e RStudio
# =====================================================================
if ! command -v R &>/dev/null; then
    echo "→ Instalando R..."
    apt-get install -y --no-install-recommends software-properties-common dirmngr gdebi-core
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
    apt-get update -y
    apt-get install -y --no-install-recommends r-base r-base-dev
    check_install R
else
    echo "✅ R já instalado. Pulando."
fi

if ! command -v rstudio &>/dev/null; then
    echo "→ Instalando RStudio..."
    wget https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.04.2-764-amd64.deb -O /tmp/rstudio.deb
    gdebi -n /tmp/rstudio.deb
    rm /tmp/rstudio.deb
    check_install rstudio
else
    echo "✅ RStudio já instalado. Pulando."
fi

# =====================================================================
# 29) Node.js
# =====================================================================
if ! command -v node &>/dev/null; then
    echo "→ Instalando Node.js..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt-get update -y
    apt-get install -y nodejs
    mkdir -p /opt/npm
    chown -R $USER:$USER /opt/npm
    npm install -g @angular/cli
    check_install node
else
    echo "✅ Node.js já instalado. Pulando."
fi

# =====================================================================
# 30) Python
# =====================================================================
if [ ! -f /usr/bin/python3.10 ] || [ ! -f /usr/bin/python3.11 ]; then
    echo "→ Configurando Python..."
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
    apt-get install -y python3.10-venv python3.11-venv
else
    echo "✅ Python já configurado. Pulando."
fi

# =====================================================================
# 31) Snaps de IDEs
# =====================================================================
if ! snap list 2>/dev/null | grep -q eclipse; then
    echo "→ Instalando Eclipse..."
    snap install eclipse --classic
else
    echo "✅ Eclipse já instalado. Pulando."
fi

if ! snap list 2>/dev/null | grep -q intellij-idea-community; then
    echo "→ Instalando IntelliJ IDEA Community..."
    snap install intellij-idea-community --classic
else
    echo "✅ IntelliJ já instalado. Pulando."
fi

if ! snap list 2>/dev/null | grep -q mongo33; then
    echo "→ Instalando MongoDB 3.3 (snap)..."
    snap install mongo33
else
    echo "✅ MongoDB 3.3 já instalado. Pulando."
fi

if ! snap list 2>/dev/null | grep -q bluej; then
    echo "→ Instalando BlueJ..."
    snap install bluej
else
    echo "✅ BlueJ já instalado. Pulando."
fi

# =====================================================================
# 32) Flutter
# =====================================================================
if [ ! -d "/opt/flutter" ]; then
    echo "→ Instalando Flutter..."
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.5-stable.tar.xz -O /tmp/flutter.tar.xz
    tar xf /tmp/flutter.tar.xz -C /opt
    chown -R $USER:$USER /opt/flutter
    rm /tmp/flutter.tar.xz
    echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
    check_install flutter
else
    echo "✅ Flutter já instalado. Pulando."
fi

# =====================================================================
# 33) Nand2Tetris
# =====================================================================
if [ ! -d "/opt/nand2tetris" ]; then
    echo "→ Instalando Nand2Tetris..."
    wget --no-check-certificate https://nuvem.ufba.br/s/ykUB6F81M5z2Ef1/download -O /tmp/nand2tetris.zip
    unzip /tmp/nand2tetris.zip -d /opt
    rm /tmp/nand2tetris.zip
else
    echo "✅ Nand2Tetris já instalado. Pulando."
fi

# =====================================================================
# 34) Google Chrome
# =====================================================================
#if ! command -v google-chrome &>/dev/null; then
#    echo "→ Instalando Google Chrome..."
#    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
#    dpkg -i /tmp/chrome.deb || apt-get -f install -y
#    rm /tmp/chrome.deb
#    check_install google-chrome
#else
#    echo "✅ Google Chrome já instalado. Pulando."
#fi

# =====================================================================
# 34) Google Chrome — DESINSTALAR
# =====================================================================
if dpkg -l 2>/dev/null | grep -q "^ii  google-chrome"; then
    echo "→ Desinstalando Google Chrome..."
    
    # 1. Purga o pacote (remove binário + configs)
    apt-get purge -y google-chrome-stable
    
    # 2. Remove dependências órfãs
    apt-get autoremove -y
    
    # 3. Remove o repositório do Chrome (se existir)
    rm -f /etc/apt/sources.list.d/google-chrome.list
    
    # 4. Remove a chave GPG do Google (opcional)
    rm -f /etc/apt/trusted.gpg.d/google-chrome.gpg
    rm -f /etc/apt/trusted.gpg.d/google-chrome-stable.gpg
    
    # 5. Atualiza o índice do apt
    apt-get update -y
    
    # 6. Valida
    if command -v google-chrome &>/dev/null; then
        echo "[ERRO] Chrome ainda presente"
    else
        echo "[SUCESSO] Chrome desinstalado"
    fi
else
    echo "✅ Google Chrome não está instalado. Nada a fazer."
fi

# =====================================================================
# 35) Android Studio
# =====================================================================
if ! [ -f /usr/local/sbin/android.sh ]; then
    echo "→ Instalando Android Studio..."
    if [[ ! -d /opt/Android ]]; then
        wget https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download -O /tmp/Android.tar.bz2
        tar xjf /tmp/Android.tar.bz2 -C /opt
        rm /tmp/Android.tar.bz2
        ln -sf /opt/Android $HOME/Android
    fi
    if ! snap list 2>/dev/null | grep -q android-studio; then
        snap install android-studio --classic
    fi
    if [[ ! -d /opt/gradle ]]; then
        wget https://nuvem.ufba.br/s/U5anBL3tRpN2xhT/download -O /tmp/gradle.tar.bz2
        tar xjf /tmp/gradle.tar.bz2 -C /opt
        mv /opt/.gradle /opt/gradle
        chown -R $USER:$USER /opt/gradle
        rm /tmp/gradle.tar.bz2
    fi
    touch /usr/local/sbin/android.sh
    check_install android-studio
else
    echo "✅ Android Studio já instalado. Pulando."
fi

# =====================================================================
# 36) Unity Hub
# =====================================================================
if ! command -v unityhub &>/dev/null; then
    echo "→ Instalando Unity Hub..."
    add-apt-repository -y ppa:dotnet/backports
    wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list
    apt-get update -y
    apt-get install -y unityhub dotnet-sdk-9.0
    check_install unityhub
else
    echo "✅ Unity Hub já instalado. Pulando."
fi

# =====================================================================
# 37) Frame0
# =====================================================================
if ! dpkg -l | grep -q frame0; then
    echo "→ Instalando Frame0..."
    wget https://files.frame0.app/releases/linux/x64/frame0_1.0.0~beta.8_amd64.deb -O /tmp/frame0.deb
    dpkg -i /tmp/frame0.deb || apt-get -f install -y
    rm /tmp/frame0.deb
    check_install frame0
else
    echo "✅ Frame0 já instalado. Pulando."
fi

# =====================================================================
# 38) Firefox (.deb) — NO FINAL
# =====================================================================
echo "→ Verificando Firefox (.deb)..."

# Se já é .deb (ELF), pula
if file /usr/bin/firefox 2>/dev/null | grep -q "ELF"; then
    echo "✅ Firefox .deb já instalado. Pulando."
else
    echo "→ Instalando Firefox (.deb)..."

    # 1. Remove o Snap (se existir)
    if snap list 2>/dev/null | grep -q firefox; then
        echo "→ Removendo Firefox Snap..."
        snap remove firefox 2>/dev/null || true
        sleep 2
    fi

    # 2. Remove o pacote wrapper do apt
    if dpkg -l | grep -q "^ii  firefox"; then
        apt remove -y firefox 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
    fi

    # 3. Bloqueia reinstalacao do snap
    mkdir -p /etc/apt/preferences.d
    cat > /etc/apt/preferences.d/firefox-no-snap <<'EOF'
Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1
EOF

    # 4. Adiciona o PPA da Mozilla
    add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null
    apt-get update -y

    # 5. Prioriza o PPA
    cat > /etc/apt/preferences.d/mozilla-firefox <<'EOF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

    # 6. Instala o .deb
    DEBIAN_FRONTEND=noninteractive apt-get install -y firefox --allow-downgrades

    # 7. Valida
    if file /usr/bin/firefox 2>/dev/null | grep -q "ELF"; then
        echo "[SUCESSO] Firefox .deb instalado"
    else
        echo "[AVISO] Firefox ainda e wrapper (snap)"
    fi
    check_install firefox
fi

# =====================================================================
# FIM
# =====================================================================
echo ""
echo "=================================================="
echo " INSTALACAO CONCLUIDA"
echo "=================================================="

exit 0

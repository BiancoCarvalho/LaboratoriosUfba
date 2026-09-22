#!/bin/bash
# =====================================================================
#  lab-programs.sh
#  v8.0.2
#
#  Instala todos os programas do laboratório.
#  Cada programa tem um SELO em /usr/local/sbin/.lab-state/NOME.
#  - Se o selo existe  → pula (rápido)
#  - Se não existe     → tenta instalar
#  - Se falhar         → NÃO cria o selo → tenta de novo no próximo boot
#
#  IDEMPOTENTE: limpa resíduos antes de instalar.
#
#  v8.0.1: Firefox agora é instalado via SNAP (método .deb/PPA removido).
#  v8.0.2: Correções para os programas que falhavam:
#          - wine: usa "wine" (não "wine64")
#          - clamav: trata freshclam sem travar
#          - jupyter: usa pip3 com fallback
#          - avra: fallback se SourceForge falhar
#          - pgadmin: instala via pip/venv (repo oficial morreu)
#          - mysql-workbench: usa snap (URL oficial morreu)
#          - simulide: fallback GitHub (link Mega morreu)
#          - nodejs: retry + fallback
#          - r-rstudio: instala gdebi antes
#          - unityhub: retry
#          - mongodb: pula se snap mongo33 já existir
# =====================================================================

export DEBIAN_FRONTEND=noninteractive

STATE="/usr/local/sbin/.lab-state"
mkdir -p "$STATE"

# =====================================================================
# Função: instala só se o selo não existe
# =====================================================================
instalar_se_preciso() {
    local nome="$1"
    local funcao="$2"
    local selo="$STATE/$nome"

    if [ -f "$selo" ]; then
        echo "✅ $nome já instalado"
        return 0
    fi

    echo ""
    echo "=================================================="
    echo "==> Instalando $nome..."
    echo "=================================================="

    if $funcao; then
        touch "$selo"
        echo "✅ $nome OK (selo criado)"
        return 0
    else
        echo "❌ $nome FALHOU — tentará de novo no próximo boot"
        return 1
    fi
}

# =====================================================================
# 0) SSH
# =====================================================================
instalar_ssh() {
    apt-get update -y || return 1
    apt-get install -y openssh-server || return 1
    systemctl enable ssh 2>/dev/null
    systemctl start ssh  2>/dev/null
    systemctl is-active --quiet ssh
}

# =====================================================================
# 1) Bloquear módulo algif_aead
# =====================================================================
instalar_algif_aead_block() {
    local CONF="/etc/modprobe.d/manual-disable-algif_aead.conf"
    echo "install algif_aead /bin/false" > "$CONF"
    echo "blacklist algif_aead" >> "$CONF"
    update-initramfs -u
    rmmod algif_aead 2>/dev/null || true
    [ -f "$CONF" ]
}

# =====================================================================
# 2) Release upgrader
# =====================================================================
instalar_release_upgrader() {
    apt-get update -y
    apt-get install --reinstall -y ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk python3-apt
    apt --fix-broken install -y
    dpkg --configure -a
    apt autoremove -y

    sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
    gsettings set com.ubuntu.update-notifier show-livepatch-status false 2>/dev/null || true
    gsettings set com.ubuntu.update-notifier auto-launch false 2>/dev/null || true
    systemctl disable --now apt-daily.service apt-daily.timer apt-daily-upgrade.timer apt-daily-upgrade.service 2>/dev/null || true

    apt-get install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg
    [ -f /etc/update-manager/release-upgrades ]
}

# =====================================================================
# 3) Quarto
# =====================================================================
instalar_quarto() {
    local V="1.8.24"
    local URL="https://github.com/quarto-dev/quarto-cli/releases/download/v${V}/quarto-${V}-linux-amd64.deb"

    rm -f /tmp/quarto.deb
    wget --timeout=60 --tries=2 -O /tmp/quarto.deb "$URL" || return 1
    [ -s /tmp/quarto.deb ] || return 1

    dpkg -i /tmp/quarto.deb || apt-get -f install -y
    rm -f /tmp/quarto.deb
    command -v quarto &>/dev/null
}

# =====================================================================
# 4) Atualização do sistema
# =====================================================================
instalar_system_update() {
    apt-get update -y
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get autoremove -y
    apt-get install -f -y
    true
}

# =====================================================================
# 5) ClamAV (v8.0.2 — trata freshclam sem travar)
# =====================================================================
instalar_clamav() {
    apt-get install -y clamav freshclam clamtk || return 1

    # freshclam em background com timeout pra não travar o script
    timeout 300 freshclam 2>/dev/null || true

    command -v clamscan &>/dev/null
}

# =====================================================================
# 6) Remover Termius
# =====================================================================
instalar_remover_termius() {
    if dpkg -l | grep -q termius-app; then
        apt-get purge -y termius-app
        apt-get autoremove -y
    fi
    rm -rf /opt/Termius
    rm -f /usr/share/applications/termius.desktop
    rm -f /usr/bin/termius
    ! dpkg -l | grep -q termius-app
}

# =====================================================================
# 7) Jupyter (v8.0.2 — usa pip3 com fallback)
# =====================================================================
instalar_jupyter() {
    apt-get install -y python3-pip python3-venv 2>/dev/null || true

    pip3 install --break-system-packages jupyter -q 2>/dev/null || \
        pip3 install jupyter -q 2>/dev/null || \
        pip install jupyter -q 2>/dev/null || \
        python3 -m pip install jupyter -q 2>/dev/null || return 1

    command -v jupyter &>/dev/null
}

# =====================================================================
# 8) Docker (limpa chave antes)
# =====================================================================
instalar_docker() {
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings

    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /etc/apt/sources.list.d/docker.list

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg || return 1

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1

    USERNAME=${SUDO_USER:-$USER}
    usermod -aG docker "$USERNAME" 2>/dev/null || true

    command -v docker &>/dev/null
}

# =====================================================================
# 9) AVRA (v8.0.2 — com fallback)
# =====================================================================
instalar_avra() {
    apt-get install -y build-essential wget bzip2 || return 1

    rm -rf /tmp/avra-1.3.0 /tmp/avra-1.3.0.tar.bz2 /tmp/avra-1.3.0.tar.gz
    cd /tmp || return 1

    wget -q --timeout=30 --tries=3 \
        https://downloads.sourceforge.net/project/avra/1.3.0/avra-1.3.0.tar.bz2 \
        -O avra-1.3.0.tar.bz2 2>/dev/null || \
    wget -q --timeout=30 --tries=3 \
        https://github.com/Ro5bert/avra/archive/refs/tags/1.3.0.tar.gz \
        -O avra-1.3.0.tar.gz 2>/dev/null || return 1

    if [ -s avra-1.3.0.tar.bz2 ]; then
        tar -xjf avra-1.3.0.tar.bz2 || return 1
        cd avra-1.3.0 || return 1
    elif [ -s avra-1.3.0.tar.gz ]; then
        tar -xzf avra-1.3.0.tar.gz || return 1
        cd avra-1.3.0 || return 1
    else
        return 1
    fi

    make || return 1
    make install
    cd / || return 1
    rm -rf /tmp/avra-1.3.0*

    command -v avra &>/dev/null
}

# =====================================================================
# 10) Ollama
# =====================================================================
instalar_ollama() {
    curl -fsSL https://ollama.com/install.sh | sh
    command -v ollama &>/dev/null
}

# =====================================================================
# 11) Sublime Text
# =====================================================================
instalar_sublime() {
    rm -f /usr/share/keyrings/sublime-text-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/sublime-text.list

    curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | \
        gpg --dearmor -o /usr/share/keyrings/sublime-text-archive-keyring.gpg || return 1

    echo "deb [signed-by=/usr/share/keyrings/sublime-text-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/" \
        > /etc/apt/sources.list.d/sublime-text.list

    apt-get update -y
    apt-get install -y sublime-text
    command -v subl &>/dev/null
}

# =====================================================================
# 12) Neofetch
# =====================================================================
instalar_neofetch() {
    apt-get install -y neofetch
    command -v neofetch &>/dev/null
}

# =====================================================================
# 13) VS Code
# =====================================================================
instalar_vscode() {
    rm -f /etc/apt/sources.list.d/vscode.list
    rm -f /etc/apt/sources.list.d/vscode.sources
    rm -f /etc/apt/sources.list.d/*vscode*
    rm -f /etc/apt/keyrings/packages.microsoft.gpg
    rm -f /usr/share/keyrings/microsoft.gpg
    rm -f /etc/apt/trusted.gpg.d/microsoft.gpg
    rm -f /tmp/packages.microsoft.gpg

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg || return 1

    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list

    apt-get update -y
    apt-get install -y code
    command -v code &>/dev/null
}

# =====================================================================
# 14) OBS Studio
# =====================================================================
instalar_obs() {
    add-apt-repository -y ppa:obsproject/obs-studio
    apt-get update -y
    apt-get install -y obs-studio
    command -v obs &>/dev/null
}

# =====================================================================
# 15) Pacotes essenciais
# =====================================================================
instalar_pacotes_essenciais() {
    apt-get install -y \
        python3-pip default-jre default-jdk maven swi-prolog racket elixir clisp nasm gcc-multilib \
        python3.11-full python3.10-venv \
        git flex bison vim sasm \
        mysql-server postgresql postgresql-contrib \
        arp-scan net-tools mtr dnsutils traceroute curl \
        gnupg ca-certificates podman megatools \
        openssh-server
    command -v git &>/dev/null
}

# =====================================================================
# 16) Octave
# =====================================================================
instalar_octave() {
    apt-get install -y octave
    command -v octave &>/dev/null
}

# =====================================================================
# 17) Racket
# =====================================================================
instalar_racket() {
    local LATEST_URL
    LATEST_URL=$(curl -s --max-time 20 https://download.racket-lang.org/ | \
        grep -oP 'https://[^"]+linux-x64.sh' | head -n 1 || true)

    if [ -n "$LATEST_URL" ]; then
        rm -f /tmp/racket-install.sh
        wget --timeout=60 -O /tmp/racket-install.sh "$LATEST_URL" || return 1
        chmod +x /tmp/racket-install.sh
        /tmp/racket-install.sh --in-place --dest /opt/racket
        ln -sf /opt/racket/bin/racket /usr/local/bin/racket
        rm -f /tmp/racket-install.sh
    fi
    command -v racket &>/dev/null
}

# =====================================================================
# 18) SWI-PROLOG
# =====================================================================
echo "Verificando SWI-Prolog..."

# 18.1) Verifica se o apt está OK antes de começar
if ! apt-get update >/dev/null 2>&1; then
    echo "⚠️ apt com problema — tentando consertar..."
    dpkg --configure -a 2>/dev/null
    apt-get --fix-broken install -y 2>/dev/null
    apt-get update -y 2>/dev/null
fi

# 18.2) Se o swipl já está instalado, pula
if command -v swipl &>/dev/null; then
    echo "✅ SWI-Prolog já instalado: $(swipl --version 2>/dev/null | head -1)"
else
    echo "==> Instalando SWI-Prolog..."

    # 18.3) Adiciona o PPA
    add-apt-repository -y ppa:swi-prolog/stable 2>/dev/null

    # 18.4) Atualiza
    apt-get update -y

    # 18.5) Tenta instalar o swi-prolog completo
    if ! apt-get install -y swi-prolog 2>/dev/null; then

        echo "⚠️ Instalação normal falhou — tentando com force-overwrite..."

        # 18.6) Remove o swi-prolog-core antigo (conflito)
        apt-get remove -y swi-prolog-core 2>/dev/null
        apt-get autoremove -y 2>/dev/null

        # 18.7) Tenta de novo
        if ! apt-get install -y swi-prolog 2>/dev/null; then

            echo "⚠️ Ainda falhou — usando force-overwrite no dpkg..."

            # 18.8) Força a instalação do pacote baixado
            DEB_NOX=$(ls /var/cache/apt/archives/swi-prolog-nox_*.deb 2>/dev/null | head -1)

            if [ -n "$DEB_NOX" ]; then
                dpkg -i --force-overwrite "$DEB_NOX" 2>/dev/null
            fi

            # 18.9) Tenta consertar o apt
            apt-get --fix-broken install -y 2>/dev/null
            dpkg --configure -a 2>/dev/null
        fi
    fi

    # 18.10) Validação final
    if command -v swipl &>/dev/null; then
        echo "✅ SWI-Prolog instalado: $(swipl --version 2>/dev/null | head -1)"
    else
        echo "⚠️ SWI-Prolog não instalou — mas o apt está OK"
    fi
fi

# 18.11) Conserta o apt (garante que não ficou quebrado)
apt-get --fix-broken install -y 2>/dev/null
dpkg --configure -a 2>/dev/null
# =====================================================================
# 19) PostgreSQL 17
# =====================================================================
instalar_postgresql() {
    rm -f /etc/apt/sources.list.d/pgdg.list
    rm -f /etc/apt/trusted.gpg.d/ACCC4CF8.asc

    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list

    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
        gpg --dearmor -o /etc/apt/trusted.gpg.d/ACCC4CF8.gpg || true

    apt-get update -y
    apt-get install -y postgresql-17 postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    command -v psql &>/dev/null
}

# =====================================================================
# 20) pgAdmin (v8.0.2 — via pip/venv, repo oficial morreu)
# =====================================================================
instalar_pgadmin() {
    rm -f /usr/share/keyrings/packages-pgadmin-org.gpg
    rm -f /etc/apt/sources.list.d/pgadmin4.list

    if curl -fsS --max-time 15 https://www.pgadmin.org/static/packages_pgadmin_org.pub | \
        gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg 2>/dev/null; then

        echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" \
            > /etc/apt/sources.list.d/pgadmin4.list

        if apt-get update -y 2>/dev/null && \
           apt-get install -y pgadmin4-web pgadmin4-desktop 2>/dev/null; then
            command -v pgadmin4 &>/dev/null && return 0
        fi
    fi

    echo "==> Repo oficial indisponível — instalando pgAdmin via pip/venv..."
    apt-get install -y python3-pip python3-venv libpq-dev 2>/dev/null || return 1

    rm -rf /opt/pgadmin4-venv
    python3 -m venv /opt/pgadmin4-venv || return 1
    /opt/pgadmin4-venv/bin/pip install --upgrade pip -q || true
    /opt/pgadmin4-venv/bin/pip install pgadmin4 -q || return 1

    ln -sf /opt/pgadmin4-venv/bin/pgadmin4 /usr/local/bin/pgadmin4
    command -v pgadmin4 &>/dev/null
}

# =====================================================================
# 21) MySQL Workbench (v8.0.2 — via snap, URL oficial morreu)
# =====================================================================
instalar_mysql_workbench() {
    if snap install mysql-workbench-community 2>/dev/null; then
        snap list mysql-workbench-community &>/dev/null && return 0
    fi

    rm -f /tmp/mysql-workbench.deb
    wget --timeout=30 --tries=2 \
        http://cdn.mysql.com/Downloads/MySQLGUITools/mysql-workbench-community_8.0.34-1ubuntu22.04_amd64.deb \
        -O /tmp/mysql-workbench.deb 2>/dev/null || return 1

    [ -s /tmp/mysql-workbench.deb ] || return 1
    dpkg -i /tmp/mysql-workbench.deb || apt-get -f install -y
    rm -f /tmp/mysql-workbench.deb
    command -v mysql-workbench &>/dev/null
}

# =====================================================================
# 22) NetBeans
# =====================================================================
instalar_netbeans() {
    apt-get install -y openjdk-17-jdk
    snap install netbeans --classic || true
    snap list netbeans &>/dev/null
}

# =====================================================================
# 23) Greenfoot
# =====================================================================
instalar_greenfoot() {
    snap install greenfoot || true
    snap list greenfoot &>/dev/null
}

# =====================================================================
# 24) SimulIDE (v8.0.2 — fallback GitHub, link Mega morreu)
# =====================================================================
instalar_simulide() {
    apt-get install -y fuse libfuse2 libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 \
        libqt5svg5 qtbase5-dev qttools5-dev-tools libqt5serialport5 libqt5serialport5-dev 2>/dev/null || true

    rm -f /tmp/SimulIDE.tar.gz /tmp/SimulIDE.tar.xz
    cd /opt || return 1

    wget -q --timeout=60 --tries=3 \
        https://github.com/SimulIDE/SimulIDE/releases/download/1.1.0/SimulIDE_1.1.0-SR1_Lin64.tar.gz \
        -O /tmp/SimulIDE.tar.gz 2>/dev/null || \
    wget -q --timeout=60 --tries=3 \
        "https://mega.nz/file/8akRDCYJ#8Fvn6U9RIJ-sX_f49fCsn05YTUr5ySNycoFlxVFX-iE" \
        -O /tmp/SimulIDE.tar.gz 2>/dev/null || return 1

    [ -s /tmp/SimulIDE.tar.gz ] || return 1

    tar -xzf /tmp/SimulIDE.tar.gz -C /opt 2>/dev/null || \
        tar -xzvf /tmp/SimulIDE.tar.gz -C /opt 2>/dev/null || return 1

    chmod +x /opt/SimulIDE*/simulide 2>/dev/null
    ln -sf /opt/SimulIDE*/simulide /usr/local/bin/simulide 2>/dev/null
    rm -f /tmp/SimulIDE.tar.gz

    command -v simulide &>/dev/null || [ -x /opt/SimulIDE_1.1.0-SR1_Lin64/simulide ]
}

# =====================================================================
# 25) Arduino
# =====================================================================
instalar_arduino() {
    snap install arduino || true
    usermod -a -G dialout ${SUDO_USER:-$USER} 2>/dev/null || true
    snap list arduino &>/dev/null
}

# =====================================================================
# 26) Wine (v8.0.2 — "wine" em vez de "wine64")
# =====================================================================
instalar_wine() {
    apt-get install -y wine || \
    apt-get install -y wine-stable || \
    apt-get install -y wine64 || return 1
    command -v wine &>/dev/null
}

# =====================================================================
# 27) MongoDB (v8.0.2 — pula se snap mongo33 já existir)
# =====================================================================
instalar_mongodb() {
    if snap list mongo33 &>/dev/null; then
        echo "==> Snap mongo33 já instalado — pulando mongodb-org"
        systemctl start snap.mongo33.mongod 2>/dev/null || true
        return 0
    fi

    rm -f /usr/share/keyrings/mongodb-server-7.0.gpg
    rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list

    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor || return 1

    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
        > /etc/apt/sources.list.d/mongodb-org-7.0.list

    apt-get update -y
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
    command -v mongod &>/dev/null
}

# =====================================================================
# 28) R e RStudio (v8.0.2 — instala gdebi antes)
# =====================================================================
instalar_r() {
    apt-get install -y --no-install-recommends software-properties-common dirmngr gdebi-core || return 1

    rm -f /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
        tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

    add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" -y
    apt-get update -y
    apt-get install -y --no-install-recommends r-base r-base-dev || return 1

    rm -f /tmp/rstudio.deb
    wget --timeout=60 --tries=2 \
        https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.04.2-764-amd64.deb \
        -O /tmp/rstudio.deb 2>/dev/null || true

    if [ -s /tmp/rstudio.deb ]; then
        gdebi -n /tmp/rstudio.deb || apt-get -f install -y
        rm -f /tmp/rstudio.deb
    fi
    command -v R &>/dev/null
}

# =====================================================================
# 29) Node.js (v8.0.2 — com retry)
# =====================================================================
instalar_nodejs() {
    mkdir -p /etc/apt/keyrings

    rm -f /etc/apt/keyrings/nodesource.gpg
    rm -f /etc/apt/sources.list.d/nodesource.list

    for i in 1 2 3; do
        if curl -fsSL --max-time 20 --retry 3 https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
            gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null; then
            break
        fi
        echo "==> Tentativa $i/3 de baixar a chave do NodeSource..."
        sleep 2
    done

    [ -f /etc/apt/keyrings/nodesource.gpg ] || return 1

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list

    apt-get update -y
    apt-get install -y nodejs || return 1

    mkdir -p /opt/npm
    chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/npm 2>/dev/null || true
    npm install -g @angular/cli 2>/dev/null || true
    command -v node &>/dev/null
}

# =====================================================================
# 30) Python
# =====================================================================
instalar_python() {
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
    apt-get install -y python3.10-venv python3.11-venv
    command -v python3 &>/dev/null
}

# =====================================================================
# 31) Snaps de IDEs
# =====================================================================
instalar_snaps_ides() {
    snap install eclipse --classic || true
    snap install intellij-idea-community --classic || true
    snap install mongo33 || true
    snap install bluej || true
    snap list eclipse &>/dev/null
}

# =====================================================================
# 32) Flutter
# =====================================================================
instalar_flutter() {
    rm -f /tmp/flutter.tar.xz
    wget --timeout=120 --tries=2 \
        https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.5-stable.tar.xz \
        -O /tmp/flutter.tar.xz || return 1

    [ -s /tmp/flutter.tar.xz ] || return 1
    rm -rf /opt/flutter
    tar xf /tmp/flutter.tar.xz -C /opt || return 1
    chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/flutter
    rm -f /tmp/flutter.tar.xz
    [ -x /opt/flutter/bin/flutter ]
}

# =====================================================================
# 33) Nand2Tetris
# =====================================================================
instalar_nand2tetris() {
    rm -f /tmp/nand2tetris.zip
    wget --timeout=60 --tries=2 --no-check-certificate \
        https://nuvem.ufba.br/s/ykUB6F81M5z2Ef1/download \
        -O /tmp/nand2tetris.zip || return 1

    [ -s /tmp/nand2tetris.zip ] || return 1
    unzip -o /tmp/nand2tetris.zip -d /opt
    rm -f /tmp/nand2tetris.zip
    [ -d /opt/nand2tetris ]
}

# =====================================================================
# 34) Google Chrome
# =====================================================================
instalar_chrome() {
    rm -f /tmp/chrome.deb
    wget --timeout=60 --tries=2 \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -O /tmp/chrome.deb || return 1

    [ -s /tmp/chrome.deb ] || return 1
    dpkg -i /tmp/chrome.deb || apt-get -f install -y
    rm -f /tmp/chrome.deb
    command -v google-chrome &>/dev/null
}

# =====================================================================
# 35) Android Studio
# =====================================================================
instalar_android_studio() {
    if [ ! -d /opt/Android ]; then
        rm -f /tmp/Android.tar.bz2
        wget --timeout=120 --tries=2 \
            https://nuvem.ufba.br/s/FjNaDukULOwHhs4/download \
            -O /tmp/Android.tar.bz2 || return 1
        [ -s /tmp/Android.tar.bz2 ] || return 1
        tar xjf /tmp/Android.tar.bz2 -C /opt || return 1
        rm -f /tmp/Android.tar.bz2
        ln -sf /opt/Android ${SUDO_USER:-$USER}/Android 2>/dev/null || true
    fi

    if ! snap list | grep -q android-studio; then
        snap install android-studio --classic || true
    fi

    if [ ! -d /opt/gradle ]; then
        rm -f /tmp/gradle.tar.bz2
        wget --timeout=120 --tries=2 \
            https://nuvem.ufba.br/s/U5anBL3tRpN2xhT/download \
            -O /tmp/gradle.tar.bz2 || return 1
        [ -s /tmp/gradle.tar.bz2 ] || return 1
        tar xjf /tmp/gradle.tar.bz2 -C /opt || return 1
        mv /opt/.gradle /opt/gradle 2>/dev/null || true
        chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/gradle 2>/dev/null || true
        rm -f /tmp/gradle.tar.bz2
    fi

    [ -d /opt/Android ] && [ -d /opt/gradle ]
}

# =====================================================================
# 36) Unity Hub (v8.0.2 — com retry)
# =====================================================================
instalar_unityhub() {
    add-apt-repository -y ppa:dotnet/backports || return 1

    rm -f /usr/share/keyrings/Unity_Technologies_ApS.gpg
    rm -f /etc/apt/sources.list.d/unityhub.list

    for i in 1 2 3; do
        if wget -q --timeout=20 --tries=2 -O - https://hub.unity3d.com/linux/keys/public | \
            gpg --dearmor > /usr/share/keyrings/Unity_Technologies_ApS.gpg 2>/dev/null; then
            break
        fi
        echo "==> Tentativa $i/3 de baixar a chave do Unity..."
        sleep 2
    done

    [ -s /usr/share/keyrings/Unity_Technologies_ApS.gpg ] || return 1

    echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" \
        > /etc/apt/sources.list.d/unityhub.list

    apt-get update -y
    apt-get install -y unityhub dotnet-sdk-9.0 || return 1
    command -v unityhub &>/dev/null
}

# =====================================================================
# 37) Frame0
# =====================================================================
instalar_frame0() {
    rm -f /tmp/frame0.deb
    wget --timeout=60 --tries=2 \
        https://files.frame0.app/releases/linux/x64/frame0_1.0.0~beta.8_amd64.deb \
        -O /tmp/frame0.deb || return 1

    [ -s /tmp/frame0.deb ] || return 1
    dpkg -i /tmp/frame0.deb || apt-get -f install -y
    rm -f /tmp/frame0.deb
    dpkg -l | grep -q frame0
}

# =====================================================================
# 38) Firefox (v8.0.1 — via SNAP)
# =====================================================================
instalar_firefox() {
    echo ""
    echo "=================================================="
    echo " FIREFOX: instalando via snap"
    echo "=================================================="

    pkill -9 firefox 2>/dev/null || true
    sleep 1

    echo "==> Removendo resíduos do Firefox .deb (se houver)..."
    if dpkg -l firefox 2>/dev/null | grep -qE "^(ii|rc|iU|iF|hi|hr)"; then
        apt-get purge -y firefox 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
    fi
    dpkg --purge --force-all firefox 2>/dev/null || true

    echo "==> Limpando repositórios/pins antigos..."
    rm -f /etc/apt/sources.list.d/*mozilla*        2>/dev/null
    rm -f /etc/apt/sources.list.d/*firefox*        2>/dev/null
    rm -f /etc/apt/preferences.d/firefox-no-snap   2>/dev/null
    rm -f /etc/apt/preferences.d/mozilla-firefox   2>/dev/null
    rm -f /usr/share/keyrings/packages.mozilla.org.gpg 2>/dev/null
    rm -f /etc/apt/keyrings/packages.mozilla.org.gpg   2>/dev/null

    rm -rf /opt/firefox
    rm -f  /usr/local/bin/firefox

    echo "==> Instalando Firefox via snap..."
    snap install firefox || true

    if snap list firefox &>/dev/null; then
        echo "[SUCESSO] Firefox snap instalado: $(snap list firefox | awk 'NR==2{print $2}')"
        return 0
    fi

    echo "❌ Falha ao instalar o snap do Firefox"
    return 1
}

# =====================================================================
# 39) Atalhos na dock
# =====================================================================
instalar_atalhos_dock() {
    if [ ! -f /usr/share/applications/firefox.desktop ] && \
       [ ! -f /var/lib/snapd/desktop/applications/firefox_firefox.desktop ]; then
        cat > /usr/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Name=Firefox
Name[pt_BR]=Firefox
Comment=Navegador Web
Comment[pt_BR]=Navegador Web
Exec=/snap/bin/firefox %u
Terminal=false
Type=Application
Icon=/snap/firefox/current/default256.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF
        chmod 644 /usr/share/applications/firefox.desktop
    fi

    if [ -d "/home/aluno" ]; then
        sudo -u aluno dbus-launch dconf write /org/gnome/shell/favorite-apps \
            "['firefox_firefox.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']" \
            2>/dev/null || true
    fi

    cat > /etc/profile.d/apps-dock.sh <<'EOF'
#!/bin/bash
if [ -n "$DISPLAY" ] && command -v dbus-launch &>/dev/null; then
    dbus-launch dconf write /org/gnome/shell/favorite-apps \
        "['firefox_firefox.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']" \
        2>/dev/null || true
fi
EOF
    chmod 644 /etc/profile.d/apps-dock.sh
    [ -f /etc/profile.d/apps-dock.sh ]
}

# =====================================================================
# 40) VLC Media Player
# =====================================================================
instalar_vlc() {
    apt-get install -y vlc
    command -v vlc &>/dev/null
}

# =====================================================================
# EXECUÇÃO
# =====================================================================

echo "=================================================="
echo " lab-programs.sh v8.0.2"
echo " Instalando programas com controle de estado"
echo "=================================================="

instalar_se_preciso "ssh"                instalar_ssh
instalar_se_preciso "algif-aead-block"   instalar_algif_aead_block
instalar_se_preciso "release-upgrader"   instalar_release_upgrader
instalar_se_preciso "quarto"             instalar_quarto
instalar_se_preciso "system-update"      instalar_system_update
instalar_se_preciso "clamav"             instalar_clamav
instalar_se_preciso "remover-termius"    instalar_remover_termius
instalar_se_preciso "jupyter"            instalar_jupyter
instalar_se_preciso "docker"             instalar_docker
instalar_se_preciso "avra"               instalar_avra
instalar_se_preciso "ollama"             instalar_ollama
instalar_se_preciso "sublime-text"       instalar_sublime
instalar_se_preciso "neofetch"           instalar_neofetch
instalar_se_preciso "vscode"             instalar_vscode
instalar_se_preciso "obs-studio"         instalar_obs
instalar_se_preciso "pacotes-essenciais" instalar_pacotes_essenciais
instalar_se_preciso "octave"             instalar_octave
instalar_se_preciso "racket"             instalar_racket
instalar_se_preciso "swi-prolog"         instalar_swipl
instalar_se_preciso "postgresql"         instalar_postgresql
instalar_se_preciso "pgadmin"            instalar_pgadmin
instalar_se_preciso "mysql-workbench"    instalar_mysql_workbench
instalar_se_preciso "netbeans"           instalar_netbeans
instalar_se_preciso "greenfoot"          instalar_greenfoot
instalar_se_preciso "simulide"           instalar_simulide
instalar_se_preciso "arduino"            instalar_arduino
instalar_se_preciso "wine"               instalar_wine
instalar_se_preciso "mongodb"            instalar_mongodb
instalar_se_preciso "r-rstudio"          instalar_r
instalar_se_preciso "nodejs"             instalar_nodejs
instalar_se_preciso "python"             instalar_python
instalar_se_preciso "snaps-ides"         instalar_snaps_ides
instalar_se_preciso "flutter"            instalar_flutter
instalar_se_preciso "nand2tetris"        instalar_nand2tetris
instalar_se_preciso "google-chrome"      instalar_chrome
instalar_se_preciso "android-studio"     instalar_android_studio
instalar_se_preciso "unityhub"           instalar_unityhub
instalar_se_preciso "frame0"             instalar_frame0
instalar_se_preciso "firefox"            instalar_firefox
instalar_se_preciso "atalhos-dock"       instalar_atalhos_dock
instalar_se_preciso "vlc"                instalar_vlc

# =====================================================================
# RESUMO FINAL
# =====================================================================
echo ""
echo "=================================================="
echo " ✅ Instalação concluída"
echo "=================================================="
echo ""
echo "Programas instalados (com selo):"
ls "$STATE" 2>/dev/null | sed 's/^/  ✅ /'
echo ""
echo "Total: $(ls "$STATE" 2>/dev/null | wc -l) programas"
echo ""
echo "=================================================="
echo " Como usar:"
echo "=================================================="
echo "  Listar instalados:      ls $STATE/"
echo "  Forçar reinstalação:    rm $STATE/NOME"
echo "  Ex: forçar Firefox:     rm $STATE/firefox"
echo "                          systemctl restart labstartup"
echo ""
echo "Firefox:"
readlink -f "$(which firefox 2>/dev/null)" 2>/dev/null || echo "  (não instalado)"
echo ""
echo "Chrome:"
command -v google-chrome 2>/dev/null || echo "  (não instalado)"
echo ""
echo "=================================================="

exit 0

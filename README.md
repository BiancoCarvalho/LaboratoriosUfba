# lab-scripts

Scripts para automatizar instalação de pacotes e configurações em geral em computadores dos laboratórios do Instituto de Computação.

## Instalação

Para instalar o script de atualização na máquina, execute o seguinte comando **como usuário root**:

```
wget -4 -O - https://raw.githubusercontent.com/BiancoCarvalho/lab-scripts/main/install.sh | /bin/bash
```

O script `lab-startup.sh` será executado a cada inicialização da máquina.

Após a instalação, reinicie a máquina e execute o seguinte comando para visualizar o log:

```
journalctl -fu labstartup.service
```

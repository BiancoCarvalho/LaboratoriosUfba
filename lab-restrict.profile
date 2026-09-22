#include <tunables/global>

profile lab-restrict flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ssl_certs>
  #include <abstractions/audio>
  #include <abstractions/fonts>
  #include <abstractions/dbus-session>

  # Navegadores permitidos (o lab-block.sh reescreve este bloco)
  /usr/bin/firefox        ixr,
  /usr/bin/google-chrome  ixr,
  /usr/bin/chromium       ixr,
  /snap/bin/firefox       ixr,

  # Bloqueia execução de qualquer outro binário
  deny /usr/bin/**         x,
  deny /usr/local/bin/**   x,
  deny /snap/bin/**        x,
  deny /opt/**             x,
  deny /home/**/bin/**     x,
  deny /home/**/*.AppImage x,

  network inet stream,
  network inet6 stream,

  owner @{HOME}/.mozilla/**              rwk,
  owner @{HOME}/.config/google-chrome/** rwk,
  owner @{HOME}/.config/chromium/**      rwk,

  /tmp/**     rwk,
  /dev/shm/** rwk,
}

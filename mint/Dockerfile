FROM linuxmintd/mint20-amd64

ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y \
      cinnamon-desktop-environment \
      xrdp \
      xorg \
      sudo \
      dbus-x11 \
      xterm \
      lxterminal \
      locales

RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME}

RUN mkdir -p /var/run/xrdp /run/xrdp && \
    chown xrdp:xrdp /var/run/xrdp /run/xrdp

# Use Cinnamon session for XRDP
# RUN sed -i.bak 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|cinnamon-session|g' \
#       /etc/xrdp/startwm.sh || true

RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'dbus-daemon --system --nofork &' \
    '/usr/sbin/xrdp-sesman &' \
    'exec /usr/sbin/xrdp -nodaemon' \
    > /usr/local/bin/start-xrdp.sh \
    && chmod +x /usr/local/bin/start-xrdp.sh

RUN printf '%s\n' \
    '#!/bin/sh' \
    '. /etc/profile' \
    'export GNOME_SHELL_SESSION_MODE=cinnamon' \
    'export XDG_SESSION_DESKTOP=cinnamon' \
    'export XDG_CURRENT_DESKTOP=cinnamon' \
    'cinnamon-session' \
    > /etc/xrdp/startwm.sh \
    && chmod +x /etc/xrdp/startwm.sh



EXPOSE 3389

WORKDIR /home/${USER_NAME}

ENTRYPOINT ["/usr/local/bin/start-xrdp.sh"]

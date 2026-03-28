FROM linuxmintd/mint21.3-amd64

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
      openssl \
      locales

# Generate XRDP SSL certificates (required for xrdp to start)
RUN openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/xrdp/key.pem \
    -out /etc/xrdp/cert.pem -days 365 \
    -subj "/C=US/ST=State/L=City/O=Org/CN=xrdp" && \
    chmod 600 /etc/xrdp/key.pem

RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME}

RUN mkdir -p /var/run/xrdp /run/xrdp && \
    chown xrdp:xrdp /var/run/xrdp /run/xrdp

# Configure XRDP logging level and fuse mount directory for session channels
RUN if [ -f /etc/xrdp/xrdp.ini ]; then \
    sed -i 's/^LogLevel=.*/LogLevel=DEBUG/' /etc/xrdp/xrdp.ini 2>/dev/null || true; \
    grep -q "^LogLevel=" /etc/xrdp/xrdp.ini || printf '\n[Logging]\nLogLevel=DEBUG\n' >> /etc/xrdp/xrdp.ini; \
    fi && \
    if [ -f /etc/xrdp/sesman.ini ]; then \
    sed -i 's|^FuseMountName=.*|FuseMountName=/tmp/.xrdp|' /etc/xrdp/sesman.ini 2>/dev/null || true; \
    grep -q "^FuseMountName=" /etc/xrdp/sesman.ini || echo "FuseMountName=/tmp/.xrdp" >> /etc/xrdp/sesman.ini; \
    fi

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

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD pgrep -x xrdp > /dev/null || exit 1

WORKDIR /home/${USER_NAME}

ENTRYPOINT ["/usr/local/bin/start-xrdp.sh"]

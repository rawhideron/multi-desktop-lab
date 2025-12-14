FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1001
ARG GID=1001

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xorg \
    xorgxrdp \
    dbus-x11 \
    x11-xserver-utils \
    xrdp \
    sudo \
    locales  \
    locale-gen en_US.UTF-8  \
    update-locale LANG=en_US.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Allow xrdp to start Xorg
RUN sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config 2>/dev/null || \
    printf 'allowed_users=anybody\n' > /etc/X11/Xwrapper.config

# Create user with password
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME}

# Configure XRDP startwm.sh - SIMPLIFIED: use xfce4-session directly
RUN printf '#!/bin/sh\n\
# Unset problematic environment variables\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
unset XDG_RUNTIME_DIR\n\
\n\
# Load locale if available\n\
if [ -r /etc/default/locale ]; then\n\
    . /etc/default/locale\n\
    export LANG LANGUAGE\n\
fi\n\
\n\
# Wait for X server to be ready\n\
sleep 2\n\
\n\
# Start XFCE session directly (more reliable for XRDP)\n\
exec xfce4-session\n' > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# Set user's default X session
RUN echo "xfce4-session" > /home/${USER_NAME}/.xsession && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.xsession && \
    chmod +x /home/${USER_NAME}/.xsession

# Configure reconnectwm.sh for session reconnection
RUN printf '#!/bin/sh\n\
# Unset problematic environment variables\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
unset XDG_RUNTIME_DIR\n\
\n\
# Load locale if available\n\
if [ -r /etc/default/locale ]; then\n\
    . /etc/default/locale\n\
    export LANG LANGUAGE\n\
fi\n\
\n\
# Wait for X server to be ready\n\
sleep 2\n\
\n\
# Restart XFCE session on reconnect\n\
exec xfce4-session\n' > /etc/xrdp/reconnectwm.sh && \
    chmod +x /etc/xrdp/reconnectwm.sh

# Make sure xrdp can access the SSL certs
RUN adduser xrdp ssl-cert || true

# Create startup script - FIXED: run sesman in background, xrdp in foreground
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
# Set password from environment if provided\n\
if [ -n "$USER_PASSWORD" ] && [ -n "$USER_NAME" ]; then\n\
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd\n\
    # Always ensure .xsession is correct (volume may override)\n\
    if [ -d "/home/$USER_NAME" ]; then\n\
        echo "xfce4-session" > /home/$USER_NAME/.xsession\n\
        chown $USER_NAME:$USER_NAME /home/$USER_NAME/.xsession 2>/dev/null || true\n\
        chmod +x /home/$USER_NAME/.xsession\n\
    fi\n\
fi\n\
\n\
# Clean up stale files\n\
rm -f /var/run/xrdp/xrdp-sesman.pid\n\
rm -rf /var/run/xrdp/sockdir/*\n\
\n\
# Create required directories\n\
mkdir -p /var/log/xrdp /var/run/xrdp/sockdir\n\
chmod 755 /var/log/xrdp /var/run/xrdp /var/run/xrdp/sockdir\n\
\n\
# Start system DBUS if not running\n\
if [ ! -S /run/dbus/system_bus_socket ]; then\n\
    mkdir -p /var/lib/dbus /var/run/dbus\n\
    dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true\n\
    dbus-daemon --system --fork --nopidfile 2>/dev/null || true\n\
    sleep 1\n\
fi\n\
\n\
# Start xrdp-sesman in background\n\
/usr/sbin/xrdp-sesman &\n\
\n\
# Wait for sesman to be ready\n\
sleep 3\n\
if ! pgrep -x xrdp-sesman > /dev/null; then\n\
    echo "ERROR: xrdp-sesman failed to start" >&2\n\
    cat /var/log/xrdp-sesman.log 2>/dev/null || true\n\
    exit 1\n\
fi\n\
echo "xrdp-sesman started successfully"\n\
\n\
# Start xrdp in foreground (this keeps container running)\n\
exec /usr/sbin/xrdp -nodaemon\n' > /usr/local/bin/start-xrdp.sh && \
    chmod +x /usr/local/bin/start-xrdp.sh

# Add troubleshooting helper (if script exists)
COPY scripts/collect-info.sh /usr/local/bin/collect-info.sh
RUN chmod +x /usr/local/bin/collect-info.sh

# Create required directories
RUN mkdir -p /var/log/xrdp /var/run/xrdp/sockdir && \
    chmod 755 /var/log/xrdp /var/run/xrdp /var/run/xrdp/sockdir

EXPOSE 3389

WORKDIR /home/${USER_NAME}

CMD ["/usr/local/bin/start-xrdp.sh"]

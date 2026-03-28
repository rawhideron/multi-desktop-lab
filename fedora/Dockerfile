FROM fedora:41

ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1000
ARG GID=1000

# Install GNOME Workstation + XRDP + sudo
# dnf5 doesn't support groups, so install GNOME packages individually
RUN dnf -y update && \
    dnf -y install \
      gnome-shell \
      gnome-terminal \
      gnome-session \
      gnome-settings-daemon \
      nautilus \
      gdm \
      xorg-x11-server-Xorg \
      xorg-x11-xinit \
      xrdp \
      sudo \
      openssl \
      dbus-x11 && \
    dnf clean all

# Generate XRDP SSL certificates (required for xrdp to start)
RUN openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/xrdp/key.pem \
    -out /etc/xrdp/cert.pem -days 365 \
    -subj "/C=US/ST=State/L=City/O=Org/CN=xrdp" && \
    chmod 600 /etc/xrdp/key.pem

# User & sudo (Fedora typically uses 'wheel' for sudoers)
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | passwd --stdin ${USER_NAME} || \
    (echo "${USER_PASSWORD}" | passwd --stdin ${USER_NAME}) && \
    usermod -aG wheel,sudo ${USER_NAME} && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-wheel && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-wheel && \
    chmod 440 /etc/sudoers.d/90-wheel

# Create xrdp log and run directories
RUN mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir 2>/dev/null || true

# Use gnome-session for XRDP
RUN sed -i.bak 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|gnome-session|g' \
      /etc/xrdp/startwm.sh || true

# Start script that creates directories and starts xrdp
RUN printf '#!/bin/bash\n\
set -e\n\
# Create necessary directories with sudo\n\
sudo mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir\n\
sudo chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir\n\
sudo chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir 2>/dev/null || true\n\
# Start system DBUS if not already running (required by desktop environments)\n\
if [ ! -S /run/dbus/system_bus_socket ]; then\n\
    sudo mkdir -p /var/run/dbus /var/lib/dbus\n\
    sudo dbus-uuidgen --ensure 2>/dev/null || true\n\
    sudo dbus-daemon --system --fork --nopidfile 2>/dev/null || true\n\
    sleep 1\n\
fi\n\
# Start xrdp-sesman with sudo\n\
sudo /usr/sbin/xrdp-sesman &\n\
# Wait a moment for sesman to start\n\
sleep 2\n\
# Start xrdp with sudo (needs root to bind to port 3389)\n\
exec sudo /usr/sbin/xrdp -nodaemon\n' > /usr/local/bin/start-xrdp.sh && \
    chmod +x /usr/local/bin/start-xrdp.sh

EXPOSE 3389

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

CMD ["/usr/local/bin/start-xrdp.sh"]

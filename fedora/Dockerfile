FROM fedora:latest

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
      dbus-x11 && \
    dnf clean all

# User & sudo (Fedora typically uses 'wheel' for sudoers)
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | passwd --stdin ${USER_NAME} || \
    (echo "${USER_PASSWORD}" | passwd --stdin ${USER_NAME}) && \
    usermod -aG wheel ${USER_NAME} && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-wheel && \
    chmod 440 /etc/sudoers.d/90-wheel

# Use gnome-session for XRDP
RUN sed -i.bak 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|gnome-session|g' \
      /etc/xrdp/startwm.sh || true

RUN printf '#!/bin/bash\nset -e\n/usr/sbin/xrdp-sesman &\nexec /usr/sbin/xrdp -nodaemon\n' \
      > /usr/local/bin/start-xrdp.sh && \
    chmod +x /usr/local/bin/start-xrdp.sh

EXPOSE 3389

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

CMD ["/usr/local/bin/start-xrdp.sh"]

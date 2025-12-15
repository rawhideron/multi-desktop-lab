FROM fedora:latest

ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1000
ARG GID=1000

# Install GNOME Workstation + XRDP + sudo
# Fedora uses dnf5 which requires the groupinstall plugin
RUN dnf -y update && \
    dnf -y install 'dnf5-command(groupinstall)' && \
    dnf -y groupinstall "Workstation" && \
    dnf -y install xrdp sudo dbus-x11 && \
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

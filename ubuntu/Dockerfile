FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

# --- Desktop & XRDP ---
RUN apt-get update && \
    apt-get install -y ubuntu-desktop xrdp sudo dbus-x11 locales && \
    locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# ===== USER AUTO-DETECT =====
ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1000
ARG GID=1000

RUN getent group ${GID} >/dev/null || groupadd -g ${GID} ${USER_NAME}
RUN id -u ${USER_NAME} &>/dev/null || \
    (getent passwd ${UID} >/dev/null && useradd -m -s /bin/bash ${USER_NAME} -g ${GID} || \
     useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME}) && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME}

# XRDP → GNOME session
RUN sed -i.bak 's|test -x /etc/X11/Xsession && exec /etc/X11/Xsession|gnome-session|g' /etc/xrdp/startwm.sh

# XRDP start script
RUN echo -e '#!/bin/bash\n/usr/sbin/xrdp-sesman &\nexec /usr/sbin/xrdp -nodaemon' \
    > /usr/local/bin/start-xrdp.sh && chmod +x /usr/local/bin/start-xrdp.sh

EXPOSE 3389
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}
CMD ["/usr/local/bin/start-xrdp.sh"]

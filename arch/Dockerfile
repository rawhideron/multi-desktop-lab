FROM archlinux:latest

ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1000
ARG GID=1000

# Faster non-interactive pacman
RUN sed -i 's/^#Color/Color/' /etc/pacman.conf && \
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Install base packages and build tools needed for AUR
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      base-devel \
      git \
      gnome \
      gnome-terminal \
      xorg-server \
      xorg-xinit \
      sudo && \
    pacman -Scc --noconfirm

# Install yay AUR helper (needs non-root user)
RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    sudo -u builder bash -c "cd /tmp && \
      git clone https://aur.archlinux.org/yay.git && \
      cd yay && \
      makepkg -si --noconfirm --skipinteg" && \
    rm -rf /tmp/yay

# Install xrdp from AUR using yay
RUN sudo -u builder yay -S --noconfirm xrdp --noprovides --skipinteg || \
    (echo "yay failed, trying manual build" && \
     cd /tmp && \
     git clone https://aur.archlinux.org/xrdp.git && \
     cd xrdp && \
     sudo -u builder makepkg -si --noconfirm --skipinteg && \
     cd / && \
     rm -rf /tmp/xrdp)

# Clean up builder user and sudoers entry
RUN userdel -r builder 2>/dev/null || true && \
    sed -i '/^builder/d' /etc/sudoers 2>/dev/null || true

# User / sudo (Arch uses 'wheel')
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG wheel ${USER_NAME} && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-wheel && \
    chmod 440 /etc/sudoers.d/90-wheel

# XRDP with gnome-session
RUN sed -i.bak 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|gnome-session|g' \
      /etc/xrdp/startwm.sh || true

RUN printf '#!/bin/bash\nset -e\n/usr/sbin/xrdp-sesman &\nexec /usr/sbin/xrdp -nodaemon\n' \
      > /usr/local/bin/start-xrdp.sh && \
    chmod +x /usr/local/bin/start-xrdp.sh

EXPOSE 3389

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

CMD ["/usr/local/bin/start-xrdp.sh"]

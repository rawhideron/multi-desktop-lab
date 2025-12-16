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
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 440 /etc/sudoers.d/builder && \
    sudo -u builder bash -c "cd /tmp && \
      git clone https://aur.archlinux.org/yay.git && \
      cd yay && \
      makepkg -s --noconfirm --skipinteg && \
      sudo pacman -U --noconfirm *.pkg.tar.*" && \
    rm -rf /tmp/yay

# Install xrdp from AUR using yay
RUN sudo -u builder yay -S --noconfirm xrdp --skipinteg || \
    (echo "yay failed, trying manual build" && \
     mkdir -p /tmp/xrdp-build && \
     chown builder:builder /tmp/xrdp-build && \
     sudo -u builder bash -c "cd /tmp/xrdp-build && \
       git clone https://aur.archlinux.org/xrdp.git && \
       cd xrdp && \
       makepkg -s --noconfirm --skipinteg && \
       sudo pacman -U --noconfirm *.pkg.tar.*" && \
     rm -rf /tmp/xrdp-build)

# Clean up builder user and sudoers entry
RUN rm -f /etc/sudoers.d/builder 2>/dev/null || true && \
    userdel -r builder 2>/dev/null || true

# User / sudo (Arch uses 'wheel')
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG wheel ${USER_NAME} && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-wheel && \
    chmod 440 /etc/sudoers.d/90-wheel

# Create xrdp log and run directories
RUN mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp 2>/dev/null || true

# XRDP with gnome-session
RUN sed -i.bak 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|gnome-session|g' \
      /etc/xrdp/startwm.sh || true

# Start script that creates directories and starts xrdp
RUN printf '#!/bin/bash\n\
set -e\n\
# Create necessary directories with sudo\n\
sudo mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir\n\
sudo chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir\n\
sudo chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp 2>/dev/null || true\n\
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

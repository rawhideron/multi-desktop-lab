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
      bash \
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

# Install xrdp and xorgxrdp from AUR using yay
RUN sudo -u builder yay -S --noconfirm xrdp xorgxrdp --skipinteg || \
    (echo "yay failed, trying manual build" && \
     mkdir -p /tmp/xrdp-build && \
     chown builder:builder /tmp/xrdp-build && \
     sudo -u builder bash -c "cd /tmp/xrdp-build && \
       git clone https://aur.archlinux.org/xrdp.git && \
       cd xrdp && \
       makepkg -s --noconfirm --skipinteg && \
       sudo pacman -U --noconfirm *.pkg.tar.* && \
       cd .. && \
       git clone https://aur.archlinux.org/xorgxrdp.git && \
       cd xorgxrdp && \
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

# Allow xrdp to start Xorg (required for X server to start)
RUN mkdir -p /etc/X11 && \
    sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config 2>/dev/null || \
    printf 'allowed_users=anybody\n' > /etc/X11/Xwrapper.config

# Create xrdp log and run directories
RUN mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir && \
    chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir 2>/dev/null || true

# Configure xrdp to use Xorg instead of VNC
RUN mkdir -p /etc/xrdp && \
    # Create proper xrdp.ini with Xorg as default and VNC disabled
    cat > /etc/xrdp/xrdp.ini << 'EOF'
[globals]
bitmap_cache=true
bitmap_compression=true
port=3389
crypt_level=low
channel_code=1
max_bpp=24
#xserverbpp=24
#xrdp.ini file version number
ini_version=1

[logging]
LogFile=xrdp.log
LogLevel=INFO
EnableSyslog=true
SyslogLevel=INFO
#EnableSyslogLevel=DEBUG

[Channels]
# Channel names not listed in [Channels] will be blocked by default
# This will be overridden by [Channels] in sesman.ini
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true
rail=true
xrdpvr=true
tcutils=true

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
xserverbpp=24
code=20
EOF

# Configure sesman.ini to use Xorg as default
RUN mkdir -p /etc/xrdp && \
    if [ -f /etc/xrdp/sesman.ini ]; then \
      # Set Xorg as default session type
      sed -i 's/^DefaultWindowManager=.*/DefaultWindowManager=startwm.sh/' /etc/xrdp/sesman.ini 2>/dev/null || true; \
      sed -i 's/^UserWindowManager=.*/UserWindowManager=false/' /etc/xrdp/sesman.ini 2>/dev/null || true; \
      sed -i 's/^RestartWindowManager=.*/RestartWindowManager=false/' /etc/xrdp/sesman.ini 2>/dev/null || true; \
    fi

# XRDP with gnome-session - create proper startwm.sh
RUN cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
# xrdp X session start script (c) 2015, 2017 mirabilos
# published under The MirOS Licence

if test -r /etc/profile; then
        . /etc/profile
fi

if test -r /etc/default/locale; then
        . /etc/default/locale
        test -z "${LANG+x}" || export LANG
        test -z "${LANGUAGE+x}" || export LANGUAGE
        test -z "${LC_ALL+x}" || export LC_ALL
        test -z "${LC_COLLATE+x}" || export LC_COLLATE
        test -z "${LC_CTYPE+x}" || export LC_CTYPE
        test -z "${LC_MESSAGES+x}" || export LC_MESSAGES
        test -z "${LC_MONETARY+x}" || export LC_MONETARY
        test -z "${LC_NUMERIC+x}" || export LC_NUMERIC
        test -z "${LC_TIME+x}" || export LC_TIME
fi

if test -r /etc/profile; then
        . /etc/profile
fi

# Unset problematic environment variables
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

# Start GNOME session
exec gnome-session
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Start script that creates directories and starts xrdp
RUN cat > /usr/local/bin/start-xrdp.sh << 'EOF'
#!/bin/bash
# Don't redirect output - let it go to stdout/stderr naturally

echo "Starting xrdp services..."

# Create necetart-xrdpsary directories with proper permissions
sudo mkdir -p /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir
sudo chmod 755 /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir
sudo chown -R xrdp:xrdp /var/log/xrdp /var/run/xrdp /run/xrdp /var/run/xrdp/sockdir 2>/dev/null || true

# Create user-specific socket directories (for UID 1000 and other common UIDs)
for uid in 1000 1001 1002; do
    sudo mkdir -p /var/run/xrdp/${uid}
    sudo chmod 755 /var/run/xrdp/${uid}
    sudo chown ${uid}:${uid} /var/run/xrdp/${uid} 2>/dev/null || true
done

# Also create for current user's UID
CURRENT_UID=$(id -u)
sudo mkdir -p /var/run/xrdp/${CURRENT_UID}
sudo chmod 755 /var/run/xrdp/${CURRENT_UID}
sudo chown ${CURRENT_UID}:${CURRENT_UID} /var/run/xrdp/${CURRENT_UID} 2>/dev/null || true

# Clean up any stale pid files
sudo rm -f /var/run/xrdp/xrdp-sesman.pid /var/run/xrdp/xrdp.pid 2>/dev/null || true

# Start xrdp-sesman with sudo
echo "Starting xrdp-sesman..."
sudo /usr/sbin/xrdp-sesman &
SESMAN_PID=$!

# Wait for sesman to start and verify it's running
for i in {1..10}; do
    if pgrep -x xrdp-sesman > /dev/null 2>&1; then
        echo "xrdp-sesman is running (PID: ${SESMAN_PID})"
        break
    fi
    sleep 1
done

if ! pgrep -x xrdp-sesman > /dev/null 2>&1; then
    echo "ERROR: xrdp-sesman failed to start after 10 seconds"
    sudo cat /var/log/xrdp-sesman.log 2>/dev/null || true
    exit 1
fi

# Wait for sesman socket to be created
echo "Waiting for sesman socket..."
for i in {1..10}; do
    if [ -S /var/run/xrdp/sockdir/sesman.socket ]; then
        echo "sesman socket found"
        break
    fi
    sleep 1
done

if [ ! -S /var/run/xrdp/sockdir/sesman.socket ]; then
    echo "WARNING: sesman socket not found after 10 seconds, continuing anyway..."
fi

# Start xrdp with sudo (needs root to bind to port 3389)
echo "Starting xrdp..."
# Check if xrdp binary exists and is executable
if [ ! -x /usr/sbin/xrdp ]; then
    echo "ERROR: /usr/sbin/xrdp not found or not executable"
    exit 1
fi

# Use exec to replace shell with xrdp process - this keeps container running
# Run xrdp in foreground - if it exits, container will restart (which is what we want)
exec sudo /usr/sbin/xrdp -nodaemon
EOF

RUN chmod +x /usr/local/bin/start-xrdp.sh

EXPOSE 3389

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

ENTRYPOINT ["/bin/bash", "/usr/local/bin/start-xrdp.sh"]

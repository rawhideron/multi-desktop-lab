# ===== BUILDER STAGE =====
FROM debian:latest AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments (only used in builder stage)
ARG USER_NAME
ARG USER_PASSWORD
ARG UID=1001
ARG GID=1001

# --- Desktop & XRDP Package Installation ---
RUN apt-get update && \
    apt-get install -y kde-plasma-desktop xrdp sudo dbus-x11 locales && \
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# Create .xsession template file
RUN printf '#!/bin/sh\n\
export XDG_SESSION_TYPE=x11\n\
export XDG_SESSION_DESKTOP=KDE\n\
export XDG_CURRENT_DESKTOP=KDE\n\
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then\n\
\teval $(dbus-launch --sh-syntax --exit-with-session)\n\
fi\n\
exec startplasma-x11\n' > /tmp/.xsession-template && \
    chmod +x /tmp/.xsession-template

# ===== USER SETUP (with password - only in builder) =====
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME} && \
    cp /tmp/.xsession-template /home/${USER_NAME}/.xsession && \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME} && \
    chmod +x /home/${USER_NAME}/.xsession

# XRDP → KDE Plasma session configuration
RUN printf '#!/bin/sh\n\
# xrdp X session start script\n\
\n\
if test -r /etc/profile; then\n\
\t. /etc/profile\n\
fi\n\
\n\
if test -r ~/.profile; then\n\
\t. ~/.profile\n\
fi\n\
\n\
# Wait for X server to be ready (check socket exists)\n\
for i in 1 2 3 4 5; do\n\
\tif [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ] || [ -S "/tmp/.X11-unix/X$(echo $DISPLAY | cut -d: -f2 | cut -d. -f1)" ]; then\n\
\t\tbreak\n\
\tfi\n\
\tsleep 1\n\
done\n\
sleep 2\n\
\n\
# Set KDE environment variables\n\
export XDG_SESSION_TYPE=x11\n\
export XDG_SESSION_DESKTOP=KDE\n\
export XDG_CURRENT_DESKTOP=KDE\n\
\n\
# Create and set XDG_RUNTIME_DIR (must be done before DBUS and Plasma start)\n\
export XDG_RUNTIME_DIR=/run/user/$(id -u)\n\
mkdir -p "$XDG_RUNTIME_DIR"\n\
chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR" 2>/dev/null || true\n\
chmod 700 "$XDG_RUNTIME_DIR"\n\
\n\
# Start DBUS session if not running\n\
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then\n\
\teval $(dbus-launch --sh-syntax --exit-with-session)\n\
fi\n\
\n\
# Ensure system DBUS is accessible\n\
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket\n\
\n\
# Ensure XDG_RUNTIME_DIR is exported for all child processes\n\
export XDG_RUNTIME_DIR\n\
\n\
# Ensure XDG_RUNTIME_DIR permissions are correct before starting Plasma\n\
chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR" 2>/dev/null || true\n\
chmod 700 "$XDG_RUNTIME_DIR"\n\
\n\
# Start KDE Plasma in background and wait a moment for it to initialize\n\
startplasma-x11 &\n\
PLASMA_PID=$!\n\
sleep 5\n\
\n\
# Explicitly start plasmashell if not already running (with proper environment)\n\
if ! pgrep -x plasmashell > /dev/null; then\n\
\texport XDG_RUNTIME_DIR\n\
\texport DISPLAY\n\
\tplasmashell --no-respawn > /tmp/plasmashell.log 2>&1 &\n\
\tsleep 2\n\
fi\n\
\n\
# Wait for plasma session to complete\n\
wait $PLASMA_PID\n' > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# Configure XRDP polkit policy
RUN mkdir -p /etc/polkit-1/localauthority/50-local.d && \
    printf '[Allow Colord all Users]\nIdentity=unix-user:*\nAction=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile\nResultAny=no\nResultInactive=no\nResultActive=yes\n\n[Allow Package Management all Users]\nIdentity=unix-user:*\nAction=org.debian.apt.*;io.snapcraft.*;org.freedesktop.packagekit.*;com.ubuntu.update-notifier.*\nResultAny=no\nResultInactive=no\nResultActive=yes\n' > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla

# Fix XRDP Xorg configuration to prevent /dev/tty0 access issues
RUN if [ -f /etc/X11/xrdp/xorg.conf ]; then \
    sed -i '/Option "DontVTSwitch" "on"/a\    Option "DontZap" "on"\n    Option "DontZoom" "on"\n    Option "AutoEnableDevices" "false"' /etc/X11/xrdp/xorg.conf || true; \
    fi

# Create startup script (will be copied to final stage)
RUN echo '#!/bin/bash' > /usr/local/bin/start-xrdp.sh && \
    echo 'set -e' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo '# Fix /dev/tty0 permissions for X server' >> /usr/local/bin/start-xrdp.sh && \
    echo 'chmod 666 /dev/tty0 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo 'USER_HOME=$(ls -d /home/*/ 2>/dev/null | head -1 | sed "s|/home/||" | sed "s|/||")' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ -z "$USER_HOME" ] || [ ! -d "/home/$USER_HOME" ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	USER_HOME="${USER_NAME}"' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo '# Set password from environment variable if provided' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ -n "$USER_PASSWORD" ] && id "$USER_HOME" &>/dev/null; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	echo "$USER_HOME:$USER_PASSWORD" | chpasswd' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ -d "/home/$USER_HOME" ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	chown -R $USER_HOME:$USER_HOME /home/$USER_HOME 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ ! -f "/home/$USER_HOME/.xsession" ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	cp /tmp/.xsession-template /home/$USER_HOME/.xsession' >> /usr/local/bin/start-xrdp.sh && \
    echo '	chown $USER_HOME:$USER_HOME /home/$USER_HOME/.xsession' >> /usr/local/bin/start-xrdp.sh && \
    echo '	chmod +x /home/$USER_HOME/.xsession' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo 'mkdir -p /var/log/xrdp /var/run/xrdp' >> /usr/local/bin/start-xrdp.sh && \
    echo 'chmod 755 /var/log/xrdp /var/run/xrdp' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo '# Pre-create XDG_RUNTIME_DIR for user (needs to exist before window manager starts)' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ -n "$USER_HOME" ] && id "$USER_HOME" &>/dev/null; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	USER_ID=$(id -u "$USER_HOME" 2>/dev/null)' >> /usr/local/bin/start-xrdp.sh && \
    echo '	if [ -n "$USER_ID" ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '		mkdir -p /run/user/$USER_ID' >> /usr/local/bin/start-xrdp.sh && \
    echo '		chown $USER_HOME:$USER_HOME /run/user/$USER_ID 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo '		chmod 700 /run/user/$USER_ID' >> /usr/local/bin/start-xrdp.sh && \
    echo '	fi' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo '# Start system DBUS if not running (required for KDE)' >> /usr/local/bin/start-xrdp.sh && \
    echo 'if [ ! -S /run/dbus/system_bus_socket ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '	mkdir -p /var/run/dbus /var/lib/dbus /etc' >> /usr/local/bin/start-xrdp.sh && \
    echo '	# Generate machine-id if missing or invalid' >> /usr/local/bin/start-xrdp.sh && \
    echo '	if [ ! -f /var/lib/dbus/machine-id ] || [ ! -s /var/lib/dbus/machine-id ] || [ $(wc -c < /var/lib/dbus/machine-id) -ne 33 ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '		dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo '	fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '	# Also create /etc/machine-id (some apps check this)' >> /usr/local/bin/start-xrdp.sh && \
    echo '	if [ ! -f /etc/machine-id ] || [ ! -s /etc/machine-id ] || [ $(wc -c < /etc/machine-id) -ne 33 ]; then' >> /usr/local/bin/start-xrdp.sh && \
    echo '		cp /var/lib/dbus/machine-id /etc/machine-id 2>/dev/null || dbus-uuidgen > /etc/machine-id 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo '	fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '	# Start DBUS with minimal config to avoid user/group errors' >> /usr/local/bin/start-xrdp.sh && \
    echo '	dbus-daemon --system --fork --nopidfile --nosyslog 2>/dev/null || \\' >> /usr/local/bin/start-xrdp.sh && \
    echo '	dbus-daemon --config-file=/usr/share/dbus-1/system.conf --system --fork --nopidfile 2>/dev/null || true' >> /usr/local/bin/start-xrdp.sh && \
    echo '	sleep 2' >> /usr/local/bin/start-xrdp.sh && \
    echo 'fi' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo '# Start xrdp-sesman and wait for it to be ready' >> /usr/local/bin/start-xrdp.sh && \
    echo 'rm -f /var/run/xrdp/xrdp-sesman.pid' >> /usr/local/bin/start-xrdp.sh && \
    echo '/usr/sbin/xrdp-sesman &' >> /usr/local/bin/start-xrdp.sh && \
    echo 'sleep 2' >> /usr/local/bin/start-xrdp.sh && \
    echo '' >> /usr/local/bin/start-xrdp.sh && \
    echo 'exec /usr/sbin/xrdp -nodaemon' >> /usr/local/bin/start-xrdp.sh && \
    chmod +x /usr/local/bin/start-xrdp.sh

# ===== FINAL STAGE =====
FROM debian:latest
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments for final stage (without password)
ARG USER_NAME
ARG UID=1001
ARG GID=1001

# Copy installed packages and system files from builder (excluding password files)
COPY --from=builder /usr /usr
COPY --from=builder /lib /lib
COPY --from=builder /lib64 /lib64
COPY --from=builder /bin /bin
COPY --from=builder /sbin /sbin
COPY --from=builder /opt /opt

# Copy /etc selectively (excluding shadow and passwd files with password hashes)
COPY --from=builder /etc/xrdp /etc/xrdp
COPY --from=builder /etc/polkit-1 /etc/polkit-1
COPY --from=builder /etc/sudoers /etc/sudoers
COPY --from=builder /etc/sudoers.d /etc/sudoers.d
COPY --from=builder /etc/locale.gen /etc/locale.gen
COPY --from=builder /etc/default /etc/default
COPY --from=builder /etc/environment /etc/environment
COPY --from=builder /etc/ssl /etc/ssl
COPY --from=builder /etc/X11 /etc/X11
COPY --from=builder /etc/dbus-1 /etc/dbus-1
COPY --from=builder /etc/fonts /etc/fonts

# Create DBUS runtime directories and generate machine-id
RUN mkdir -p /var/lib/dbus /var/run/dbus /etc && \
    dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true && \
    cp /var/lib/dbus/machine-id /etc/machine-id 2>/dev/null || true

# Ensure XRDP Xorg config has proper settings to avoid /dev/tty0 issues
RUN if [ -f /etc/X11/xrdp/xorg.conf ]; then \
    sed -i '/Option "DontVTSwitch" "on"/a\    Option "DontZap" "on"\n    Option "DontZoom" "on"\n    Option "AutoEnableDevices" "false"' /etc/X11/xrdp/xorg.conf || true; \
    fi

# Copy /var selectively (excluding user data)
COPY --from=builder /var/lib/dpkg /var/lib/dpkg
COPY --from=builder /var/lib/apt /var/lib/apt
COPY --from=builder /var/cache /var/cache

# Clean up dpkg statoverride file - remove entries for groups/users that don't exist
RUN if [ -f /var/lib/dpkg/statoverride ]; then \
    while IFS= read -r line; do \
        if [ -n "$line" ] && [ "${line#Removing}" = "$line" ]; then \
            group=$(echo "$line" | awk '{print $2}'); \
            user=$(echo "$line" | awk '{print $1}'); \
            if [ -n "$group" ] && ! getent group "$group" > /dev/null 2>&1; then \
                :; \
            elif [ -n "$user" ] && [ "$user" != "root" ] && ! getent passwd "$user" > /dev/null 2>&1; then \
                :; \
            else \
                echo "$line"; \
            fi; \
        fi; \
    done < /var/lib/dpkg/statoverride > /var/lib/dpkg/statoverride.tmp && \
    mv /var/lib/dpkg/statoverride.tmp /var/lib/dpkg/statoverride || true; \
    fi

# Copy configuration files and templates
COPY --from=builder /usr/local/bin/start-xrdp.sh /usr/local/bin/start-xrdp.sh
COPY --from=builder /tmp/.xsession-template /tmp/.xsession-template

# Substitute USER_NAME in startup script
RUN sed -i "s|\${USER_NAME}|${USER_NAME}|g" /usr/local/bin/start-xrdp.sh

# Create user WITHOUT password (password will be set at runtime from environment variable)
RUN groupadd -g ${GID} ${USER_NAME} || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER_NAME} && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USER_NAME} && \
    chmod 440 /etc/sudoers.d/90-${USER_NAME}

# Create messagebus user for DBUS (required for system DBUS)
RUN groupadd -r messagebus || true && \
    useradd -r -g messagebus -d /var/run/dbus -s /usr/sbin/nologin messagebus || true

# Create XRDP log directories and ensure proper permissions
RUN mkdir -p /var/log/xrdp /var/run/xrdp && \
    chmod 755 /var/log/xrdp /var/run/xrdp && \
    chmod 755 /usr/local/bin/start-xrdp.sh && \
    chmod 755 /etc/xrdp/startwm.sh && \
    chmod 755 /tmp/.xsession-template

# Fix /dev/tty0 permissions issue - ensure it's accessible or create workaround
RUN chmod 666 /dev/tty0 2>/dev/null || true

EXPOSE 3389
WORKDIR /home/${USER_NAME}
CMD ["/usr/local/bin/start-xrdp.sh"]

# Multi-stage Dockerfile for Agentic Coding Pipeline Container
# Based on Ubuntu 24.04 LTS with comprehensive development environment

# =============================================================================
# Stage 1: Base System Setup
# =============================================================================
FROM ubuntu:24.04 AS base

# Set timezone FIRST (before any apt-get operations)
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Detroit
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create non-root user for development
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# System initialization: timezone, user creation, essential packages
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update \
    && apt-get install -y sudo \
    && echo ubuntu ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu \
    && echo 'ubuntu:ubuntu' | chpasswd \
    && apt-get install -y \
    # Essential system tools
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    jq \
    # Build tools
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    # Development tools
    openssh-client \
    rsync \
    # Network tools
    net-tools \
    iputils-ping \
    telnet \
    netcat-openbsd \
    # Process management
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Desktop Environment Setup - IceWM Desktop with NoVNC
# =============================================================================

# Install desktop environment: IceWM, VNC, xRDP, browsers
RUN add-apt-repository -y ppa:mozillateam/ppa \
    && echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' | tee /etc/apt/preferences.d/mozilla-firefox \
    && echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox \
    && apt-get update && apt-get install -y \
    # Window manager and desktop components
    icewm \
    icewm-common \
    xterm \
    gnome-terminal \
    nautilus \
    # Display server
    xorg \
    dbus-x11 \
    x11-xserver-utils \
    x11-utils \
    # VNC server
    tigervnc-standalone-server \
    tigervnc-common \
    # NoVNC and dependencies
    python3-numpy \
    novnc \
    websockify \
    # RDP server (xrdp)
    xrdp \
    xorgxrdp \
    # Fonts and rendering
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    # Audio support
    pulseaudio \
    # Web browser
    firefox \
    # Additional utilities
    xdotool \
    wmctrl \
    menu \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb \
    && apt-get install -y /tmp/google-chrome.deb \
    && rm /tmp/google-chrome.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure VNC, xRDP, and create all control scripts
RUN mkdir -p /home/ubuntu/.vnc /var/log/supervisor /etc/supervisor/conf.d \
    && echo "ubuntu" | vncpasswd -f > /home/ubuntu/.vnc/passwd \
    && chmod 600 /home/ubuntu/.vnc/passwd \
    && chown -R ubuntu:ubuntu /home/ubuntu/.vnc \
    && chmod 755 /var/log/supervisor \
    && usermod -a -G root ubuntu \
    && adduser ubuntu ssl-cert \
    && mkdir -p /var/run/xrdp \
    && chown xrdp:xrdp /var/run/xrdp \
    && chmod 755 /var/run/xrdp \
    && sed -i 's/^port=.*/port=3389/' /etc/xrdp/xrdp.ini \
    && sed -i '/^\[Xorg\]/,/^\[/{s/port=3389/port=-1/}' /etc/xrdp/xrdp.ini \
    && sed -i '/^\[Xvnc\]/,/^\[vnc-any\]/{/^\[vnc-any\]/!d;}' /etc/xrdp/xrdp.ini \
    && sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini \
    && sed -i 's/^MaxSessions=.*/MaxSessions=10/' /etc/xrdp/sesman.ini \
    && (sed -i 's/^EnableUserWindowManager=.*/EnableUserWindowManager=true/' /etc/xrdp/sesman.ini || \
     echo "EnableUserWindowManager=true" >> /etc/xrdp/sesman.ini)

# Create all configuration files and scripts in a single layer
RUN cat > /home/ubuntu/.vnc/xstartup << 'EOF' && chmod +x /home/ubuntu/.vnc/xstartup && chown ubuntu:ubuntu /home/ubuntu/.vnc/xstartup \
    && cat > /home/ubuntu/.vnc/config << 'EOFCONFIG' && chown ubuntu:ubuntu /home/ubuntu/.vnc/config \
    && cat > /home/ubuntu/.xsession << 'EOFXSESSION' && chmod +x /home/ubuntu/.xsession && chown ubuntu:ubuntu /home/ubuntu/.xsession \
    && cat > /etc/xrdp/startwm.sh << 'EOFSTARTWM' && chmod +x /etc/xrdp/startwm.sh \
    && cat > /etc/xrdp/xorg.conf << 'EOFXORG' \
    && cat > /usr/local/bin/start-vnc.sh << 'EOFSTARTVNC' && chmod +x /usr/local/bin/start-vnc.sh \
    && cat > /usr/local/bin/stop-vnc.sh << 'EOFSTOPVNC' && chmod +x /usr/local/bin/stop-vnc.sh \
    && cat > /usr/local/bin/vnc-ctl << 'EOFVNCCTL' && chmod +x /usr/local/bin/vnc-ctl \
    && cat > /usr/local/bin/desktop-status.sh << 'EOFDESKTOP' && chmod +x /usr/local/bin/desktop-status.sh \
    && cat > /usr/local/bin/start-firefox << 'EOFFIREFOX' && chmod +x /usr/local/bin/start-firefox \
    && cat > /usr/local/bin/start-chrome << 'EOFCHROME' && chmod +x /usr/local/bin/start-chrome \
    && cat > /usr/local/bin/xrdp-ctl << 'EOFXRDPCTL' && chmod +x /usr/local/bin/xrdp-ctl \
    && cat > /usr/local/bin/vncserver-supervisor.sh << 'EOFVNCSUPER' && chmod +x /usr/local/bin/vncserver-supervisor.sh \
    && cat > /etc/supervisor/supervisord.conf << 'EOFSUPERVISORD' \
    && cat > /etc/supervisor/conf.d/vncserver.conf << 'EOFCONFVNC' \
    && cat > /etc/supervisor/conf.d/novnc.conf << 'EOFCONFNOVNC' \
    && cat > /etc/supervisor/conf.d/xrdp.conf << 'EOFCONFXRDP'
#!/bin/bash
# Lightweight VNC session with IceWM (container-friendly, no systemd required)

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start dbus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Set background color
xsetroot -solid darkblue &

# Start file manager (optional, in background)
nautilus --no-desktop &

# Start terminal
gnome-terminal &

# Start IceWM window manager (lightweight and container-friendly)
exec icewm-session
EOF
geometry=1920x1080
dpi=96
depth=24
localhost=no
alwaysshared
EOFCONFIG
#!/bin/bash
# xRDP session startup script for IceWM

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start dbus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Set background color
xsetroot -solid darkblue &

# Start file manager (optional, in background)
nautilus --no-desktop &

# Start terminal
gnome-terminal &

# Start IceWM window manager
exec icewm-session
EOFXSESSION
#!/bin/bash
# xrdp startwm script

# Log for debugging
exec > $HOME/.xsession-errors 2>&1

if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

echo "Starting xRDP session at $(date)"
echo "USER: $USER"
echo "HOME: $HOME"
echo "DISPLAY: $DISPLAY"

# Test if X server is available
if ! xdpyinfo >/dev/null 2>&1; then
    echo "ERROR: X server not available on DISPLAY $DISPLAY"
    sleep 5
fi

# Execute user's .xsession if it exists
if [ -f $HOME/.xsession ]; then
    echo "Executing $HOME/.xsession"
    exec $HOME/.xsession
else
    # Fallback to IceWM
    echo "No .xsession found, starting icewm-session"
    exec icewm-session
fi
EOFSTARTWM
Section "ServerLayout"
    Identifier     "X.org Configured"
    Screen      0  "Screen0" 0 0
    InputDevice    "Mouse0" "CorePointer"
    InputDevice    "Keyboard0" "CoreKeyboard"
EndSection

Section "Files"
    ModulePath   "/usr/lib/xorg/modules"
    FontPath     "/usr/share/fonts/X11/misc"
    FontPath     "/usr/share/fonts/X11/cyrillic"
    FontPath     "/usr/share/fonts/X11/100dpi/:unscaled"
    FontPath     "/usr/share/fonts/X11/75dpi/:unscaled"
    FontPath     "/usr/share/fonts/X11/Type1"
    FontPath     "/usr/share/fonts/X11/100dpi"
    FontPath     "/usr/share/fonts/X11/75dpi"
    FontPath     "built-ins"
EndSection

Section "Module"
    Load  "dbe"
    Load  "ddc"
    Load  "extmod"
    Load  "glx"
    Load  "int10"
    Load  "record"
    Load  "vbe"
    Load  "xorgxrdp"
    Load  "fb"
EndSection

Section "InputDevice"
    Identifier  "Keyboard0"
    Driver      "kbd"
EndSection

Section "InputDevice"
    Identifier  "Mouse0"
    Driver      "mouse"
    Option      "Protocol" "auto"
    Option      "Device" "/dev/input/mice"
    Option      "ZAxisMapping" "4 5 6 7"
EndSection

Section "Monitor"
    Identifier   "Monitor0"
    VendorName   "Monitor Vendor"
    ModelName    "Monitor Model"
EndSection

Section "Device"
    Identifier  "Card0"
    Driver      "xorgxrdp"
    Option      "DRMDevice" ""
    Option      "DRI3" "false"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device     "Card0"
    Monitor    "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Viewport   0 0
        Depth     24
        Modes "1920x1080" "1680x1050" "1600x900" "1440x900" "1366x768" "1280x1024" "1280x800" "1024x768"
    EndSubSection
EndSection
EOFXORG
#!/bin/bash
# Start VNC desktop services via Supervisor

echo "Starting VNC desktop services via Supervisor..."

# Check if supervisor is running
if ! pgrep -x supervisord > /dev/null; then
    echo "Starting Supervisor..."
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
    sleep 2
fi

# Start VNC and NoVNC services
echo "Starting VNC server..."
supervisorctl start vncserver

echo "Starting NoVNC web interface..."
supervisorctl start novnc

# Wait for services to start
sleep 2

# Check status
echo ""
supervisorctl status vncserver novnc

echo ""
echo "Desktop services started!"
echo "VNC server: Port 5901"
echo "NoVNC web interface: http://localhost:6080/vnc.html"
echo "VNC password: ubuntu"
echo ""
echo "To check status: desktop-status.sh"
echo "To manage services: supervisorctl status|start|stop|restart <service>"
EOFSTARTVNC
#!/bin/bash
# Stop VNC desktop services via Supervisor

echo "Stopping VNC desktop services..."

# Stop NoVNC first
supervisorctl stop novnc 2>/dev/null || echo "NoVNC not running"

# Stop VNC server
supervisorctl stop vncserver 2>/dev/null || echo "VNC server not running"

# Check status
echo ""
supervisorctl status vncserver novnc

echo ""
echo "Desktop services stopped!"
echo "To restart: start-vnc.sh"
EOFSTOPVNC
#!/bin/bash
# VNC Service Control Helper

case "$1" in
    status)
        echo "=== VNC Desktop Services Status ==="
        supervisorctl status vncserver novnc
        echo ""
        desktop-status.sh
        ;;
    start)
        start-vnc.sh
        ;;
    stop)
        stop-vnc.sh
        ;;
    restart)
        echo "Restarting VNC desktop services..."
        supervisorctl restart vncserver novnc
        sleep 2
        supervisorctl status vncserver novnc
        ;;
    logs)
        service="${2:-vncserver}"
        if [ "$service" = "vncserver" ]; then
            echo "=== VNC Server Logs ==="
            tail -50 /var/log/supervisor/vncserver.log
        elif [ "$service" = "novnc" ]; then
            echo "=== NoVNC Logs ==="
            tail -50 /var/log/supervisor/novnc.log
        else
            echo "Unknown service: $service"
            echo "Valid services: vncserver, novnc"
            exit 1
        fi
        ;;
    *)
        echo "VNC Service Control"
        echo "Usage: vnc-ctl {status|start|stop|restart|logs [vncserver|novnc]}"
        echo ""
        echo "Examples:"
        echo "  vnc-ctl status          - Show service status"
        echo "  vnc-ctl start           - Start VNC services"
        echo "  vnc-ctl stop            - Stop VNC services"
        echo "  vnc-ctl restart         - Restart VNC services"
        echo "  vnc-ctl logs vncserver  - Show VNC server logs"
        echo "  vnc-ctl logs novnc      - Show NoVNC logs"
        exit 1
        ;;
esac
EOFVNCCTL
#!/bin/bash

echo "=== Desktop Environment Status ==="
echo ""

# Check VNC server (looks for both Xtigervnc and Xvnc)
if pgrep -x "Xtigervnc" > /dev/null || pgrep -x "Xvnc" > /dev/null; then
    echo "✓ VNC Server: Running"
    echo "  Display: :1 (port 5901)"
else
    echo "✗ VNC Server: Not running"
fi

# Check NoVNC
if pgrep -f "websockify.*6080" > /dev/null; then
    echo "✓ NoVNC Web Interface: Running"
    echo "  URL: http://localhost:6080/vnc.html"
else
    echo "✗ NoVNC Web Interface: Not running"
fi

# Check xRDP
if pgrep -x "xrdp" > /dev/null; then
    echo "✓ xRDP Server: Running"
    echo "  Port: 3389"
else
    echo "✗ xRDP Server: Not running"
fi

# Check xRDP Session Manager
if pgrep -x "xrdp-sesman" > /dev/null; then
    echo "✓ xRDP Session Manager: Running"
else
    echo "✗ xRDP Session Manager: Not running"
fi

# Check IceWM
if pgrep -x "icewm" > /dev/null || pgrep -x "icewm-session" > /dev/null; then
    echo "✓ IceWM Window Manager: Running"
else
    echo "✗ IceWM Window Manager: Not running"
fi

echo ""
echo "To start desktop environment: start-vnc.sh"
echo "To stop VNC: vncserver -kill :1"
echo "To manage xRDP: xrdp-ctl {status|start|stop|restart}"
EOFDESKTOP
#!/bin/bash
# Launch Firefox browser
export DISPLAY=:1
firefox "$@" &
EOFFIREFOX
#!/bin/bash
# Launch Google Chrome browser
export DISPLAY=:1
# Run Chrome with --no-sandbox flag for container compatibility
google-chrome --no-sandbox "$@" &
EOFCHROME
#!/bin/bash
# xRDP Service Control Helper

case "$1" in
    status)
        echo "=== xRDP Services Status ==="
        supervisorctl status xrdp-sesman xrdp
        echo ""
        echo "=== xRDP Process Status ==="
        if pgrep -x "xrdp-sesman" > /dev/null; then
            echo "✓ xRDP Session Manager: Running"
        else
            echo "✗ xRDP Session Manager: Not running"
        fi
        if pgrep -x "xrdp" > /dev/null; then
            echo "✓ xRDP Server: Running on port 3389"
        else
            echo "✗ xRDP Server: Not running"
        fi
        ;;
    start)
        echo "Starting xRDP services..."
        supervisorctl start xrdp-sesman xrdp
        sleep 2
        supervisorctl status xrdp-sesman xrdp
        ;;
    stop)
        echo "Stopping xRDP services..."
        supervisorctl stop xrdp xrdp-sesman
        sleep 1
        supervisorctl status xrdp-sesman xrdp
        ;;
    restart)
        echo "Restarting xRDP services..."
        supervisorctl restart xrdp-sesman xrdp
        sleep 2
        supervisorctl status xrdp-sesman xrdp
        ;;
    logs)
        service="${2:-xrdp}"
        if [ "$service" = "xrdp" ]; then
            echo "=== xRDP Server Logs ==="
            tail -50 /var/log/supervisor/xrdp.log
        elif [ "$service" = "sesman" ]; then
            echo "=== xRDP Session Manager Logs ==="
            tail -50 /var/log/supervisor/xrdp-sesman.log
        else
            echo "Unknown service: $service"
            echo "Valid services: xrdp, sesman"
            exit 1
        fi
        ;;
    *)
        echo "xRDP Service Control"
        echo "Usage: xrdp-ctl {status|start|stop|restart|logs [xrdp|sesman]}"
        echo ""
        echo "Examples:"
        echo "  xrdp-ctl status        - Show service status"
        echo "  xrdp-ctl start         - Start xRDP services"
        echo "  xrdp-ctl stop          - Stop xRDP services"
        echo "  xrdp-ctl restart       - Restart xRDP services"
        echo "  xrdp-ctl logs xrdp     - Show xRDP server logs"
        echo "  xrdp-ctl logs sesman   - Show xRDP session manager logs"
        exit 1
        ;;
esac
EOFXRDPCTL
#!/bin/bash
# VNC Server startup script for Supervisor
set -e

# Clean up any stale VNC locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Kill any existing VNC servers
vncserver -kill :1 2>/dev/null || true
sleep 1

# Export environment variables
export USER=ubuntu
export HOME=/home/ubuntu
export DISPLAY=:1

# Start Xvnc in background
/usr/bin/Xvnc :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -dpi 96 \
    -rfbport 5901 \
    -SecurityTypes VncAuth,TLSVnc \
    -PasswordFile /home/ubuntu/.vnc/passwd \
    -desktop "Agentic Coding Desktop" \
    -localhost no \
    -AlwaysShared \
    -NeverShared=0 &

XVNC_PID=$!

# Wait for X server to be ready
sleep 2

# Execute xstartup script to start the desktop environment
DISPLAY=:1 /home/ubuntu/.vnc/xstartup &

# Wait for Xvnc process (this keeps supervisor happy)
wait $XVNC_PID
EOFVNCSUPER
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
loglevel=info

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0770

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[include]
files = /etc/supervisor/conf.d/*.conf
EOFSUPERVISORD
[program:vncserver]
command=/usr/local/bin/vncserver-supervisor.sh
user=ubuntu
autostart=true
autorestart=true
startsecs=5
startretries=3
stdout_logfile=/var/log/supervisor/vncserver.log
stderr_logfile=/var/log/supervisor/vncserver.err
priority=10
EOFCONFVNC
[program:novnc]
command=/usr/bin/websockify --web=/usr/share/novnc 6080 localhost:5901
user=ubuntu
autostart=true
autorestart=true
startsecs=5
startretries=3
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc.err
priority=20
depends_on=vncserver
EOFCONFNOVNC
[program:xrdp-sesman]
command=/usr/sbin/xrdp-sesman --nodaemon
user=root
autostart=true
autorestart=true
startsecs=5
startretries=3
stdout_logfile=/var/log/supervisor/xrdp-sesman.log
stderr_logfile=/var/log/supervisor/xrdp-sesman.err
priority=15

[program:xrdp]
command=/usr/sbin/xrdp --nodaemon
user=root
autostart=true
autorestart=true
startsecs=5
startretries=3
stdout_logfile=/var/log/supervisor/xrdp.log
stderr_logfile=/var/log/supervisor/xrdp.err
priority=16
depends_on=xrdp-sesman
EOFCONFXRDP

# =============================================================================
# Stage 2: Runtime Environments
# =============================================================================
FROM base AS runtime

# Install all runtime environments: Node.js, Python, Docker, zsh, and configure Git
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    zsh \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && usermod -aG docker $USERNAME 2>/dev/null || true \
    && usermod -s /usr/bin/zsh ubuntu \
    && git config --global init.defaultBranch main \
    && git config --global user.name "Developer" \
    && git config --global user.email "developer@localhost" \
    && git config --global core.editor "vim" \
    && git config --global pull.rebase false \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install and configure Kiro (CLI + IDE with wrapper scripts)
RUN sudo -u ubuntu bash -c 'curl -fsSL https://cli.kiro.dev/install | bash' \
    && apt-get install -f \
    && cat > /usr/local/bin/kiro-safe << 'EOFKIROSAFE' && chmod +x /usr/local/bin/kiro-safe \
    && KIRO_METADATA_URL="https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-deb-stable.json" \
    && echo "Fetching Kiro IDE metadata..." \
    && METADATA=$(curl -fsSL "$KIRO_METADATA_URL") \
    && echo "Metadata received, parsing download URL..." \
    && KIRO_DEB_URL=$(echo "$METADATA" | jq -r '.releases[].updateTo.url | select(endswith(".deb"))' | head -n1) \
    && if [ -z "$KIRO_DEB_URL" ] || [ "$KIRO_DEB_URL" = "null" ]; then \
        echo "ERROR: Could not parse download URL from metadata. Metadata contents:"; \
        echo "$METADATA" | jq '.' || echo "$METADATA"; \
        exit 1; \
    fi \
    && echo "Downloading Kiro IDE from: $KIRO_DEB_URL" \
    && curl -fsSL "$KIRO_DEB_URL" -o /tmp/kiro-ide.deb \
    && echo "Installing Kiro IDE..." \
    && apt-get update \
    && apt-get install -y /tmp/kiro-ide.deb \
    && rm /tmp/kiro-ide.deb \
    && if [ -f "/opt/Kiro/kiro" ]; then \
        KIRO_BIN="/opt/Kiro/kiro"; \
    elif [ -f "/usr/bin/kiro" ]; then \
        KIRO_BIN="/usr/bin/kiro"; \
    elif [ -f "/usr/local/bin/kiro" ]; then \
        KIRO_BIN="/usr/local/bin/kiro"; \
    else \
        echo "ERROR: Could not find Kiro IDE binary"; \
        exit 1; \
    fi \
    && echo "Found Kiro IDE at: $KIRO_BIN" \
    && mv "$KIRO_BIN" "${KIRO_BIN}.bin" \
    && printf '%s\n' '#!/bin/bash' \
        '# Kiro IDE wrapper for container compatibility' \
        '# Automatically adds flags to disable sandboxing and reads config from environment variables' \
        '' \
        '# Set DISPLAY if not already set' \
        'export DISPLAY=${DISPLAY:-:1}' \
        '' \
        '# Find the real Kiro binary' \
        'SCRIPT_DIR=$(dirname "$(readlink -f "$0")")' \
        'KIRO_REAL="${SCRIPT_DIR}/$(basename "$0").bin"' \
        '' \
        'if [ ! -f "$KIRO_REAL" ]; then' \
        '    echo "Error: Kiro IDE binary not found at $KIRO_REAL"' \
        '    exit 1' \
        'fi' \
        '' \
        '# Build arguments array with container-safe flags' \
        'KIRO_ARGS=(' \
        '    --no-sandbox' \
        '    --disable-dev-shm-usage' \
        '    --disable-gpu' \
        ')' \
        '' \
        '# Add start URL if provided via environment variable' \
        'if [ -n "$KIRO_START_URL" ]; then' \
        '    echo "Using start URL from KIRO_START_URL: $KIRO_START_URL"' \
        '    KIRO_ARGS+=(--url "$KIRO_START_URL")' \
        'fi' \
        '' \
        '# Add AWS region if provided via environment variable' \
        'if [ -n "$KIRO_AWS_REGION" ]; then' \
        '    echo "Using AWS region from KIRO_AWS_REGION: $KIRO_AWS_REGION"' \
        '    export AWS_REGION="$KIRO_AWS_REGION"' \
        '    export AWS_DEFAULT_REGION="$KIRO_AWS_REGION"' \
        '    KIRO_ARGS+=(--region "$KIRO_AWS_REGION")' \
        'fi' \
        '' \
        '# Also support AWS_REGION if KIRO_AWS_REGION is not set' \
        'if [ -z "$KIRO_AWS_REGION" ] && [ -n "$AWS_REGION" ]; then' \
        '    echo "Using AWS region from AWS_REGION: $AWS_REGION"' \
        '    export AWS_DEFAULT_REGION="$AWS_REGION"' \
        '    KIRO_ARGS+=(--region "$AWS_REGION")' \
        'fi' \
        '' \
        '# Launch with all flags and user arguments' \
        'exec "$KIRO_REAL" "${KIRO_ARGS[@]}" "$@"' \
        > "$KIRO_BIN" \
    && chmod +x "$KIRO_BIN" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
#!/bin/bash
# Kiro CLI launcher with container-safe flags
# Disables sandboxing which is incompatible with Docker containers

# Check if kiro is in user's local bin first, otherwise use system install
if [ -f "$HOME/.local/bin/kiro" ]; then
    KIRO_PATH="$HOME/.local/bin/kiro"
elif [ -f "/usr/bin/kiro" ]; then
    KIRO_PATH="/usr/bin/kiro"
else
    echo "Error: kiro not found in \$HOME/.local/bin or /usr/bin"
    exit 1
fi

exec "$KIRO_PATH" \
    --no-sandbox \
    --disable-dev-shm-usage \
    "$@"
EOFKIROSAFE

# Configure shell: install oh-my-zsh, setup PATH, set default browser
RUN sudo -u ubuntu sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/ubuntu/.zshrc \
    && chown ubuntu:ubuntu /home/ubuntu/.zshrc \
    && sudo -u ubuntu xdg-settings set default-web-browser firefox.desktop

# =============================================================================
# Stage 3: Base Container Image Integration
# =============================================================================
FROM runtime AS base_integration

# Switch to root for system-level installations
USER root

# Clone and integrate Base Container Image components
RUN git clone https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup.git /tmp/base_setup || \
    echo "Base container repository not accessible, using fallback configuration"

# Install additional tools commonly found in agentic coding environments
# Note: curl, wget, jq, htop, netcat-openbsd already installed in base stage
# Note: zsh already installed in runtime stage
RUN apt-get update && apt-get install -y \
    # Terminal and shell enhancements \
    tmux \
    screen \
    # File management \
    ranger \
    mc \
    # Network and API tools \
    httpie \
    # Text processing \
    xmlstarlet \
    # Monitoring and system tools \
    sysstat \
    # Development utilities \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Database clients \
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install optional tools (fish, fzf, database clients) in one layer
RUN apt-get update && \
    (apt-get install -y fish || echo "Fish shell installation failed, continuing...") && \
    (apt-get install -y fzf || echo "fzf installation failed, continuing...") && \
    (apt-get install -y postgresql-client mysql-client redis-tools || echo "Some database clients failed to install, continuing...") && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install additional Python packages for agentic coding (skip for now, will be done in development_enhanced stage)
# RUN /home/$USERNAME/.venv/bin/pip install \
#     # AI and ML libraries \
#     langchain \
#     langchain-community \
#     langchain-openai \
#     langchain-anthropic \
#     chromadb \
#     faiss-cpu \
#     sentence-transformers \
#     # API and web frameworks \
#     flask \
#     django \
#     starlette \
#     # Data processing \
#     sqlalchemy \
#     alembic \
#     redis \
#     celery \
#     # Development tools \
#     pre-commit \
#     bandit \
#     safety \
#     # Documentation \
#     mkdocs \
#     sphinx

# Install additional Node.js packages for agentic development
RUN npm install -g \
    # API development \
    @nestjs/cli \
    fastify-cli \
    # Testing and quality \
    mocha \
    chai \
    nyc \
    # Build tools \
    rollup \
    vite \
    # Utilities \
    concurrently \
    cross-env \
    dotenv-cli

# Create directories for pipeline projects and tools
RUN mkdir -p /opt/pipelines \
    && mkdir -p /opt/tools \
    && mkdir -p /opt/configs

# Clone all pipeline and tool repositories in a single layer
# Note: Configuration files have been moved to runtime initialization scripts
RUN set -e && \
    # Clone pipeline projects \
    cd /opt/pipelines && \
    (git clone https://github.com/AndyMik90/Auto-Claude.git auto-claude || mkdir -p auto-claude) && \
    (git clone https://github.com/parcadei/Continuous-Claude-v2.git continuous-claude || mkdir -p continuous-claude) && \
    (git clone https://github.com/AutoMaker-Org/automaker.git automaker || mkdir -p automaker) && \
    (git clone https://github.com/ChenglinPoly/infiAgent.git infiagent || mkdir -p infiagent) && \
    (git clone https://github.com/Tongyi-MAI/MAI-UI.git mai-ui || mkdir -p mai-ui) && \
    (git clone https://github.com/asklokesh/claudeskill-loki-mode.git loki-mode || mkdir -p loki-mode) && \
    # Clone tool repositories \
    cd /opt/tools && \
    (git clone https://github.com/MrSibe/KnowNote.git knownote || mkdir -p knownote) && \
    (git clone https://github.com/VibiumDev/vibium.git vibium || mkdir -p vibium) && \
    (git clone https://github.com/open-tinker/OpenTinker.git opentinker || mkdir -p opentinker) && \
    (git clone https://github.com/heyhuynhgiabuu/proxypal.git proxypal || mkdir -p proxypal) && \
    (git clone https://github.com/simonw/claude-code-transcripts.git claude-transcripts || mkdir -p claude-transcripts) && \
    # Create basic startup scripts for all projects \
    for dir in /opt/pipelines/* /opt/tools/*; do \
        if [ -d "$dir" ]; then \
            name=$(basename "$dir"); \
            echo '#!/bin/bash' > "$dir/start-$name.sh"; \
            echo "echo 'Starting $name...'" >> "$dir/start-$name.sh"; \
            chmod +x "$dir/start-$name.sh"; \
        fi; \
    done


# Set proper ownership and permissions for all directories
RUN chmod -R 755 /opt/pipelines /opt/tools /opt/configs && \
    chmod -R 775 /workspace && \
    find /opt -name "*.sh" -exec chmod +x {} \; && \
    # Clean up package caches and temporary files to reduce image size \
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    # Clean up npm cache \
    npm cache clean --force && \
    # Note: pip cache purge will be done in development_enhanced stage after venv is created \
    # Remove git repositories .git directories to save space (keep source code) \
    find /opt/pipelines -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/tools -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# =============================================================================
# Stage 4: Development Tools and Directories
# =============================================================================
FROM base_integration AS development_enhanced

# Re-declare ARG variables for this stage
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create directories for pipeline projects
RUN mkdir -p /opt/pipelines \
    && mkdir -p /opt/tools \
    && mkdir -p /opt/configs \
    && mkdir -p /workspace

# Ensure proper ownership and create Python virtual environment
USER root
RUN chown -R ubuntu:ubuntu /workspace /home/ubuntu 2>/dev/null || true

# Create Python virtual environment for global tools as root, then change ownership
WORKDIR /home/ubuntu
RUN python -m venv /home/ubuntu/.venv \
    && echo "source /home/ubuntu/.venv/bin/activate" >> /home/ubuntu/.bashrc \
    && chown -R ubuntu:ubuntu /home/ubuntu/.venv /home/ubuntu/.bashrc 2>/dev/null || true

# Install common Python packages as root, then change ownership
RUN /home/ubuntu/.venv/bin/pip install --upgrade pip setuptools wheel \
    && /home/ubuntu/.venv/bin/pip install \
    requests \
    pyyaml \
    click \
    rich \
    typer \
    httpx \
    aiohttp \
    fastapi \
    uvicorn \
    pytest \
    pytest-asyncio \
    black \
    flake8 \
    mypy \
    jupyter \
    notebook \
    ipython \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch \
    transformers \
    openai \
    anthropic \
    && chown -R ubuntu:ubuntu /home/ubuntu/.venv 2>/dev/null || true

# Install all Python dependencies for pipeline projects and tools in one layer to reduce build depth
RUN /home/ubuntu/.venv/bin/pip install \
    langchain \
    langchain-anthropic \
    langchain-openai \
    langchain-google-genai \
    pydantic \
    asyncio \
    aiofiles \
    jinja2 \
    gitpython \
    google-generativeai \
    docker \
    kubernetes \
    celery \
    redis \
    sqlalchemy \
    alembic \
    psutil \
    memory-profiler \
    configparser \
    jsonschema \
    torchvision \
    accelerate \
    bitsandbytes \
    peft \
    datasets \
    pillow \
    opencv-python \
    gradio \
    streamlit \
    huggingface-hub \
    safetensors \
    chromadb \
    sentence-transformers \
    tf-keras \
    pypdf \
    python-docx \
    markdown \
    beautifulsoup4 \
    gymnasium \
    stable-baselines3 \
    'ray[rllib]' \
    tensorboard \
    wandb \
    mlflow \
    optuna \
    && /home/ubuntu/.venv/bin/pip cache purge

# Install common Node.js packages globally
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    pm2 \
    @types/node \
    eslint \
    prettier \
    jest \
    webpack \
    webpack-cli \
    create-react-app \
    @angular/cli \
    vue-cli \
    express-generator

# =============================================================================
# Stage 5: Final Configuration
# =============================================================================
FROM development_enhanced AS final

# Set working directory to ubuntu user's home
WORKDIR /home/ubuntu

# Expose common development ports
EXPOSE 3000 8000 8080 9000
# Expose VNC and NoVNC ports
EXPOSE 5901 6080
# Expose xRDP port
EXPOSE 3389

# Ensure proper ownership in final stage
USER root

# Create startup script with executable permissions (using --chmod to avoid additional RUN layer)
COPY --chmod=755 scripts/base-container-setup.sh /usr/local/bin/base-container-setup.sh

# Fix: Create symlinks for agentic commands in system path
# Commented out due to Docker overlay filesystem depth limit - run manually at container startup if needed
# RUN if [ -f /home/ubuntu/.local/bin/agentic-status ]; then \
#         ln -s /home/ubuntu/.local/bin/agentic-status /usr/local/bin/agentic-status && \
#         ln -s /home/ubuntu/.local/bin/init-project /usr/local/bin/init-project && \
#         chmod +x /usr/local/bin/agentic-status && \
#         chmod +x /usr/local/bin/init-project; \
#     fi

# Fix: Ensure all startup scripts exit cleanly and handle missing venv
# Commented out due to Docker overlay filesystem depth limit - run manually at container startup if needed
# RUN for script in /opt/pipelines/*/start-*.sh /opt/tools/*/start-*.sh; do \
#         if [ -f "$script" ]; then \
#             # Make venv activation conditional \
#             sed -i 's|^source /home/ubuntu/.venv/bin/activate|if [ -f /home/ubuntu/.venv/bin/activate ]; then source /home/ubuntu/.venv/bin/activate; else echo "Warning: venv not found, using system Python"; fi|g' "$script" && \
#             # Ensure script exits 0 \
#             if ! grep -q "^exit 0" "$script"; then \
#                 echo "" >> "$script" && \
#                 echo "exit 0" >> "$script"; \
#             fi \
#         fi \
#     done

# Ensure Git is configured for ubuntu user
# Commented out due to Docker overlay filesystem depth limit - run manually at container startup if needed
# RUN sudo -u ubuntu git config --global init.defaultBranch main && \
#     sudo -u ubuntu git config --global user.name "Agentic ubuntu" && \
#     sudo -u ubuntu git config --global user.email "ubuntu@agentic-coding.local" && \
#     sudo -u ubuntu git config --global core.editor "vim" && \
#     sudo -u ubuntu git config --global pull.rebase false && \
#     chown ubuntu:ubuntu /home/ubuntu/.gitconfig 2>/dev/null || true

# Note: Due to Docker overlay filesystem depth limits, this Dockerfile cannot add any more layers
# Container is functional but some configuration must be done at runtime
# Use: docker run -it agentic-coding-pipeline:latest /bin/bash

# Metadata only - does not create layers
LABEL maintainer="Agentic Coding Pipeline" \
      description="Comprehensive Docker container with multi-agent coding pipeline projects" \
      version="1.0.0" \
      org.opencontainers.image.source="https://github.com/ai_coding_pipeline"

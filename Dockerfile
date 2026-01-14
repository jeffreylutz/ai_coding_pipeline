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

# Configure timezone non-interactively
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create non-root user for development
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create user first (before package installations)
RUN apt-get update \
     && apt-get install -y sudo \
     && echo ubuntu ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/ubuntu \
     && chmod 0440 /etc/sudoers.d/ubuntu
    
# RUN groupadd --gid 1000 ubuntu 2>/dev/null || groupmod -g 1000 ubuntu 2>/dev/null || true \
#     && useradd --uid 1000 --gid 1000 -m ubuntu 2>/dev/null || usermod -u 1000 -g 1000 ubuntu 2>/dev/null || true \
#     && echo ubuntu ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/ubuntu \
#     && chmod 0440 /etc/sudoers.d/ubuntu

# Update system and install all essential packages in one layer
RUN apt-get update && apt-get install -y \
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
    sudo \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Desktop Environment Setup - IceWM Desktop with NoVNC
# =============================================================================

# Install IceWM Desktop, NoVNC, and all dependencies in one layer
# Using IceWM instead of GNOME for container compatibility (no systemd required)
RUN apt-get update && apt-get install -y \
    # Window manager and desktop components \
    icewm \
    icewm-common \
    xterm \
    gnome-terminal \
    nautilus \
    # Display server \
    xorg \
    dbus-x11 \
    x11-xserver-utils \
    x11-utils \
    # VNC server \
    tigervnc-standalone-server \
    tigervnc-common \
    # NoVNC and dependencies \
    python3-numpy \
    novnc \
    websockify \
    # Fonts and rendering \
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    # Audio support \
    pulseaudio \
    # Additional utilities \
    xdotool \
    wmctrl \
    menu \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure VNC for ubuntu user
RUN mkdir -p /home/ubuntu/.vnc && \
    echo "ubuntu" | vncpasswd -f > /home/ubuntu/.vnc/passwd && \
    chmod 600 /home/ubuntu/.vnc/passwd && \
    chown -R ubuntu:ubuntu /home/ubuntu/.vnc

# Create VNC xstartup script for IceWM
RUN cat > /home/ubuntu/.vnc/xstartup << 'EOF'
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

RUN chmod +x /home/ubuntu/.vnc/xstartup && \
    chown ubuntu:ubuntu /home/ubuntu/.vnc/xstartup

# Create VNC configuration file
RUN cat > /home/ubuntu/.vnc/config << 'EOF'
# VNC Configuration
geometry=1920x1080
dpi=96
depth=24
localhost=no
alwaysshared
EOF

RUN chown ubuntu:ubuntu /home/ubuntu/.vnc/config

# Create startup script for VNC and NoVNC (now uses Supervisor)
RUN cat > /usr/local/bin/start-vnc.sh << 'EOF'
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
EOF

RUN chmod +x /usr/local/bin/start-vnc.sh

# Create stop script for VNC and NoVNC
RUN cat > /usr/local/bin/stop-vnc.sh << 'EOF'
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
EOF

RUN chmod +x /usr/local/bin/stop-vnc.sh

# Create supervisor management helper
RUN cat > /usr/local/bin/vnc-ctl << 'EOF'
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
EOF

RUN chmod +x /usr/local/bin/vnc-ctl

# Create desktop environment check script
RUN cat > /usr/local/bin/desktop-status.sh << 'EOF'
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

# Check IceWM
if pgrep -x "icewm" > /dev/null || pgrep -x "icewm-session" > /dev/null; then
    echo "✓ IceWM Window Manager: Running"
else
    echo "✗ IceWM Window Manager: Not running"
fi

echo ""
echo "To start desktop environment: start-vnc.sh"
echo "To stop VNC: vncserver -kill :1"
EOF

RUN chmod +x /usr/local/bin/desktop-status.sh

# Configure Supervisor to manage VNC and NoVNC services
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d

# Create supervisor configuration for VNC server
RUN cat > /etc/supervisor/conf.d/vncserver.conf << 'EOF'
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
EOF

# Create supervisor configuration for NoVNC
RUN cat > /etc/supervisor/conf.d/novnc.conf << 'EOF'
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
EOF

# Create VNC startup wrapper script for supervisor
RUN cat > /usr/local/bin/vncserver-supervisor.sh << 'EOF'
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
EOF

RUN chmod +x /usr/local/bin/vncserver-supervisor.sh

# Create main supervisor configuration
RUN cat > /etc/supervisor/supervisord.conf << 'EOF'
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
EOF

# Add ubuntu user to root group so they can access supervisor socket
RUN usermod -a -G root ubuntu

# =============================================================================
# Stage 2: Runtime Environments
# =============================================================================
FROM base AS runtime

# Install Node.js 18+ (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.12+ and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for python and pip
RUN ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Install Docker (for Docker-in-Docker support)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && usermod -aG docker $USERNAME 2>/dev/null || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure Git with default settings
RUN git config --global init.defaultBranch main \
    && git config --global user.name "Developer" \
    && git config --global user.email "developer@localhost" \
    && git config --global core.editor "vim" \
    && git config --global pull.rebase false

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
RUN apt-get update && apt-get install -y \
    # Terminal and shell enhancements \
    zsh \
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

# Install oh-my-zsh for enhanced shell experience
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true

# Configure shell enhancements for ubuntu user (skip for now to avoid user issues)
# This will be configured later in the development_enhanced stage

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

# Install Kiro CLI
RUN curl -fsSL https://cli.kiro.dev/install | bash \
    && apt-get install -f

# Create Kiro startup script
RUN mkdir -p /opt/pipelines/kiro
RUN cat > /opt/pipelines/kiro/start-kiro.sh << 'EOF'
#!/bin/bash
# Kiro Autonomous Agent Startup Script

echo "Starting Kiro Autonomous Agent..."
echo "Configuration: /opt/configs/kiro/config.json"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/kiro"

# Create logs directory
mkdir -p /opt/logs/kiro

# Note: Actual Kiro installation would go here
# This is a placeholder for the proprietary Kiro agent
echo "Kiro Autonomous Agent is configured and ready"
echo "To install the actual Kiro agent, visit: https://kiro.dev/autonomous-agent/"
echo "Current configuration supports:"
echo "- Sandbox environment with Dockerfile detection"
echo "- Autonomous operation with context maintenance"
echo "- Learning from interactions"
echo "- Containerized development workflows"
EOF

RUN chmod +x /opt/pipelines/kiro/start-kiro.sh

# Install Auto-Claude Framework
RUN cd /opt/pipelines && \
    git clone https://github.com/AndyMik90/Auto-Claude.git auto-claude || \
    (mkdir -p auto-claude && echo "Auto-Claude repository placeholder" > auto-claude/README.md)

# Note: Auto-Claude Python dependencies will be installed in development_enhanced stage

# Create Auto-Claude configuration
RUN mkdir -p /opt/configs/auto-claude && \
    cat > /opt/configs/auto-claude/config.yaml << 'EOF'
# Auto-Claude Framework Configuration
name: "auto-claude"
version: "1.0.0"
description: "Autonomous multi-agent coding framework"

# API Configuration
apis:
  anthropic:
    model: "claude-3-sonnet-20240229"
    max_tokens: 4096
    temperature: 0.1
  openai:
    model: "gpt-4"
    max_tokens: 4096
    temperature: 0.1

# Multi-Agent Configuration
agents:
  planner:
    role: "planning"
    model: "claude-3-sonnet-20240229"
    capabilities: ["analysis", "planning", "architecture"]
  builder:
    role: "implementation"
    model: "claude-3-sonnet-20240229"
    capabilities: ["coding", "testing", "debugging"]
  validator:
    role: "validation"
    model: "claude-3-sonnet-20240229"
    capabilities: ["testing", "review", "quality_assurance"]

# Workflow Configuration
workflow:
  enabled: true
  auto_planning: true
  auto_building: true
  auto_validation: true
  human_approval: false

# Environment
workspace: "/workspace"
logs: "/opt/logs/auto-claude"
temp: "/tmp/auto-claude"
EOF

# Create Auto-Claude startup script
RUN cat > /opt/pipelines/auto-claude/start-auto-claude.sh << 'EOF'
#!/bin/bash
# Auto-Claude Framework Startup Script

echo "Starting Auto-Claude Framework..."
echo "Configuration: /opt/configs/auto-claude/config.yaml"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/auto-claude"

# Create necessary directories
mkdir -p /opt/logs/auto-claude
mkdir -p /tmp/auto-claude

# Activate Python virtual environment
source /home/ubuntu/.venv/bin/activate

# Check API keys
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Warning: ANTHROPIC_API_KEY not set"
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: OPENAI_API_KEY not set"
fi

echo "Auto-Claude Framework is configured and ready"
echo "Available agents: planner, builder, validator"
echo "Workflow: planning -> building -> validation"
echo "To use Auto-Claude, set your API keys and run the framework"

# Note: Actual Auto-Claude execution would go here
# This is a placeholder for the Auto-Claude framework
EOF

RUN chmod +x /opt/pipelines/auto-claude/start-auto-claude.sh

# Install Continuous-Claude System
RUN cd /opt/pipelines && \
    git clone https://github.com/parcadei/Continuous-Claude-v2.git continuous-claude || \
    (mkdir -p continuous-claude && echo "Continuous-Claude repository placeholder" > continuous-claude/README.md)

# Install Continuous-Claude Node.js dependencies
RUN cd /opt/pipelines/continuous-claude && \
    npm init -y --name continuous-claude && \
    npm install \
    @anthropic-ai/sdk \
    axios \
    fs-extra \
    yaml \
    commander \
    chalk \
    inquirer \
    lodash \
    moment \
    uuid \
    ws \
    express

# Create Continuous-Claude configuration
RUN mkdir -p /opt/configs/continuous-claude && \
    cat > /opt/configs/continuous-claude/config.json << 'EOF'
{
  "name": "continuous-claude",
  "version": "2.0.0",
  "description": "Session continuity, token-efficient MCP execution, and agentic workflows",
  
  "session_management": {
    "continuity_enabled": true,
    "ledger_path": "/workspace/.claude-ledger",
    "handoff_path": "/workspace/.claude-handoffs",
    "auto_save_interval": 300,
    "max_context_length": 100000
  },
  
  "mcp_execution": {
    "enabled": true,
    "token_efficient": true,
    "context_pollution_prevention": true,
    "isolated_execution": true
  },
  
  "agentic_workflows": {
    "enabled": true,
    "agent_orchestration": true,
    "isolated_context_windows": true,
    "workflow_templates": "/opt/configs/continuous-claude/workflows"
  },
  
  "claude_integration": {
    "model": "claude-3-sonnet-20240229",
    "max_tokens": 4096,
    "temperature": 0.1,
    "api_endpoint": "https://api.anthropic.com"
  },
  
  "workspace": "/workspace",
  "logs": "/opt/logs/continuous-claude",
  "temp": "/tmp/continuous-claude"
}
EOF

# Create workflow templates directory
RUN mkdir -p /opt/configs/continuous-claude/workflows && \
    cat > /opt/configs/continuous-claude/workflows/default.yaml << 'EOF'
# Default Continuous-Claude Workflow Template
name: "default_workflow"
description: "Standard agentic workflow with session continuity"

steps:
  - name: "initialize_session"
    type: "session_management"
    action: "load_context"
    
  - name: "execute_task"
    type: "agent_execution"
    action: "process_request"
    
  - name: "save_state"
    type: "session_management"
    action: "update_ledger"
    
  - name: "cleanup"
    type: "maintenance"
    action: "clear_context"

session_continuity:
  enabled: true
  auto_handoff: true
  context_preservation: true
  
mcp_settings:
  token_efficiency: true
  isolated_execution: true
  context_pollution_prevention: true
EOF

# Create Continuous-Claude startup script
RUN cat > /opt/pipelines/continuous-claude/start-continuous-claude.sh << 'EOF'
#!/bin/bash
# Continuous-Claude System Startup Script

echo "Starting Continuous-Claude System..."
echo "Configuration: /opt/configs/continuous-claude/config.json"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/continuous-claude"

# Create necessary directories
mkdir -p /opt/logs/continuous-claude
mkdir -p /tmp/continuous-claude
mkdir -p /workspace/.claude-ledger
mkdir -p /workspace/.claude-handoffs

# Check Node.js availability
if ! command -v node &> /dev/null; then
    echo "Error: Node.js not found"
    exit 1
fi

# Check API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Warning: ANTHROPIC_API_KEY not set"
fi

echo "Continuous-Claude System is configured and ready"
echo "Features:"
echo "- Session continuity with ledger management"
echo "- Token-efficient MCP execution"
echo "- Agentic workflows with isolated context windows"
echo "- Context pollution prevention"
echo "- Automatic handoff generation"

# Note: Actual Continuous-Claude execution would go here
# This is a placeholder for the Continuous-Claude system
EOF

RUN chmod +x /opt/pipelines/continuous-claude/start-continuous-claude.sh

# Install Automaker Development Studio
RUN cd /opt/pipelines && \
    git clone https://github.com/AutoMaker-Org/automaker.git automaker || \
    (mkdir -p automaker && echo "Automaker repository placeholder" > automaker/README.md)

# Note: Automaker Python dependencies will be installed in development_enhanced stage

# Create Automaker configuration
RUN mkdir -p /opt/configs/automaker && \
    cat > /opt/configs/automaker/config.yaml << 'EOF'
# Automaker Development Studio Configuration
name: "automaker"
version: "1.0.0"
description: "Autonomous AI development studio that transforms how you build software"

# AI Model Configuration
models:
  primary:
    provider: "anthropic"
    model: "claude-3-sonnet-20240229"
    max_tokens: 4096
    temperature: 0.1
  
  secondary:
    provider: "openai"
    model: "gpt-4"
    max_tokens: 4096
    temperature: 0.1
  
  code_generation:
    provider: "anthropic"
    model: "claude-3-sonnet-20240229"
    max_tokens: 8192
    temperature: 0.0

# Development Studio Features
studio:
  autonomous_development: true
  code_generation: true
  testing_automation: true
  deployment_automation: true
  monitoring: true
  
# Workflow Configuration
workflows:
  enabled: true
  auto_planning: true
  auto_implementation: true
  auto_testing: true
  auto_deployment: false  # Requires manual approval
  
# Docker Integration
docker:
  enabled: true
  auto_containerization: true
  image_optimization: true
  multi_stage_builds: true
  
# Development Environment
environment:
  workspace: "/workspace"
  projects: "/workspace/automaker-projects"
  templates: "/opt/configs/automaker/templates"
  logs: "/opt/logs/automaker"
  
# Quality Assurance
qa:
  code_review: true
  security_scanning: true
  performance_testing: true
  documentation_generation: true
EOF

# Create Automaker project templates
RUN mkdir -p /opt/configs/automaker/templates && \
    cat > /opt/configs/automaker/templates/web-app.yaml << 'EOF'
# Web Application Template
name: "web-app"
description: "Full-stack web application template"

stack:
  frontend: "react"
  backend: "fastapi"
  database: "postgresql"
  cache: "redis"
  
structure:
  - "frontend/"
  - "backend/"
  - "database/"
  - "docker/"
  - "tests/"
  - "docs/"
  
dependencies:
  frontend:
    - "react"
    - "typescript"
    - "tailwindcss"
  backend:
    - "fastapi"
    - "sqlalchemy"
    - "alembic"
    - "pytest"
    
deployment:
  containerized: true
  orchestration: "docker-compose"
  monitoring: true
EOF

# Create Automaker startup script
RUN cat > /opt/pipelines/automaker/start-automaker.sh << 'EOF'
#!/bin/bash
# Automaker Development Studio Startup Script

echo "Starting Automaker Development Studio..."
echo "Configuration: /opt/configs/automaker/config.yaml"
echo "Workspace: /workspace"
echo "Projects: /workspace/automaker-projects"
echo "Logs: /opt/logs/automaker"

# Create necessary directories
mkdir -p /opt/logs/automaker
mkdir -p /workspace/automaker-projects

# Activate Python virtual environment
source /home/ubuntu/.venv/bin/activate

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "Warning: Docker not available for containerization features"
fi

# Check API keys
if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: No AI API keys set (ANTHROPIC_API_KEY, OPENAI_API_KEY)"
fi

echo "Automaker Development Studio is configured and ready"
echo "Features:"
echo "- Autonomous AI development workflows"
echo "- Code generation and testing automation"
echo "- Docker integration and containerization"
echo "- Multi-model AI support (Claude, GPT-4)"
echo "- Project templates and scaffolding"
echo "- Quality assurance and security scanning"

# Note: Actual Automaker execution would go here
# This is a placeholder for the Automaker development studio
EOF

RUN chmod +x /opt/pipelines/automaker/start-automaker.sh

# Install InfiAgent (MLA) Framework
RUN cd /opt/pipelines && \
    git clone https://github.com/ChenglinPoly/infiAgent.git infiagent || \
    (mkdir -p infiagent && echo "InfiAgent repository placeholder" > infiagent/README.md)

# Note: InfiAgent Python dependencies will be installed in development_enhanced stage

# Create InfiAgent configuration directory and files
RUN mkdir -p /opt/configs/infiagent/agents && \
    mkdir -p /opt/configs/infiagent/workflows && \
    mkdir -p /opt/configs/infiagent/templates && \
    cat > /opt/configs/infiagent/mla-config.yaml << 'EOF'
# InfiAgent (Multi-Level Agent) Configuration
name: "infiagent-mla"
version: "1.0.0"
description: "Multi-Level Agent framework for unlimited runtime without chaos"

# Multi-Level Agent Architecture
mla:
  enabled: true
  unlimited_runtime: true
  chaos_prevention: true
  resource_management: true
  conversation_history_management: true
  
# Agent Levels
levels:
  level_1:
    name: "coordinator"
    role: "task_coordination"
    max_context: 50000
    memory_limit: "1GB"
    
  level_2:
    name: "specialist"
    role: "domain_specific"
    max_context: 30000
    memory_limit: "512MB"
    
  level_3:
    name: "executor"
    role: "task_execution"
    max_context: 20000
    memory_limit: "256MB"

# Resource Management
resources:
  memory_monitoring: true
  context_rotation: true
  garbage_collection: true
  task_resource_tracking: true
  
# Agent Configuration
agents:
  general_purpose:
    type: "multi_level"
    capabilities: ["reasoning", "planning", "execution"]
    specializations: []
    
  semi_specialized:
    type: "domain_specific"
    capabilities: ["coding", "analysis", "testing"]
    specializations: ["python", "javascript", "docker"]

# Runtime Configuration
runtime:
  unlimited: true
  crash_prevention: true
  auto_recovery: true
  resource_cleanup: true
  
# Workspace Configuration
workspace: "/workspace"
agent_configs: "/opt/configs/infiagent/agents"
workflow_configs: "/opt/configs/infiagent/workflows"
logs: "/opt/logs/infiagent"
EOF

# Create sample agent configuration
RUN cat > /opt/configs/infiagent/agents/coding-agent.yaml << 'EOF'
# Coding Agent Configuration
name: "coding-agent"
type: "semi_specialized"
level: 2

capabilities:
  - "code_generation"
  - "code_review"
  - "debugging"
  - "testing"
  - "documentation"

specializations:
  languages:
    - "python"
    - "javascript"
    - "typescript"
    - "bash"
  frameworks:
    - "fastapi"
    - "react"
    - "docker"
    
resources:
  max_memory: "512MB"
  max_context: 30000
  timeout: 300
  
behavior:
  autonomous: true
  learning: true
  context_preservation: true
EOF

# Create sample workflow configuration
RUN cat > /opt/configs/infiagent/workflows/development-workflow.yaml << 'EOF'
# Development Workflow Configuration
name: "development-workflow"
description: "Multi-agent development workflow"

agents:
  - name: "planner"
    level: 1
    role: "planning"
    
  - name: "coder"
    level: 2
    role: "implementation"
    
  - name: "tester"
    level: 2
    role: "testing"
    
  - name: "reviewer"
    level: 1
    role: "review"

workflow:
  steps:
    - agent: "planner"
      action: "analyze_requirements"
      
    - agent: "planner"
      action: "create_plan"
      
    - agent: "coder"
      action: "implement_code"
      
    - agent: "tester"
      action: "run_tests"
      
    - agent: "reviewer"
      action: "review_results"
      
coordination:
  handoff_enabled: true
  context_sharing: true
  resource_isolation: true
EOF

# Create InfiAgent startup script
RUN cat > /opt/pipelines/infiagent/start-infiagent.sh << 'EOF'
#!/bin/bash
# InfiAgent (MLA) Framework Startup Script

echo "Starting InfiAgent (Multi-Level Agent) Framework..."
echo "Configuration: /opt/configs/infiagent/mla-config.yaml"
echo "Agent Configs: /opt/configs/infiagent/agents/"
echo "Workflow Configs: /opt/configs/infiagent/workflows/"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/infiagent"

# Create necessary directories
mkdir -p /opt/logs/infiagent
mkdir -p /workspace/infiagent-sessions

# Activate Python virtual environment
source /home/ubuntu/.venv/bin/activate

# Check system resources
echo "System Resources:"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "CPU Cores: $(nproc)"
echo "Disk Space: $(df -h /workspace | tail -1 | awk '{print $4}')"

# Check API keys
if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: No AI API keys set"
fi

echo "InfiAgent (MLA) Framework is configured and ready"
echo "Features:"
echo "- Multi-Level Agent architecture"
echo "- Unlimited runtime without chaos"
echo "- Resource management and monitoring"
echo "- Conversation history management"
echo "- Crash prevention and auto-recovery"
echo "- General-purpose and semi-specialized agents"

# Note: Actual InfiAgent execution would go here
# This is a placeholder for the InfiAgent framework
EOF

RUN chmod +x /opt/pipelines/infiagent/start-infiagent.sh

# Install MAI-UI GUI Agent Models
RUN cd /opt/pipelines && \
    git clone https://github.com/Tongyi-MAI/MAI-UI.git mai-ui || \
    (mkdir -p mai-ui && echo "MAI-UI repository placeholder" > mai-ui/README.md)

# Note: MAI-UI Python dependencies will be installed in development_enhanced stage

# Create MAI-UI configuration
RUN mkdir -p /opt/configs/mai-ui/{models,cache} && \
    cat > /opt/configs/mai-ui/config.yaml << 'EOF'
# MAI-UI GUI Agent Models Configuration
name: "mai-ui"
version: "1.0.0"
description: "GUI agent foundation models spanning multiple sizes"

# Model Variants
models:
  mai_2b:
    name: "MAI-UI-2B"
    size: "2B"
    type: "gui_agent"
    precision: "fp16"
    quantization: "4bit"
    
  mai_8b:
    name: "MAI-UI-8B"
    size: "8B"
    type: "gui_agent"
    precision: "fp16"
    quantization: "4bit"
    
  mai_32b:
    name: "MAI-UI-32B"
    size: "32B"
    type: "gui_agent"
    precision: "fp16"
    quantization: "8bit"
    
  mai_235b_a22b:
    name: "MAI-UI-235B-A22B"
    size: "235B"
    active_params: "22B"
    type: "gui_agent_moe"
    precision: "fp16"
    quantization: "8bit"

# Model Paths
paths:
  models: "/opt/configs/mai-ui/models"
  cache: "/opt/configs/mai-ui/cache"
  checkpoints: "/workspace/mai-ui-checkpoints"
  
# GPU Configuration
gpu:
  enabled: true
  device: "auto"
  memory_fraction: 0.8
  mixed_precision: true
  
# GUI Agent Capabilities
capabilities:
  screen_understanding: true
  ui_interaction: true
  visual_reasoning: true
  action_planning: true
  multimodal_processing: true
  
# Inference Configuration
inference:
  batch_size: 1
  max_length: 2048
  temperature: 0.1
  top_p: 0.9
  do_sample: true
  
# Environment
workspace: "/workspace"
logs: "/opt/logs/mai-ui"
temp: "/tmp/mai-ui"
EOF

# Create model download script
RUN cat > /opt/pipelines/mai-ui/download-models.sh << 'EOF'
#!/bin/bash
# MAI-UI Model Download Script

echo "MAI-UI Model Download Script"
echo "Note: This is a placeholder for model downloads"
echo "Actual models would be downloaded from Hugging Face Hub"

# Create model directories
mkdir -p /opt/configs/mai-ui/models/{2b,8b,32b,235b-a22b}
mkdir -p /opt/configs/mai-ui/cache

# Create placeholder model info files
cat > /opt/configs/mai-ui/models/2b/model_info.json << 'MODELEOF'
{
  "name": "MAI-UI-2B",
  "size": "2B",
  "type": "gui_agent",
  "status": "placeholder",
  "download_url": "https://huggingface.co/Tongyi-MAI/MAI-UI-2B",
  "requirements": {
    "memory": "4GB",
    "gpu_memory": "2GB"
  }
}
MODELEOF

cat > /opt/configs/mai-ui/models/8b/model_info.json << 'MODELEOF'
{
  "name": "MAI-UI-8B", 
  "size": "8B",
  "type": "gui_agent",
  "status": "placeholder",
  "download_url": "https://huggingface.co/Tongyi-MAI/MAI-UI-8B",
  "requirements": {
    "memory": "16GB",
    "gpu_memory": "8GB"
  }
}
MODELEOF

echo "Model placeholders created. To download actual models:"
echo "1. Set up Hugging Face authentication"
echo "2. Use huggingface-hub to download models"
echo "3. Update model paths in configuration"
EOF

RUN chmod +x /opt/pipelines/mai-ui/download-models.sh

# Create MAI-UI startup script
RUN cat > /opt/pipelines/mai-ui/start-mai-ui.sh << 'EOF'
#!/bin/bash
# MAI-UI GUI Agent Models Startup Script

echo "Starting MAI-UI GUI Agent Models..."
echo "Configuration: /opt/configs/mai-ui/config.yaml"
echo "Models: /opt/configs/mai-ui/models/"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/mai-ui"

# Create necessary directories
mkdir -p /opt/logs/mai-ui
mkdir -p /tmp/mai-ui
mkdir -p /workspace/mai-ui-checkpoints

# Activate Python virtual environment
source /home/ubuntu/.venv/bin/activate

# Check GPU availability
if command -v nvidia-smi &> /dev/null; then
    echo "GPU Information:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits
else
    echo "Warning: No GPU detected. Models will run on CPU (slower performance)"
fi

# Check PyTorch installation
python -c "import torch; print(f'PyTorch version: {torch.__version__}')"
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

echo "MAI-UI GUI Agent Models system is configured and ready"
echo "Available model variants:"
echo "- MAI-UI-2B: Lightweight GUI agent (2B parameters)"
echo "- MAI-UI-8B: Balanced GUI agent (8B parameters)"  
echo "- MAI-UI-32B: Advanced GUI agent (32B parameters)"
echo "- MAI-UI-235B-A22B: Expert GUI agent (235B total, 22B active)"

echo "Capabilities:"
echo "- Screen understanding and visual reasoning"
echo "- UI interaction and action planning"
echo "- Multimodal processing"

echo "To download models, run: /opt/pipelines/mai-ui/download-models.sh"

# Note: Actual MAI-UI model loading would go here
# This is a placeholder for the MAI-UI system
EOF

RUN chmod +x /opt/pipelines/mai-ui/start-mai-ui.sh

# Install Loki-Mode Autonomous System
RUN cd /opt/pipelines && \
    git clone https://github.com/asklokesh/claudeskill-loki-mode.git loki-mode || \
    (mkdir -p loki-mode && echo "Loki-Mode repository placeholder" > loki-mode/README.md)

# Install Loki-Mode Node.js dependencies
RUN cd /opt/pipelines/loki-mode && \
    npm init -y --name loki-mode && \
    npm install \
    @anthropic-ai/sdk \
    openai \
    axios \
    express \
    socket.io \
    commander \
    chalk \
    inquirer \
    fs-extra \
    yaml \
    lodash \
    uuid \
    moment \
    bull \
    redis

# Create Loki-Mode configuration
RUN mkdir -p /opt/configs/loki-mode/skills && \
    mkdir -p /opt/configs/loki-mode/agents && \
    mkdir -p /opt/configs/loki-mode/workflows && \
    cat > /opt/configs/loki-mode/config.json << 'EOF'
{
  "name": "loki-mode",
  "version": "1.0.0",
  "description": "The First Truly Autonomous Multi-Agent Startup System",
  
  "autonomous_system": {
    "enabled": true,
    "multi_agent": true,
    "startup_automation": true,
    "self_management": true
  },
  
  "claude_integration": {
    "model": "claude-3-sonnet-20240229",
    "max_tokens": 4096,
    "temperature": 0.1,
    "skills_enabled": true
  },
  
  "multi_agent_architecture": {
    "coordinator": {
      "role": "system_coordination",
      "capabilities": ["planning", "resource_allocation", "monitoring"]
    },
    "executor": {
      "role": "task_execution", 
      "capabilities": ["implementation", "testing", "deployment"]
    },
    "monitor": {
      "role": "system_monitoring",
      "capabilities": ["health_check", "performance", "alerts"]
    }
  },
  
  "startup_system": {
    "auto_initialization": true,
    "dependency_management": true,
    "service_orchestration": true,
    "health_monitoring": true
  },
  
  "skills": {
    "directory": "/opt/configs/loki-mode/skills",
    "auto_discovery": true,
    "dynamic_loading": true
  },
  
  "workspace": "/workspace",
  "logs": "/opt/logs/loki-mode",
  "temp": "/tmp/loki-mode"
}
EOF

# Create sample skills
RUN cat > /opt/configs/loki-mode/skills/coding-skill.json << 'EOF'
{
  "name": "coding-skill",
  "description": "Advanced coding and development capabilities",
  "version": "1.0.0",
  
  "capabilities": [
    "code_generation",
    "code_review", 
    "debugging",
    "testing",
    "refactoring"
  ],
  
  "languages": [
    "python",
    "javascript",
    "typescript",
    "bash",
    "dockerfile"
  ],
  
  "frameworks": [
    "fastapi",
    "react",
    "express",
    "docker"
  ],
  
  "tools": [
    "git",
    "npm",
    "pip",
    "docker",
    "pytest",
    "jest"
  ],
  
  "autonomous": true,
  "learning": true
}
EOF

RUN cat > /opt/configs/loki-mode/skills/startup-skill.json << 'EOF'
{
  "name": "startup-skill",
  "description": "Autonomous startup and business development capabilities",
  "version": "1.0.0",
  
  "capabilities": [
    "business_planning",
    "product_development",
    "market_analysis",
    "resource_management",
    "automation"
  ],
  
  "domains": [
    "saas",
    "ai_tools",
    "developer_tools",
    "automation",
    "productivity"
  ],
  
  "processes": [
    "mvp_development",
    "user_research",
    "growth_hacking",
    "monetization",
    "scaling"
  ],
  
  "autonomous": true,
  "multi_agent": true
}
EOF

# Create Loki-Mode startup script
RUN cat > /opt/pipelines/loki-mode/start-loki-mode.sh << 'EOF'
#!/bin/bash
# Loki-Mode Autonomous Multi-Agent Startup System

echo "Starting Loki-Mode Autonomous Multi-Agent Startup System..."
echo "Configuration: /opt/configs/loki-mode/config.json"
echo "Skills: /opt/configs/loki-mode/skills/"
echo "Workspace: /workspace"
echo "Logs: /opt/logs/loki-mode"

# Create necessary directories
mkdir -p /opt/logs/loki-mode
mkdir -p /tmp/loki-mode
mkdir -p /workspace/loki-projects

# Check Node.js availability
if ! command -v node &> /dev/null; then
    echo "Error: Node.js not found"
    exit 1
fi

# Check API keys
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Warning: ANTHROPIC_API_KEY not set"
fi

# Check Redis availability (for job queues)
if command -v redis-cli &> /dev/null; then
    echo "Redis available for job queuing"
else
    echo "Warning: Redis not available, using in-memory queuing"
fi

echo "Loki-Mode System is configured and ready"
echo "Features:"
echo "- Truly autonomous multi-agent system"
echo "- Startup automation and self-management"
echo "- Claude skills integration"
echo "- Dynamic skill discovery and loading"
echo "- Multi-agent coordination (coordinator, executor, monitor)"
echo "- Business and technical development capabilities"

echo "Available Skills:"
ls -1 /opt/configs/loki-mode/skills/*.json | xargs -I {} basename {} .json

# Note: Actual Loki-Mode execution would go here
# This is a placeholder for the Loki-Mode system
EOF

RUN chmod +x /opt/pipelines/loki-mode/start-loki-mode.sh

# Install Additional Development Tools

# Create tools directory first
RUN mkdir -p /opt/tools

# Install KnowNote (Local-first NotebookLM alternative)
RUN cd /opt/tools && \
    git clone https://github.com/MrSibe/KnowNote.git knownote || \
    (mkdir -p knownote && echo "KnowNote repository placeholder" > knownote/README.md)

# Note: KnowNote Python dependencies will be installed in development_enhanced stage

# Install Vibium (Browser automation)
RUN cd /opt/tools && \
    git clone https://github.com/VibiumDev/vibium.git vibium || \
    (mkdir -p vibium && echo "Vibium repository placeholder" > vibium/README.md)

RUN cd /opt/tools/vibium && \
    (npm install \
    playwright \
    puppeteer \
    selenium-webdriver \
    cheerio \
    axios \
    commander || echo "Vibium npm install failed, continuing...")

# Install OpenTinker (Agentic RL as a Service)
RUN cd /opt/tools && \
    git clone https://github.com/open-tinker/OpenTinker.git opentinker || \
    (mkdir -p opentinker && echo "OpenTinker repository placeholder" > opentinker/README.md)

# Note: OpenTinker Python dependencies will be installed in development_enhanced stage

# Install ProxyPal (AI subscription proxy)
RUN cd /opt/tools && \
    git clone https://github.com/heyhuynhgiabuu/proxypal.git proxypal || \
    (mkdir -p proxypal && echo "ProxyPal repository placeholder" > proxypal/README.md)

RUN cd /opt/tools/proxypal && \
    (npm install \
    express \
    http-proxy-middleware \
    cors \
    helmet \
    rate-limiter-flexible \
    jsonwebtoken || echo "ProxyPal npm install failed, continuing...")

# Install claude-code-transcript tools
RUN cd /opt/tools && \
    git clone https://github.com/simonw/claude-code-transcripts.git claude-transcripts || \
    (mkdir -p claude-transcripts && echo "Claude code transcripts repository placeholder" > claude-transcripts/README.md)

# Note: Claude-transcripts Python dependencies will be installed in development_enhanced stage

# Create configurations for additional tools
RUN mkdir -p /opt/configs/knownote && \
    mkdir -p /opt/configs/vibium && \
    mkdir -p /opt/configs/opentinker && \
    mkdir -p /opt/configs/proxypal && \
    mkdir -p /opt/configs/claude-transcripts

# KnowNote configuration
RUN cat > /opt/configs/knownote/config.yaml << 'EOF'
# KnowNote Configuration
name: "knownote"
description: "Local-first, open-source alternative to Google NotebookLM"

features:
  local_first: true
  private_llms: true
  no_docker_required: true
  full_control: true

llm:
  provider: "local"
  model: "llama2"  # Can be configured for different local models
  embedding_model: "sentence-transformers/all-MiniLM-L6-v2"

storage:
  vector_db: "chromadb"
  documents: "/workspace/knownote-docs"
  embeddings: "/workspace/knownote-embeddings"

interface:
  type: "streamlit"
  port: 8501
  host: "0.0.0.0"
EOF

# Vibium configuration
RUN cat > /opt/configs/vibium/config.json << 'EOF'
{
  "name": "vibium",
  "description": "Browser automation without the drama",
  
  "browsers": {
    "default": "playwright",
    "supported": ["playwright", "puppeteer", "selenium"]
  },
  
  "automation": {
    "headless": true,
    "timeout": 30000,
    "wait_for_selector": 5000,
    "screenshot_on_failure": true
  },
  
  "features": {
    "drama_free": true,
    "simple_api": true,
    "reliable_selectors": true,
    "auto_wait": true
  }
}
EOF

# OpenTinker configuration
RUN cat > /opt/configs/opentinker/config.yaml << 'EOF'
# OpenTinker Configuration
name: "opentinker"
description: "Democratizing Agentic Reinforcement Learning as a Service"

rl_service:
  enabled: true
  democratized: true
  agentic: true

algorithms:
  - "PPO"
  - "A2C"
  - "DQN"
  - "SAC"
  - "TD3"

environments:
  - "gymnasium"
  - "custom"

features:
  distributed_training: true
  hyperparameter_tuning: true
  experiment_tracking: true
  model_serving: true

tracking:
  backend: "tensorboard"
  experiment_name: "agentic-rl"
EOF

# ProxyPal configuration
RUN cat > /opt/configs/proxypal/config.json << 'EOF'
{
  "name": "proxypal",
  "description": "Use AI subscriptions with any coding tool",
  
  "proxy": {
    "port": 8888,
    "host": "0.0.0.0",
    "rate_limit": {
      "requests_per_minute": 60,
      "burst": 10
    }
  },
  
  "supported_services": {
    "claude": {
      "endpoint": "https://api.anthropic.com",
      "auth_type": "api_key"
    },
    "openai": {
      "endpoint": "https://api.openai.com",
      "auth_type": "api_key"
    },
    "github_copilot": {
      "endpoint": "https://api.github.com",
      "auth_type": "token"
    }
  },
  
  "features": {
    "native_desktop_app": true,
    "cli_proxy_api": true,
    "universal_compatibility": true
  }
}
EOF

# Claude transcripts configuration
RUN cat > /opt/configs/claude-transcripts/config.yaml << 'EOF'
# Claude Code Transcripts Configuration
name: "claude-transcripts"
description: "Tools for working with Claude code transcripts"

features:
  transcript_parsing: true
  code_extraction: true
  session_analysis: true
  export_formats: ["markdown", "html", "json"]

claude:
  model: "claude-3-sonnet-20240229"
  max_tokens: 4096

output:
  directory: "/workspace/claude-transcripts"
  format: "markdown"
EOF

# Create startup scripts for additional tools
RUN cat > /opt/tools/knownote/start-knownote.sh << 'EOF'
#!/bin/bash
echo "Starting KnowNote - Local-first NotebookLM alternative..."
source /home/ubuntu/.venv/bin/activate
mkdir -p /workspace/knownote-docs /workspace/knownote-embeddings
echo "KnowNote configured for local-first operation"
echo "Features: Private LLMs, Full control, No Docker required"
EOF

RUN cat > /opt/tools/vibium/start-vibium.sh << 'EOF'
#!/bin/bash
echo "Starting Vibium - Browser automation without the drama..."
echo "Supported browsers: Playwright, Puppeteer, Selenium"
echo "Features: Drama-free automation, Simple API, Reliable selectors"
EOF

RUN cat > /opt/tools/opentinker/start-opentinker.sh << 'EOF'
#!/bin/bash
echo "Starting OpenTinker - Agentic RL as a Service..."
source /home/ubuntu/.venv/bin/activate
echo "Democratizing Agentic Reinforcement Learning"
echo "Supported algorithms: PPO, A2C, DQN, SAC, TD3"
EOF

RUN cat > /opt/tools/proxypal/start-proxypal.sh << 'EOF'
#!/bin/bash
echo "Starting ProxyPal - AI subscription proxy..."
echo "Proxy server for Claude, ChatGPT, Gemini, GitHub Copilot"
echo "Native desktop app with CLI proxy API"
EOF

RUN cat > /opt/tools/claude-transcripts/start-claude-transcripts.sh << 'EOF'
#!/bin/bash
echo "Starting Claude Code Transcripts tools..."
source /home/ubuntu/.venv/bin/activate
mkdir -p /workspace/claude-transcripts
echo "Tools for parsing and analyzing Claude code transcripts"
EOF

# Make all startup scripts executable
RUN chmod +x /opt/tools/*/start-*.sh

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
RUN chown -R ubuntu:ubuntu /opt /workspace /home/ubuntu 2>/dev/null || true

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

# Install Python dependencies for pipeline projects
# Auto-Claude Framework dependencies
RUN cd /opt/pipelines/auto-claude && \
    /home/ubuntu/.venv/bin/pip install \
    langchain \
    langchain-anthropic \
    langchain-openai \
    pydantic \
    asyncio \
    aiofiles \
    jinja2 \
    gitpython

# Automaker dependencies
RUN cd /opt/pipelines/automaker && \
    /home/ubuntu/.venv/bin/pip install \
    google-generativeai \
    langchain-google-genai \
    docker \
    kubernetes \
    celery \
    redis \
    sqlalchemy \
    alembic

# InfiAgent dependencies
RUN cd /opt/pipelines/infiagent && \
    /home/ubuntu/.venv/bin/pip install \
    langchain-openai \
    langchain-anthropic \
    aiofiles \
    celery \
    psutil \
    memory-profiler \
    configparser \
    jsonschema

# MAI-UI dependencies
RUN cd /opt/pipelines/mai-ui && \
    /home/ubuntu/.venv/bin/pip install \
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
    safetensors

# Additional tools dependencies
# KnowNote dependencies
RUN cd /opt/tools/knownote && \
    /home/ubuntu/.venv/bin/pip install \
    streamlit \
    langchain \
    chromadb \
    sentence-transformers \
    tf-keras \
    pypdf \
    python-docx \
    markdown \
    beautifulsoup4

# OpenTinker dependencies
RUN cd /opt/tools/opentinker && \
    /home/ubuntu/.venv/bin/pip install \
    gymnasium \
    stable-baselines3 \
    ray[rllib] \
    tensorboard \
    wandb \
    mlflow \
    optuna

# Claude-transcripts dependencies
RUN cd /opt/tools/claude-transcripts && \
    /home/ubuntu/.venv/bin/pip install \
    jinja2

# Clean up pip cache after all Python package installations
RUN /home/ubuntu/.venv/bin/pip cache purge

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

# Set working directory
WORKDIR /workspace

# Expose common development ports
EXPOSE 3000 8000 8080 9000
# Expose VNC and NoVNC ports
EXPOSE 5901 6080

# Ensure proper ownership in final stage
USER root
RUN chown -R ubuntu:ubuntu /opt /workspace /home/ubuntu 2>/dev/null || true

# Create startup script
COPY scripts/base-container-setup.sh /usr/local/bin/base-container-setup.sh
RUN chmod +x /usr/local/bin/base-container-setup.sh \
    && /usr/local/bin/base-container-setup.sh ubuntu

# Fix: Create symlinks for agentic commands in system path
RUN if [ -f /home/ubuntu/.local/bin/agentic-status ]; then \
        ln -s /home/ubuntu/.local/bin/agentic-status /usr/local/bin/agentic-status && \
        ln -s /home/ubuntu/.local/bin/init-project /usr/local/bin/init-project && \
        chmod +x /usr/local/bin/agentic-status && \
        chmod +x /usr/local/bin/init-project; \
    fi

# Fix: Ensure all startup scripts exit cleanly and handle missing venv
RUN for script in /opt/pipelines/*/start-*.sh /opt/tools/*/start-*.sh; do \
        if [ -f "$script" ]; then \
            # Make venv activation conditional \
            sed -i 's|^source /home/ubuntu/.venv/bin/activate|if [ -f /home/ubuntu/.venv/bin/activate ]; then source /home/ubuntu/.venv/bin/activate; else echo "Warning: venv not found, using system Python"; fi|g' "$script" && \
            # Ensure script exits 0 \
            if ! grep -q "^exit 0" "$script"; then \
                echo "" >> "$script" && \
                echo "exit 0" >> "$script"; \
            fi \
        fi \
    done

# Ensure Git is configured for ubuntu user
RUN sudo -u ubuntu git config --global init.defaultBranch main && \
    sudo -u ubuntu git config --global user.name "Agentic ubuntu" && \
    sudo -u ubuntu git config --global user.email "ubuntu@agentic-coding.local" && \
    sudo -u ubuntu git config --global core.editor "vim" && \
    sudo -u ubuntu git config --global pull.rebase false && \
    chown ubuntu:ubuntu /home/ubuntu/.gitconfig 2>/dev/null || true

RUN cat > /usr/local/bin/start-container.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Agentic Coding Pipeline Container..."
echo "Container started at: $(date)"

# Start Docker daemon if not running
if ! pgrep dockerd > /dev/null; then
    echo "Starting Docker daemon..."
    dockerd > /dev/null 2>&1 &

    # Wait for Docker to be ready
    echo "Waiting for Docker daemon to be ready..."
    timeout=30
    while [ $timeout -gt 0 ]; do
        if docker info > /dev/null 2>&1; then
            echo "Docker daemon is ready"
            break
        fi
        sleep 1
        timeout=$((timeout - 1))
    done

    if [ $timeout -eq 0 ]; then
        echo "Warning: Docker daemon did not start within 30 seconds"
    fi
fi

# Verify installations
echo "Verifying installations..."
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "Python version: $(python --version)"
echo "pip version: $(pip --version)"
echo "Git version: $(git --version)"
echo "Docker version: $(docker --version 2>/dev/null || echo 'Docker not available')"

# Start Supervisor to manage VNC and NoVNC services
echo ""
echo "Starting Supervisor to manage desktop services..."
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &
SUPERVISOR_PID=$!

# Wait for supervisor to start
sleep 2

# Check if supervisor is running
if kill -0 $SUPERVISOR_PID 2>/dev/null; then
    echo "✓ Supervisor started (PID: $SUPERVISOR_PID)"

    # Wait for VNC and NoVNC to start (supervisor will auto-start them)
    echo "Waiting for desktop services to initialize..."
    sleep 3

    # Check service status
    if pgrep -x "Xvnc" > /dev/null 2>&1; then
        echo "✓ VNC server started on display :1 (port 5901)"
    else
        echo "⚠ VNC server starting... (check logs: /var/log/supervisor/vncserver.log)"
    fi

    if pgrep -f "websockify.*6080" > /dev/null 2>&1; then
        echo "✓ NoVNC web interface started on port 6080"
    else
        echo "⚠ NoVNC starting... (check logs: /var/log/supervisor/novnc.log)"
    fi
else
    echo "⚠ Supervisor failed to start. Desktop services not available."
fi

# Create container readiness indicator
touch /workspace/.container-ready

# Switch to ubuntu user and start bash
echo ""
echo "Switching to ubuntu user..."
echo "Available pipeline projects:"
ls -1 /opt/pipelines/
echo ""
echo "Available tools:"
ls -1 /opt/tools/
echo ""
echo "Use 'agentic-status' to check system status"
echo "Use 'init-project <name> [type]' to create new projects"
echo ""
echo "Desktop Environment:"
echo "  VNC Server: Port 5901"
echo "  NoVNC Web: http://localhost:6080/vnc.html"
echo "  VNC Password: ubuntu"
echo "  Desktop status: desktop-status.sh"
echo "  Supervisor control: supervisorctl status"
echo ""
echo "Container is ready!"
exec su - ubuntu -c "cd /workspace && bash"
EOF

RUN chmod +x /usr/local/bin/start-container.sh

# Switch back to ubuntu user
USER ubuntu

# Set default command
CMD ["/usr/local/bin/start-container.sh"]

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/agentic-status > /dev/null 2>&1 || exit 1

# Add labels for metadata
LABEL maintainer="Agentic Coding Pipeline"
LABEL description="Comprehensive Docker container with multi-agent coding pipeline projects"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/ai_coding_pipeline"
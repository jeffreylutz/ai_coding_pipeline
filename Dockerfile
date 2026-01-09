# Multi-stage Dockerfile for Agentic Coding Pipeline Container
# Based on Ubuntu 24.04 LTS with comprehensive development environment

# =============================================================================
# Stage 1: Base System Setup
# =============================================================================
FROM ubuntu:24.04 AS base

# Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Update system and install essential packages
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
    # Process management
    supervisor \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -g $USER_GID $USERNAME 2>/dev/null || true \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME 2>/dev/null || usermod -u $USER_UID -g $USER_GID $USERNAME 2>/dev/null || true \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
RUN apt-get update && apt-get install -y \
    # Terminal and shell enhancements
    zsh \
    fish \
    tmux \
    screen \
    # File management
    ranger \
    mc \
    fzf \
    # Network and API tools
    httpie \
    curl \
    wget \
    netcat-openbsd \
    # Text processing
    jq \
    xmlstarlet \
    # Monitoring and system tools
    htop \
    iotop \
    nethogs \
    dstat \
    # Development utilities
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Database clients
    sqlite3 \
    postgresql-client \
    mysql-client \
    redis-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install oh-my-zsh for enhanced shell experience
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true

# Configure shell enhancements for developer user
USER $USERNAME
RUN if [ -d "/home/$USERNAME/.oh-my-zsh" ]; then \
        echo 'export ZSH="/home/$USERNAME/.oh-my-zsh"' >> /home/$USERNAME/.zshrc && \
        echo 'ZSH_THEME="robbyrussell"' >> /home/$USERNAME/.zshrc && \
        echo 'plugins=(git docker python node npm)' >> /home/$USERNAME/.zshrc && \
        echo 'source $ZSH/oh-my-zsh.sh' >> /home/$USERNAME/.zshrc && \
        echo 'source /home/$USERNAME/.venv/bin/activate' >> /home/$USERNAME/.zshrc; \
    fi

# Add useful aliases and environment setup
RUN echo 'alias ll="ls -la"' >> /home/$USERNAME/.bashrc && \
    echo 'alias la="ls -la"' >> /home/$USERNAME/.bashrc && \
    echo 'alias ..="cd .."' >> /home/$USERNAME/.bashrc && \
    echo 'alias ...="cd ../.."' >> /home/$USERNAME/.bashrc && \
    echo 'alias grep="grep --color=auto"' >> /home/$USERNAME/.bashrc && \
    echo 'alias fgrep="fgrep --color=auto"' >> /home/$USERNAME/.bashrc && \
    echo 'alias egrep="egrep --color=auto"' >> /home/$USERNAME/.bashrc && \
    echo 'export EDITOR=vim' >> /home/$USERNAME/.bashrc && \
    echo 'export PAGER=less' >> /home/$USERNAME/.bashrc

# Install additional Python packages for agentic coding
RUN /home/$USERNAME/.venv/bin/pip install \
    # AI and ML libraries
    langchain \
    langchain-community \
    langchain-openai \
    langchain-anthropic \
    chromadb \
    faiss-cpu \
    sentence-transformers \
    # API and web frameworks
    flask \
    django \
    starlette \
    # Data processing
    sqlalchemy \
    alembic \
    redis \
    celery \
    # Development tools
    pre-commit \
    bandit \
    safety \
    # Documentation
    mkdocs \
    sphinx

# Install additional Node.js packages for agentic development
RUN npm install -g \
    # API development
    @nestjs/cli \
    fastify-cli \
    # Testing and quality
    mocha \
    chai \
    nyc \
    # Build tools
    rollup \
    vite \
    # Utilities
    concurrently \
    cross-env \
    dotenv-cli

# Install Kiro Autonomous Agent
RUN mkdir -p /opt/pipelines/kiro && \
    cd /opt/pipelines/kiro && \
    echo "Kiro Autonomous Agent installation placeholder" > README.md && \
    echo "Visit https://kiro.dev/autonomous-agent/ for installation instructions" >> README.md

# Create Kiro configuration directory
RUN mkdir -p /opt/configs/kiro && \
    cat > /opt/configs/kiro/config.json << 'EOF'
{
  "name": "kiro-autonomous-agent",
  "version": "1.0.0",
  "description": "Kiro Autonomous Agent Configuration",
  "sandbox": {
    "enabled": true,
    "dockerfile_detection": true,
    "environment": "containerized"
  },
  "autonomous_operation": {
    "enabled": true,
    "context_maintenance": true,
    "learning": true
  },
  "workspace": "/workspace",
  "logs": "/opt/logs/kiro"
}
EOF

# Create Kiro startup script
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

# Install Auto-Claude Python dependencies
RUN cd /opt/pipelines/auto-claude && \
    /home/$USERNAME/.venv/bin/pip install \
    anthropic \
    openai \
    langchain \
    langchain-anthropic \
    langchain-openai \
    pydantic \
    asyncio \
    aiofiles \
    rich \
    typer \
    pyyaml \
    jinja2 \
    gitpython

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
source /home/developer/.venv/bin/activate

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

# Install Automaker Python dependencies
RUN cd /opt/pipelines/automaker && \
    /home/$USERNAME/.venv/bin/pip install \
    openai \
    anthropic \
    google-generativeai \
    langchain \
    langchain-openai \
    langchain-anthropic \
    langchain-google-genai \
    docker \
    kubernetes \
    pydantic \
    fastapi \
    uvicorn \
    celery \
    redis \
    sqlalchemy \
    alembic \
    pytest \
    pytest-asyncio

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
source /home/developer/.venv/bin/activate

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

# Install InfiAgent Python dependencies
RUN cd /opt/pipelines/infiagent && \
    /home/$USERNAME/.venv/bin/pip install \
    openai \
    anthropic \
    langchain \
    langchain-openai \
    langchain-anthropic \
    pydantic \
    asyncio \
    aiofiles \
    redis \
    celery \
    sqlalchemy \
    psutil \
    memory-profiler \
    configparser \
    jsonschema

# Create InfiAgent configuration directory and files
RUN mkdir -p /opt/configs/infiagent/{agents,workflows,templates} && \
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
source /home/developer/.venv/bin/activate

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

# Install MAI-UI Python dependencies
RUN cd /opt/pipelines/mai-ui && \
    /home/$USERNAME/.venv/bin/pip install \
    torch \
    torchvision \
    transformers \
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
source /home/developer/.venv/bin/activate

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
RUN mkdir -p /opt/configs/loki-mode/{skills,agents,workflows} && \
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

# Install KnowNote (Local-first NotebookLM alternative)
RUN cd /opt/tools && \
    git clone https://github.com/MrSibe/KnowNote.git knownote || \
    (mkdir -p knownote && echo "KnowNote repository placeholder" > knownote/README.md)

RUN cd /opt/tools/knownote && \
    /home/$USERNAME/.venv/bin/pip install \
    streamlit \
    langchain \
    chromadb \
    sentence-transformers \
    pypdf \
    python-docx \
    markdown \
    beautifulsoup4 \
    requests

# Install Vibium (Browser automation)
RUN cd /opt/tools && \
    git clone https://github.com/VibiumDev/vibium.git vibium || \
    (mkdir -p vibium && echo "Vibium repository placeholder" > vibium/README.md)

RUN cd /opt/tools/vibium && \
    npm init -y --name vibium && \
    npm install \
    playwright \
    puppeteer \
    selenium-webdriver \
    cheerio \
    axios \
    commander

# Install OpenTinker (Agentic RL as a Service)
RUN cd /opt/tools && \
    git clone https://github.com/open-tinker/OpenTinker.git opentinker || \
    (mkdir -p opentinker && echo "OpenTinker repository placeholder" > opentinker/README.md)

RUN cd /opt/tools/opentinker && \
    /home/$USERNAME/.venv/bin/pip install \
    gymnasium \
    stable-baselines3 \
    ray[rllib] \
    tensorboard \
    wandb \
    mlflow \
    optuna

# Install ProxyPal (AI subscription proxy)
RUN cd /opt/tools && \
    git clone https://github.com/heyhuynhgiabuu/proxypal.git proxypal || \
    (mkdir -p proxypal && echo "ProxyPal repository placeholder" > proxypal/README.md)

RUN cd /opt/tools/proxypal && \
    npm init -y --name proxypal && \
    npm install \
    express \
    http-proxy-middleware \
    cors \
    helmet \
    rate-limiter-flexible \
    jsonwebtoken

# Install claude-code-transcript tools
RUN cd /opt/tools && \
    git clone https://github.com/simonw/claude-code-transcripts.git claude-transcripts || \
    (mkdir -p claude-transcripts && echo "Claude code transcripts repository placeholder" > claude-transcripts/README.md)

RUN cd /opt/tools/claude-transcripts && \
    /home/$USERNAME/.venv/bin/pip install \
    anthropic \
    click \
    rich \
    pyyaml \
    jinja2

# Create configurations for additional tools
RUN mkdir -p /opt/configs/{knownote,vibium,opentinker,proxypal,claude-transcripts}

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
source /home/developer/.venv/bin/activate
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
source /home/developer/.venv/bin/activate
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
source /home/developer/.venv/bin/activate
mkdir -p /workspace/claude-transcripts
echo "Tools for parsing and analyzing Claude code transcripts"
EOF

# Make all startup scripts executable
RUN chmod +x /opt/tools/*/start-*.sh

# Set proper ownership and permissions for all directories
RUN chown -R $USERNAME:$USERNAME /opt/pipelines /opt/tools /opt/configs /workspace /home/$USERNAME && \
    chmod -R 755 /opt/pipelines /opt/tools /opt/configs && \
    chmod -R 775 /workspace && \
    find /opt -name "*.sh" -exec chmod +x {} \; && \
    # Clean up package caches and temporary files to reduce image size
    apt-get autoremove -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    # Clean up npm cache
    npm cache clean --force && \
    # Clean up pip cache
    /home/$USERNAME/.venv/bin/pip cache purge && \
    # Remove git repositories .git directories to save space (keep source code)
    find /opt/pipelines -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/tools -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# =============================================================================
# Stage 4: Development Tools and Directories
# =============================================================================
FROM base_integration AS development_enhanced

# Create directories for pipeline projects
RUN mkdir -p /opt/pipelines \
    && mkdir -p /opt/tools \
    && mkdir -p /opt/configs \
    && mkdir -p /workspace \
    && chown -R $USERNAME:$USERNAME /opt /workspace

# Switch to non-root user for remaining operations
USER $USERNAME
WORKDIR /home/$USERNAME

# Create Python virtual environment for global tools
RUN python -m venv /home/$USERNAME/.venv \
    && echo "source /home/$USERNAME/.venv/bin/activate" >> /home/$USERNAME/.bashrc

# Install common Python packages
RUN /home/$USERNAME/.venv/bin/pip install --upgrade pip setuptools wheel \
    && /home/$USERNAME/.venv/bin/pip install \
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
    ipython \
    pandas \
    numpy \
    torch \
    transformers \
    openai \
    anthropic

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

# Create startup script
USER root
COPY scripts/base-container-setup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/base-container-setup.sh && \
    /usr/local/bin/base-container-setup.sh

RUN cat > /usr/local/bin/start-container.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Agentic Coding Pipeline Container..."
echo "Container started at: $(date)"

# Start Docker daemon if not running
if ! pgrep dockerd > /dev/null; then
    echo "Starting Docker daemon..."
    dockerd &
    sleep 5
fi

# Verify installations
echo "Verifying installations..."
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "Python version: $(python --version)"
echo "pip version: $(pip --version)"
echo "Git version: $(git --version)"
echo "Docker version: $(docker --version)"

# Switch to developer user and start bash
echo "Switching to developer user..."
echo "Available pipeline projects:"
ls -1 /opt/pipelines/
echo ""
echo "Available tools:"
ls -1 /opt/tools/
echo ""
echo "Use 'agentic-status' to check system status"
echo "Use 'init-project <name> [type]' to create new projects"
echo ""
exec su - developer -c "cd /workspace && bash"
EOF

RUN chmod +x /usr/local/bin/start-container.sh

# Switch back to developer user
USER $USERNAME

# Set default command
CMD ["/usr/local/bin/start-container.sh"]

# Add labels for metadata
LABEL maintainer="Agentic Coding Pipeline"
LABEL description="Comprehensive Docker container with multi-agent coding pipeline projects"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/ai_coding_pipeline"
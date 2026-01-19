#!/bin/bash

# Base Container Image Integration Script
# This script replicates the essential configurations from the agentic_coding_flywheel_setup

set -e

echo "Configuring Base Container Image components..."

# Detect the primary non-root user dynamically
# First check for passed argument, then look for UID 1000, then check common usernames
if [ -n "$1" ]; then
    DEV_USER="$1"
    echo "Using provided username: $DEV_USER"
elif id -u 1000 >/dev/null 2>&1; then
    DEV_USER=$(id -un 1000)
    echo "Detected user with UID 1000: $DEV_USER"
elif id "ubuntu" >/dev/null 2>&1; then
    DEV_USER="ubuntu"
    echo "Detected ubuntu user"
elif id "developer" >/dev/null 2>&1; then
    DEV_USER="developer"
    echo "Detected developer user"
else
    echo "Warning: No suitable development user found, using current user or root"
    DEV_USER=$(whoami)
fi

DEV_HOME=$(eval echo ~$DEV_USER)
echo "Development user: $DEV_USER (home: $DEV_HOME)"

# Create essential directories
mkdir -p /opt/agentic-tools
mkdir -p /opt/configs/base
mkdir -p "$DEV_HOME/.config"
mkdir -p "$DEV_HOME/.local/bin"

# Configure Git with enhanced settings for agentic development
if [ -d "$DEV_HOME" ]; then
    # Configure as development user
    export HOME="$DEV_HOME"
    sudo -u "$DEV_USER" git config --global init.defaultBranch main
    sudo -u "$DEV_USER" git config --global user.name "Agentic Developer"
    sudo -u "$DEV_USER" git config --global user.email "$DEV_USER@agentic-coding.local"
    sudo -u "$DEV_USER" git config --global core.editor "vim"
    sudo -u "$DEV_USER" git config --global pull.rebase false
    sudo -u "$DEV_USER" git config --global push.default simple
    sudo -u "$DEV_USER" git config --global core.autocrlf input
    sudo -u "$DEV_USER" git config --global color.ui auto

    # Ensure proper ownership
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.gitconfig" 2>/dev/null || true
else
    # Fallback: configure for current user
    git config --global init.defaultBranch main
    git config --global user.name "Agentic Developer"
    git config --global user.email "$DEV_USER@agentic-coding.local"
    git config --global core.editor "vim"
    git config --global pull.rebase false
    git config --global push.default simple
    git config --global core.autocrlf input
    git config --global color.ui auto
fi

# Configure SSH for development
mkdir -p "$DEV_HOME/.ssh"
chmod 700 "$DEV_HOME/.ssh"
touch "$DEV_HOME/.ssh/config"
chmod 600 "$DEV_HOME/.ssh/config"

# Create development environment configuration
cat > "$DEV_HOME/.config/agentic-env.sh" << 'EOF'
#!/bin/bash
# Agentic Coding Environment Configuration

# Python environment
export PYTHONPATH="/opt/pipelines:/opt/tools:$PYTHONPATH"
export PYTHON_ENV="development"

# Node.js environment
export NODE_ENV="development"
export NPM_CONFIG_PREFIX="$HOME/.local"

# Development paths
export PATH="$HOME/.local/bin:/opt/pipelines/bin:/opt/tools/bin:$PATH"

# AI/ML environment variables
export TOKENIZERS_PARALLELISM=false
export TRANSFORMERS_CACHE="$HOME/.cache/transformers"
export HF_HOME="$HOME/.cache/huggingface"

# Development settings
export EDITOR="vim"
export PAGER="less"
export BROWSER="echo"
export TERM="xterm-256color"

# Logging
export LOG_LEVEL="info"
export DEBUG="false"

echo "Agentic coding environment loaded"
EOF

# Source the environment configuration in shell profiles
echo "source $DEV_HOME/.config/agentic-env.sh" >> "$DEV_HOME/.bashrc"
echo "source $DEV_HOME/.config/agentic-env.sh" >> "$DEV_HOME/.zshrc" 2>/dev/null || true

# Create vim configuration for development
cat > "$DEV_HOME/.vimrc" << 'EOF'
" Basic vim configuration for agentic development
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set ruler
set showcmd
set wildmenu
set laststatus=2
set encoding=utf-8
set fileencoding=utf-8
set backspace=indent,eol,start

" Enable syntax highlighting
syntax on
filetype plugin indent on

" Color scheme
colorscheme default
set background=dark

" Key mappings
nnoremap <C-n> :set number!<CR>
nnoremap <C-h> :set hlsearch!<CR>

" File type specific settings
autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType typescript setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType json setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 expandtab
EOF

# Create tmux configuration
cat > "$DEV_HOME/.tmux.conf" << 'EOF'
# Tmux configuration for agentic development

# Set prefix to Ctrl-a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Set default terminal
set -g default-terminal "screen-256color"

# Start windows and panes at 1
set -g base-index 1
setw -g pane-base-index 1

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes
bind | split-window -h
bind - split-window -v

# Move between panes
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
EOF

# Create development workspace structure
mkdir -p /workspace/projects
mkdir -p /workspace/experiments
mkdir -p /workspace/notebooks
mkdir -p /workspace/scripts
mkdir -p /workspace/configs

# Create useful development scripts
cat > "$DEV_HOME/.local/bin/agentic-status" << 'EOF'
#!/bin/bash
# Display agentic development environment status

echo "=== Agentic Coding Environment Status ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Working Directory: $(pwd)"
echo ""

echo "=== Runtime Versions ==="
echo "Python: $(python --version 2>&1)"
echo "Node.js: $(node --version 2>&1)"
echo "npm: $(npm --version 2>&1)"
echo "Git: $(git --version 2>&1)"
echo "Docker: $(docker --version 2>&1 || echo 'Docker not available')"
echo ""

echo "=== Environment Variables ==="
echo "PYTHON_ENV: $PYTHON_ENV"
echo "NODE_ENV: $NODE_ENV"
echo "LOG_LEVEL: $LOG_LEVEL"
echo ""

echo "=== Disk Usage ==="
df -h /workspace 2>/dev/null || echo "Workspace not mounted"
echo ""

echo "=== Active Processes ==="
ps aux | grep -E "(python|node|npm)" | grep -v grep | head -5
echo ""

echo "=== Pipeline Projects ==="
ls -la /opt/pipelines/ 2>/dev/null || echo "Pipeline projects not yet installed"
EOF

chmod +x "$DEV_HOME/.local/bin/agentic-status"

# Create project initialization script
cat > "$DEV_HOME/.local/bin/init-project" << 'EOF'
#!/bin/bash
# Initialize a new agentic development project

PROJECT_NAME="$1"
PROJECT_TYPE="${2:-mixed}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: init-project <project-name> [python|node|mixed]"
    exit 1
fi

PROJECT_DIR="/workspace/projects/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "Project $PROJECT_NAME already exists"
    exit 1
fi

echo "Creating project: $PROJECT_NAME (type: $PROJECT_TYPE)"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize Git
git init
echo "# $PROJECT_NAME" > README.md
echo "node_modules/" > .gitignore
echo "__pycache__/" >> .gitignore
echo ".env" >> .gitignore
echo "*.log" >> .gitignore

# Create project structure based on type
case "$PROJECT_TYPE" in
    "python")
        mkdir -p src tests docs
        echo "# Python Project: $PROJECT_NAME" >> README.md
        python -m venv venv
        echo "venv/" >> .gitignore
        ;;
    "node")
        mkdir -p src tests docs
        npm init -y --name "$PROJECT_NAME"
        echo "# Node.js Project: $PROJECT_NAME" >> README.md
        ;;
    "mixed")
        mkdir -p src/{python,typescript} tests docs scripts
        npm init -y --name "$PROJECT_NAME"
        python -m venv venv
        echo "venv/" >> .gitignore
        echo "# Mixed Project: $PROJECT_NAME" >> README.md
        echo "This project uses both Python and Node.js" >> README.md
        ;;
esac

# Initial commit
git add .
git commit -m "Initial project setup for $PROJECT_NAME"

echo "Project $PROJECT_NAME created successfully in $PROJECT_DIR"
echo "To get started: cd $PROJECT_DIR"
EOF

chmod +x "$DEV_HOME/.local/bin/init-project"

# Set proper ownership for newly created files only
if id "$DEV_USER" &>/dev/null; then
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.gitconfig" 2>/dev/null || true
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.config/agentic-env.sh" 2>/dev/null || true
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.vimrc" 2>/dev/null || true
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.tmux.conf" 2>/dev/null || true
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.local/bin/agentic-status" 2>/dev/null || true
    chown "$DEV_USER:$DEV_USER" "$DEV_HOME/.local/bin/init-project" 2>/dev/null || true
    echo "Ownership set for $DEV_USER user config files"
else
    echo "User $DEV_USER not found, skipping ownership changes"
fi

echo "Base Container Image integration completed successfully for user: $DEV_USER"
#!/bin/bash

# Base Container Image Integration Script
# This script replicates the essential configurations from the agentic_coding_flywheel_setup

set -e

echo "Configuring Base Container Image components..."

# Create essential directories
mkdir -p /opt/agentic-tools
mkdir -p /opt/configs/base
mkdir -p /home/developer/.config
mkdir -p /home/developer/.local/bin

# Configure Git with enhanced settings for agentic development
git config --global init.defaultBranch main
git config --global user.name "Agentic Developer"
git config --global user.email "developer@agentic-coding.local"
git config --global core.editor "vim"
git config --global pull.rebase false
git config --global push.default simple
git config --global core.autocrlf input
git config --global color.ui auto

# Configure SSH for development
mkdir -p /home/developer/.ssh
chmod 700 /home/developer/.ssh
touch /home/developer/.ssh/config
chmod 600 /home/developer/.ssh/config

# Create development environment configuration
cat > /home/developer/.config/agentic-env.sh << 'EOF'
#!/bin/bash
# Agentic Coding Environment Configuration

# Python environment
export PYTHONPATH="/opt/pipelines:/opt/tools:$PYTHONPATH"
export PYTHON_ENV="development"

# Node.js environment  
export NODE_ENV="development"
export NPM_CONFIG_PREFIX="/home/developer/.local"

# Development paths
export PATH="/home/developer/.local/bin:/opt/pipelines/bin:/opt/tools/bin:$PATH"

# AI/ML environment variables
export TOKENIZERS_PARALLELISM=false
export TRANSFORMERS_CACHE="/home/developer/.cache/transformers"
export HF_HOME="/home/developer/.cache/huggingface"

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
echo "source /home/developer/.config/agentic-env.sh" >> /home/developer/.bashrc
echo "source /home/developer/.config/agentic-env.sh" >> /home/developer/.zshrc 2>/dev/null || true

# Create vim configuration for development
cat > /home/developer/.vimrc << 'EOF'
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
cat > /home/developer/.tmux.conf << 'EOF'
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
cat > /home/developer/.local/bin/agentic-status << 'EOF'
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

chmod +x /home/developer/.local/bin/agentic-status

# Create project initialization script
cat > /home/developer/.local/bin/init-project << 'EOF'
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

chmod +x /home/developer/.local/bin/init-project

# Set proper ownership (only if developer user exists)
if id "developer" &>/dev/null; then
    chown -R developer:developer /home/developer 2>/dev/null || true
    chown -R developer:developer /workspace 2>/dev/null || true
    chown -R developer:developer /opt/configs 2>/dev/null || true
    echo "Ownership set for developer user"
else
    echo "Developer user not found, skipping ownership changes"
fi

echo "Base Container Image integration completed successfully"
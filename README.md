# Agentic Coding Pipeline Container

A comprehensive Docker container that includes the Base Container Image development environment and all multi-agent coding pipeline projects for autonomous agentic coding workflows.

## Overview

This container provides a complete, ready-to-use development environment that includes:

- **Base Container Image** - Foundational development environment with essential tools
- **Multi-Agent Pipeline Projects** - 7 cutting-edge agentic coding frameworks
- **Additional Development Tools** - 5 specialized tools for enhanced productivity
- **Optimized Configuration** - Pre-configured for immediate use

## Quick Start

### Prerequisites

- Docker 20.10+ or Docker Desktop
- 8GB+ RAM recommended
- 20GB+ free disk space

### Build the Container

```bash
# Clone this repository
git clone <repository-url>
cd ai_coding_pipeline

# Build the container
./build.sh

# Or build manually
docker build -t agentic-coding-pipeline:latest .
```

### Run the Container

```bash
# Using Docker Compose (recommended)
docker-compose up -d

# Or using Docker directly
docker run -it --privileged \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 9000:9000 \
  -v $(pwd)/workspace:/workspace \
  agentic-coding-pipeline:latest
```

### Access the Container

```bash
# Access running container
docker exec -it agentic-coding-container bash

# Check system status
agentic-status

# Create a new project
init-project my-project mixed
```

## Included Pipeline Projects

### 1. Kiro CLI
- **Location**: `/opt/pipelines/kiro`
- **Type**: Proprietary agent platform
- **Features**: Autonomous operation, context maintenance, learning
- **Start**: `/opt/pipelines/kiro/start-kiro.sh`
- **Config**: `/opt/configs/kiro/config.json`

### 2. Auto-Claude Framework
- **Location**: `/opt/pipelines/auto-claude`
- **Type**: Python-based multi-agent framework
- **Features**: Planning, building, validation agents
- **Start**: `/opt/pipelines/auto-claude/start-auto-claude.sh`
- **Config**: `/opt/configs/auto-claude/config.yaml`

### 3. Continuous-Claude
- **Location**: `/opt/pipelines/continuous-claude`
- **Type**: Node.js session continuity system
- **Features**: Token-efficient MCP execution, context management
- **Start**: `/opt/pipelines/continuous-claude/start-continuous-claude.sh`
- **Config**: `/opt/configs/continuous-claude/config.json`

### 4. Automaker Development Studio
- **Location**: `/opt/pipelines/automaker`
- **Type**: Python autonomous development studio
- **Features**: AI-powered development workflows, Docker integration
- **Start**: `/opt/pipelines/automaker/start-automaker.sh`
- **Config**: `/opt/configs/automaker/config.yaml`

### 5. InfiAgent (MLA)
- **Location**: `/opt/pipelines/infiagent`
- **Type**: Multi-Level Agent framework
- **Features**: Unlimited runtime, resource management, chaos prevention
- **Start**: `/opt/pipelines/infiagent/start-infiagent.sh`
- **Config**: `/opt/configs/infiagent/mla-config.yaml`

### 6. MAI-UI GUI Agent Models
- **Location**: `/opt/pipelines/mai-ui`
- **Type**: GUI agent foundation models
- **Features**: Screen understanding, UI interaction, visual reasoning
- **Start**: `/opt/pipelines/mai-ui/start-mai-ui.sh`
- **Config**: `/opt/configs/mai-ui/config.yaml`

### 7. Loki-Mode Autonomous System
- **Location**: `/opt/pipelines/loki-mode`
- **Type**: Multi-agent startup system
- **Features**: Autonomous multi-agent coordination, Claude skills
- **Start**: `/opt/pipelines/loki-mode/start-loki-mode.sh`
- **Config**: `/opt/configs/loki-mode/config.json`

## Additional Development Tools

### 1. KnowNote
- **Location**: `/opt/tools/knownote`
- **Description**: Local-first NotebookLM alternative
- **Features**: Private LLMs, full control, no Docker required
- **Start**: `/opt/tools/knownote/start-knownote.sh`

### 2. Vibium
- **Location**: `/opt/tools/vibium`
- **Description**: Browser automation without the drama
- **Features**: Playwright, Puppeteer, Selenium support
- **Start**: `/opt/tools/vibium/start-vibium.sh`

### 3. OpenTinker
- **Location**: `/opt/tools/opentinker`
- **Description**: Agentic Reinforcement Learning as a Service
- **Features**: Multiple RL algorithms, distributed training
- **Start**: `/opt/tools/opentinker/start-opentinker.sh`

### 4. ProxyPal
- **Location**: `/opt/tools/proxypal`
- **Description**: AI subscription proxy for coding tools
- **Features**: Claude, ChatGPT, Gemini, GitHub Copilot support
- **Start**: `/opt/tools/proxypal/start-proxypal.sh`

### 5. Claude Code Transcripts
- **Location**: `/opt/tools/claude-transcripts`
- **Description**: Tools for Claude code transcript analysis
- **Features**: Parsing, extraction, session analysis
- **Start**: `/opt/tools/claude-transcripts/start-claude-transcripts.sh`

## Environment Configuration

### Environment Variables

Set these environment variables for full functionality:

```bash
# AI API Keys
export ANTHROPIC_API_KEY="your-anthropic-key"
export OPENAI_API_KEY="your-openai-key"
export GOOGLE_API_KEY="your-google-key"

# Development Settings
export WORKSPACE_DIR="/workspace"
export LOG_LEVEL="info"
export DEBUG="false"
```

### Directory Structure

```
/workspace/          # Your development workspace
/opt/pipelines/      # Multi-agent pipeline projects
/opt/tools/          # Additional development tools
/opt/configs/        # Configuration files
/opt/logs/           # Log files
/home/developer/     # Developer user home directory
```

### Exposed Ports

- **3000**: General web development
- **8000**: Python/Django development
- **8080**: Alternative web port
- **9000**: Additional service port

## Usage Examples

### Starting a Pipeline Project

```bash
# Start Auto-Claude framework
/opt/pipelines/auto-claude/start-auto-claude.sh

# Start Continuous-Claude system
/opt/pipelines/continuous-claude/start-continuous-claude.sh

# Start Loki-Mode autonomous system
/opt/pipelines/loki-mode/start-loki-mode.sh
```

### Creating Projects

```bash
# Create a Python project
init-project my-python-app python

# Create a Node.js project
init-project my-node-app node

# Create a mixed project (Python + Node.js)
init-project my-full-stack mixed
```

### Using Development Tools

```bash
# Check system status
agentic-status

# Start KnowNote for document analysis
/opt/tools/knownote/start-knownote.sh

# Start browser automation with Vibium
/opt/tools/vibium/start-vibium.sh
```

## Configuration

### Customizing Pipeline Projects

Each pipeline project has its own configuration file:

```bash
# Edit Auto-Claude configuration
vim /opt/configs/auto-claude/config.yaml

# Edit Continuous-Claude configuration
vim /opt/configs/continuous-claude/config.json

# Edit InfiAgent configuration
vim /opt/configs/infiagent/mla-config.yaml
```

### Adding Custom Tools

```bash
# Add your own tools to /opt/tools/
mkdir /opt/tools/my-custom-tool

# Create configuration
mkdir /opt/configs/my-custom-tool

# Add startup script
cat > /opt/tools/my-custom-tool/start-my-tool.sh << 'EOF'
#!/bin/bash
echo "Starting my custom tool..."
EOF

chmod +x /opt/tools/my-custom-tool/start-my-tool.sh
```

## Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check Docker daemon
docker info

# Check image exists
docker images | grep agentic-coding-pipeline

# Rebuild if necessary
./build.sh
```

#### Permission Errors
```bash
# Fix workspace permissions
docker exec -it agentic-coding-container chown -R developer:developer /workspace

# Check user
docker exec -it agentic-coding-container whoami
```

#### API Key Issues
```bash
# Check environment variables
docker exec -it agentic-coding-container env | grep API_KEY

# Set API keys
docker exec -it agentic-coding-container bash -c 'export ANTHROPIC_API_KEY="your-key"'
```

#### Memory Issues
```bash
# Check available memory
docker exec -it agentic-coding-container free -h

# Increase Docker memory limit in Docker Desktop settings
# Recommended: 8GB+ for full functionality
```

#### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep :3000

# Use different ports
docker run -p 3001:3000 -p 8001:8000 agentic-coding-pipeline:latest
```

### Performance Optimization

#### For Better Performance
- Allocate 8GB+ RAM to Docker
- Use SSD storage for better I/O
- Enable Docker BuildKit for faster builds
- Use volume mounts for persistent data

#### For Smaller Image Size
- Remove unused pipeline projects from Dockerfile
- Use multi-stage builds (already implemented)
- Clean up package caches (already implemented)

### Logs and Debugging

```bash
# View container logs
docker logs agentic-coding-container

# View pipeline project logs
ls /opt/logs/

# Enable debug mode
export DEBUG="true"
export LOG_LEVEL="debug"
```

## Development

### Building from Source

```bash
# Clone repository
git clone <repository-url>
cd ai_coding_pipeline

# Build with custom arguments
docker build --build-arg USERNAME=myuser --build-arg USER_UID=1001 -t agentic-coding-pipeline:custom .

# Run tests
cd tests
pip install -r requirements.txt
pytest -v
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add your pipeline project or tool
4. Update documentation
5. Add tests
6. Submit a pull request

### Testing

```bash
# Run all tests
pytest tests/ -v

# Run specific test categories
pytest tests/test_base_container.py -v
pytest tests/test_pipeline_projects.py -v
pytest tests/test_additional_tools.py -v

# Run property-based tests
pytest tests/ -m property -v
```

## License

This project is open source. Individual pipeline projects and tools may have their own licenses.

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review logs in `/opt/logs/`
3. Check individual project documentation
4. Open an issue in the repository

## Acknowledgments

This container integrates the following open-source projects:

- [Kiro Autonomous Agent](https://kiro.dev/autonomous-agent/)
- [Auto-Claude](https://github.com/AndyMik90/Auto-Claude)
- [Continuous-Claude](https://github.com/parcadei/Continuous-Claude-v2)
- [Automaker](https://github.com/AutoMaker-Org/automaker)
- [InfiAgent](https://github.com/ChenglinPoly/infiAgent)
- [MAI-UI](https://github.com/Tongyi-MAI/MAI-UI)
- [Loki-Mode](https://github.com/asklokesh/claudeskill-loki-mode)
- [KnowNote](https://github.com/MrSibe/KnowNote)
- [Vibium](https://github.com/VibiumDev/vibium)
- [OpenTinker](https://github.com/open-tinker/OpenTinker)
- [ProxyPal](https://github.com/heyhuynhgiabuu/proxypal)
- [Claude Code Transcripts](https://github.com/simonw/claude-code-transcripts)

Special thanks to all the developers and maintainers of these projects for advancing the field of agentic coding.
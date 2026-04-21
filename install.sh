#!/usr/bin/env bash
# =============================================================================
# AIORCH — Interactive Docker Installer
# Usage: curl -fsSL https://aiorch.ai/install.sh | bash
# =============================================================================

set -euo pipefail

# --- ANSI Color Codes ---
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'

# --- Helper functions ---
ok()    { echo -e "  ${GREEN}[OK]${RESET}    $*"; }
warn()  { echo -e "  ${YELLOW}[WARN]${RESET}  $*"; }
err()   { echo -e "  ${RED}[ERROR]${RESET} $*"; }
info()  { echo -e "  ${CYAN}[INFO]${RESET}  $*"; }
step()  { echo -e "\n  ${BOLD}${BLUE}$*${RESET}"; }
ask()   { echo -en "  ${WHITE}$*${RESET}" ; }

# Get terminal width (default 60 if unavailable)
COLS=$(tput cols 2>/dev/null || echo 60)
[ "$COLS" -lt 50 ] && COLS=50

# Draw a colored horizontal rule
hr() {
    local char="${1:-─}"
    printf '  %s\n' "$(printf "%${COLS}s" | tr ' ' "$char")" | head -c $((COLS + 4))
    echo ""
}

# --- Full-width Banner ---
echo ""
echo -e "  ${BG_BLUE}${WHITE}${BOLD}$(printf "%-${COLS}s" "")${RESET}"
echo -e "  ${BG_BLUE}${WHITE}${BOLD}$(printf "%-${COLS}s" "   AIORCH — AI Code Orchestration")${RESET}"
echo -e "  ${BG_BLUE}${WHITE}${BOLD}$(printf "%-${COLS}s" "   https://aiorch.ai")${RESET}"
echo -e "  ${BG_BLUE}${WHITE}${BOLD}$(printf "%-${COLS}s" "")${RESET}"
echo ""

# =============================================================================
# Section 1: Prerequisites
# =============================================================================
step "Checking prerequisites..."
echo ""

# --- Check Docker ---
if ! command -v docker &>/dev/null; then
    err "Docker is required but not installed."
    echo ""
    echo -e "    Install Docker:"
    echo -e "      ${CYAN}curl -fsSL https://get.docker.com | sh${RESET}"
    echo ""
    echo -e "    After installing, run this script again."
    echo ""
    read -p "  Press Enter to exit..." < /dev/tty
    exit 1
fi
ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"

# --- Check Docker Compose ---
if ! docker compose version &>/dev/null 2>&1; then
    err "Docker Compose is required but not installed."
    echo -e "    Install: ${CYAN}apt install docker-compose-plugin${RESET}"
    read -p "  Press Enter to exit..." < /dev/tty
    exit 1
fi
ok "Docker Compose $(docker compose version --short)"

# --- Check Docker starts on boot ---
if command -v systemctl &>/dev/null; then
    if systemctl is-enabled docker &>/dev/null; then
        ok "Docker is enabled to start on boot"
    else
        warn "Docker is NOT enabled to start on boot."
        echo -e "    The orchestrator won't auto-start after a reboot."
        echo -e "    Fix: ${CYAN}sudo systemctl enable docker${RESET}"
    fi
fi

# =============================================================================
# Section 2: CLI Agent Selection
# =============================================================================
step "CLI Agent Setup"
echo ""
echo -e "  AIORCH can use CLI-based AI agents for code tasks."
echo -e "  Select which CLI agents to configure. Each detected on"
echo -e "  the host will be mounted into the container."
echo -e "  ${DIM}(API-based providers like OpenAI and Ollama are configured later in Settings.)${RESET}"
echo ""

# --- Detect / select Claude CLI ---
CLAUDE_CLI_PATH=""
CLAUDE_CONFIG_PATH=""
INSTALL_CLAUDE_CHOICE="n"

if command -v claude &>/dev/null; then
    CLAUDE_CLI_PATH="$(command -v claude)"
    ok "Claude CLI found: ${CLAUDE_CLI_PATH}"
    INSTALL_CLAUDE_CHOICE="y"
    if [ -d "${HOME}/.claude" ]; then
        CLAUDE_CONFIG_PATH="${HOME}/.claude"
    fi
else
    echo -en "  ${YELLOW}●${RESET} Claude CLI not found. "
    echo -e "${DIM}(Anthropic — Claude Opus, Sonnet, Haiku)${RESET}"
    echo ""
    echo -e "    Install Claude CLI:  ${CYAN}curl -fsSL https://claude.ai/install.sh | bash${RESET}"
    echo -e "    Then authenticate:   ${CYAN}claude${RESET}"
    echo ""
    read -p "  Would you like to install Claude CLI now? (y/N): " INSTALL_CLAUDE_NOW < /dev/tty
    if [ "${INSTALL_CLAUDE_NOW}" = "y" ] || [ "${INSTALL_CLAUDE_NOW}" = "Y" ]; then
        info "Installing Claude CLI..."
        if curl -fsSL https://claude.ai/install.sh | bash; then
            # Re-detect after installation
            export PATH="${HOME}/.claude/bin:${HOME}/.local/bin:${PATH}"
            if command -v claude &>/dev/null; then
                CLAUDE_CLI_PATH="$(command -v claude)"
                ok "Claude CLI installed: ${CLAUDE_CLI_PATH}"
                INSTALL_CLAUDE_CHOICE="y"
                echo ""
                info "Run ${CYAN}claude${RESET} after setup to authenticate."
            else
                warn "Claude CLI installer ran but binary not found in PATH."
                read -p "  Path to claude binary (or Enter to skip): " CLAUDE_CLI_PATH < /dev/tty
                if [ -n "${CLAUDE_CLI_PATH}" ]; then
                    if [ ! -f "${CLAUDE_CLI_PATH}" ]; then
                        err "File not found: ${CLAUDE_CLI_PATH}"
                        CLAUDE_CLI_PATH=""
                    else
                        INSTALL_CLAUDE_CHOICE="y"
                    fi
                fi
            fi
        else
            warn "Claude CLI installation failed. You can install it manually later."
        fi
    else
        read -p "  Path to claude binary (or Enter to skip): " CLAUDE_CLI_PATH < /dev/tty
        if [ -n "${CLAUDE_CLI_PATH}" ]; then
            if [ ! -f "${CLAUDE_CLI_PATH}" ]; then
                err "File not found: ${CLAUDE_CLI_PATH}"
                CLAUDE_CLI_PATH=""
            else
                INSTALL_CLAUDE_CHOICE="y"
            fi
        fi
    fi
    if [ -n "${CLAUDE_CLI_PATH}" ] && [ -d "${HOME}/.claude" ]; then
        CLAUDE_CONFIG_PATH="${HOME}/.claude"
    fi
fi
echo ""

# --- Detect / select Kimi CLI ---
KIMI_CLI_PATH=""
KIMI_CONFIG_PATH=""
INSTALL_KIMI_CHOICE="n"

if command -v kimi &>/dev/null; then
    KIMI_CLI_PATH="$(command -v kimi)"
    ok "Kimi CLI found: ${KIMI_CLI_PATH}"
    INSTALL_KIMI_CHOICE="y"
    if [ -d "${HOME}/.kimi" ]; then
        KIMI_CONFIG_PATH="${HOME}/.kimi"
    fi
else
    echo -en "  ${YELLOW}●${RESET} Kimi CLI not found. "
    echo -e "${DIM}(Moonshot AI — Kimi K2)${RESET}"
    echo ""
    echo -e "    Install Kimi CLI:    ${CYAN}pip install kimi-cli${RESET}"
    echo -e "    Then authenticate:   ${CYAN}kimi login${RESET}"
    echo ""
    read -p "  Would you like to install Kimi CLI now? (y/N): " INSTALL_KIMI_NOW < /dev/tty
    if [ "${INSTALL_KIMI_NOW}" = "y" ] || [ "${INSTALL_KIMI_NOW}" = "Y" ]; then
        info "Installing Kimi CLI..."
        if pip install kimi-cli 2>/dev/null || pip3 install kimi-cli 2>/dev/null; then
            if command -v kimi &>/dev/null; then
                KIMI_CLI_PATH="$(command -v kimi)"
                ok "Kimi CLI installed: ${KIMI_CLI_PATH}"
                INSTALL_KIMI_CHOICE="y"
                echo ""
                info "Run ${CYAN}kimi login${RESET} after setup to authenticate."
            else
                warn "Kimi CLI installed but binary not found in PATH."
                read -p "  Path to kimi binary (or Enter to skip): " KIMI_CLI_PATH < /dev/tty
                if [ -n "${KIMI_CLI_PATH}" ] && [ ! -f "${KIMI_CLI_PATH}" ]; then
                    err "File not found: ${KIMI_CLI_PATH}"
                    KIMI_CLI_PATH=""
                elif [ -n "${KIMI_CLI_PATH}" ]; then
                    INSTALL_KIMI_CHOICE="y"
                fi
            fi
        else
            warn "Kimi CLI installation failed. You can install it manually later."
        fi
    else
        read -p "  Path to kimi binary (or Enter to skip): " KIMI_CLI_PATH < /dev/tty
        if [ -n "${KIMI_CLI_PATH}" ]; then
            if [ ! -f "${KIMI_CLI_PATH}" ]; then
                err "File not found: ${KIMI_CLI_PATH}"
                KIMI_CLI_PATH=""
            else
                INSTALL_KIMI_CHOICE="y"
            fi
        fi
    fi
    if [ -n "${KIMI_CLI_PATH}" ] && [ -d "${HOME}/.kimi" ]; then
        KIMI_CONFIG_PATH="${HOME}/.kimi"
    fi
fi
echo ""

# --- Detect / select Codex CLI ---
CODEX_CLI_PATH=""
CODEX_CONFIG_PATH=""
INSTALL_CODEX_CHOICE="n"

if command -v codex &>/dev/null; then
    CODEX_CLI_PATH="$(command -v codex)"
    ok "Codex CLI found: ${CODEX_CLI_PATH}"
    INSTALL_CODEX_CHOICE="y"
    if [ -d "${HOME}/.codex" ]; then
        CODEX_CONFIG_PATH="${HOME}/.codex"
    fi
else
    echo -en "  ${YELLOW}●${RESET} Codex CLI not found. "
    echo -e "${DIM}(OpenAI — Codex)${RESET}"
    echo ""
    echo -e "    Install Codex CLI:   ${CYAN}npm install -g @openai/codex${RESET}"
    echo -e "    Then authenticate:   ${CYAN}codex login${RESET}"
    echo ""
    read -p "  Would you like to install Codex CLI now? (y/N): " INSTALL_CODEX_NOW < /dev/tty
    if [ "${INSTALL_CODEX_NOW}" = "y" ] || [ "${INSTALL_CODEX_NOW}" = "Y" ]; then
        if ! command -v npm &>/dev/null; then
            warn "npm not found. Install Node.js first, then run:"
            echo -e "      ${CYAN}npm install -g @openai/codex${RESET}"
        else
            info "Installing Codex CLI..."
            if npm install -g @openai/codex 2>/dev/null; then
                if command -v codex &>/dev/null; then
                    CODEX_CLI_PATH="$(command -v codex)"
                    ok "Codex CLI installed: ${CODEX_CLI_PATH}"
                    INSTALL_CODEX_CHOICE="y"
                    echo ""
                    info "Run ${CYAN}codex login${RESET} after setup to authenticate."
                else
                    warn "Codex CLI installed but binary not found in PATH."
                    read -p "  Path to codex binary (or Enter to skip): " CODEX_CLI_PATH < /dev/tty
                    if [ -n "${CODEX_CLI_PATH}" ] && [ ! -f "${CODEX_CLI_PATH}" ]; then
                        err "File not found: ${CODEX_CLI_PATH}"
                        CODEX_CLI_PATH=""
                    elif [ -n "${CODEX_CLI_PATH}" ]; then
                        INSTALL_CODEX_CHOICE="y"
                    fi
                fi
            else
                warn "Codex CLI installation failed. You can install it manually later."
            fi
        fi
    else
        read -p "  Path to codex binary (or Enter to skip): " CODEX_CLI_PATH < /dev/tty
        if [ -n "${CODEX_CLI_PATH}" ]; then
            if [ ! -f "${CODEX_CLI_PATH}" ]; then
                err "File not found: ${CODEX_CLI_PATH}"
                CODEX_CLI_PATH=""
            else
                INSTALL_CODEX_CHOICE="y"
            fi
        fi
    fi
    if [ -n "${CODEX_CLI_PATH}" ] && [ -d "${HOME}/.codex" ]; then
        CODEX_CONFIG_PATH="${HOME}/.codex"
    fi
fi

# --- CLI summary ---
echo ""
step "CLI Agent Summary"
echo ""
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Claude CLI  ${DIM}→ ${CLAUDE_CLI_PATH}${RESET}"
else
    echo -e "  ${DIM}○ Claude CLI  → skipped${RESET}"
fi
if [ -n "${KIMI_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Kimi CLI    ${DIM}→ ${KIMI_CLI_PATH}${RESET}"
else
    echo -e "  ${DIM}○ Kimi CLI    → skipped${RESET}"
fi
if [ -n "${CODEX_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Codex CLI   ${DIM}→ ${CODEX_CLI_PATH}${RESET}"
else
    echo -e "  ${DIM}○ Codex CLI   → skipped${RESET}"
fi
echo -e "  ${DIM}(API providers: OpenAI, Ollama — configure in Settings after install)${RESET}"

# =============================================================================
# Section 3: Installation Configuration
# =============================================================================
step "Installation Configuration"
echo ""

# --- Install directory ---
read -p "  Install directory [/opt/aiorch]: " INSTALL_DIR < /dev/tty
INSTALL_DIR=${INSTALL_DIR:-/opt/aiorch}

if [ -d "${INSTALL_DIR}" ] && [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    warn "Existing installation found at ${INSTALL_DIR}"
    read -p "  Overwrite configuration? (y/N): " OVERWRITE < /dev/tty
    if [ "${OVERWRITE}" != "y" ] && [ "${OVERWRITE}" != "Y" ]; then
        info "Aborting. Existing installation preserved."
        exit 0
    fi
fi

mkdir -p "${INSTALL_DIR}/data"

# --- Port ---
read -p "  Port [1230]: " PORT < /dev/tty
PORT=${PORT:-1230}

# --- License key ---
echo ""
read -sp "  License key (Enter for 14-day trial): " LICENSE_KEY < /dev/tty
echo ""

# --- License server URL ---
LICENSE_URL="https://license.aiorch.ai"
if [ -n "${LICENSE_KEY}" ]; then
    read -p "  License server URL [${LICENSE_URL}]: " CUSTOM_LICENSE_URL < /dev/tty
    LICENSE_URL=${CUSTOM_LICENSE_URL:-${LICENSE_URL}}
fi

# --- Docker image ---
REGISTRY="aiorch/orchestrator"
IMAGE_TAG="latest"
read -p "  Docker image [${REGISTRY}:${IMAGE_TAG}]: " CUSTOM_IMAGE < /dev/tty
if [ -n "${CUSTOM_IMAGE}" ]; then
    REGISTRY="${CUSTOM_IMAGE%%:*}"
    IMAGE_TAG="${CUSTOM_IMAGE##*:}"
    if [ "${IMAGE_TAG}" = "${REGISTRY}" ]; then
        IMAGE_TAG="latest"
    fi
fi

# --- Pull image ---
echo ""
info "Pulling image: ${CYAN}${REGISTRY}:${IMAGE_TAG}${RESET}"
docker pull "${REGISTRY}:${IMAGE_TAG}"

# --- Generate session secret ---
SESSION_SECRET=""
if command -v python3 &>/dev/null; then
    SESSION_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
elif command -v openssl &>/dev/null; then
    SESSION_SECRET=$(openssl rand -hex 32)
else
    SESSION_SECRET=$(head -c 32 /dev/urandom | xxd -p | tr -d '\n')
fi

# =============================================================================
# Section 4: Generate .env
# =============================================================================
step "Writing configuration..."
echo ""

cat > "${INSTALL_DIR}/.env" << ENVEOF
# AIORCH v3 — Generated by install.sh
# Modify values below as needed

# Server
ORCH_HOST=0.0.0.0
ORCH_PORT=${PORT}
ORCH_LOG_LEVEL=INFO

# Authentication (empty = no auth required)
ORCH_API_KEY=

# Paths (inside container)
ORCH_BASE_DIR=/opt/aiorch
ORCH_SESSIONS_DIR=/opt/aiorch/data/sessions
ORCH_PIPELINES_DIR=/opt/aiorch/data/pipelines
ORCH_DATA_DIR=/opt/aiorch/data

# Model defaults
ORCH_DEFAULT_MODEL=opus
ORCH_DEFAULT_PLANNING_MODEL=
ORCH_DEFAULT_REVIEW_MODEL=

# Provider API keys
ORCH_OPENAI_API_KEY=
ORCH_OLLAMA_BASE_URL=http://localhost:11434
ORCH_OPENAI_BASE_URL=https://api.openai.com/v1
ORCH_KIMI_API_KEY=

# GitHub
ORCH_GITHUB_TOKEN=

# License
ORCH_LICENSE_KEY=${LICENSE_KEY}
ORCH_LICENSE_URL=${LICENSE_URL}
ORCH_LICENSE_HEARTBEAT_INTERVAL=300
ORCH_LICENSE_GRACE_HOURS=24
ORCH_LICENSE_STALE_TIMEOUT_MINUTES=10

# Agent defaults
ORCH_MAX_PARALLEL_AGENTS=4
ORCH_MAX_REVIEW_ROUNDS=3
ORCH_MAX_AGENTS_PER_SESSION=10

# Polling intervals (seconds)
ORCH_POLL_INTERVAL=15
ORCH_PIPELINE_POLL_INTERVAL=20
ORCH_AUTO_START_POLL_INTERVAL=30
ORCH_ZOMBIE_RECOVERY_INTERVAL=60

# Settings page security
ORCH_SESSION_SECRET=${SESSION_SECRET}
ORCH_SETTINGS_SESSION_EXPIRY_MINUTES=30

# Tool-use loop settings (for OpenAI agent mode)
ORCH_MAX_TOOL_ITERATIONS=50
ORCH_TOOL_CMD_TIMEOUT=60
ORCH_TOOL_CMD_OUTPUT_CAP=10240
ORCH_TOOL_MAX_CONSECUTIVE_ERRORS=3
ORCH_TOOL_LOOP_TEMPERATURE=0.3

# Docker distribution
ORCH_DOCKER_REGISTRY=${REGISTRY}
ORCH_IMAGE_TAG=${IMAGE_TAG}
ENVEOF

chmod 600 "${INSTALL_DIR}/.env"
ok "Environment config → ${INSTALL_DIR}/.env"

# =============================================================================
# Section 5: Project Directories
# =============================================================================
echo ""
step "Project Directories"
echo ""
echo -e "  Agents need access to your code repos via volume mounts."
echo -e "  Default mounts: ${BOLD}/home${RESET}, ${BOLD}/opt${RESET}, ${BOLD}/tmp${RESET}"
echo ""
read -p "  Extra directories (comma-separated, or Enter to skip): " EXTRA_DIRS < /dev/tty

PROJECT_MOUNTS="      - /home:/home
      - /opt:/opt
      - /tmp:/tmp"

if [ -n "${EXTRA_DIRS}" ]; then
    IFS=',' read -ra DIRS <<< "${EXTRA_DIRS}"
    for d in "${DIRS[@]}"; do
        d="$(echo "${d}" | xargs)"
        if [ -n "${d}" ] && [ "${d}" != "/home" ] && [ "${d}" != "/opt" ] && [ "${d}" != "/tmp" ]; then
            PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${d}:${d}"
        fi
    done
fi

# =============================================================================
# Section 6: Generate docker-compose.yml
# =============================================================================

# Build CLI volume mounts dynamically
CLI_VOLUMES=""

add_cli_volume() {
    local mount_line="$1"
    if [ -n "${CLI_VOLUMES}" ]; then
        CLI_VOLUMES="${CLI_VOLUMES}
${mount_line}"
    else
        CLI_VOLUMES="      # CLI agent binaries and auth configs
${mount_line}"
    fi
}

# Claude CLI mounts
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    add_cli_volume "      - ${CLAUDE_CLI_PATH}:/usr/local/bin/claude:ro"
fi
if [ -n "${CLAUDE_CONFIG_PATH}" ]; then
    add_cli_volume "      - ${CLAUDE_CONFIG_PATH}:/root/.claude:ro"
fi

# Kimi CLI mounts
if [ -n "${KIMI_CLI_PATH}" ]; then
    add_cli_volume "      - ${KIMI_CLI_PATH}:/usr/local/bin/kimi:ro"
fi
if [ -n "${KIMI_CONFIG_PATH}" ]; then
    add_cli_volume "      - ${KIMI_CONFIG_PATH}:/root/.kimi:ro"
fi

# Codex CLI mounts
if [ -n "${CODEX_CLI_PATH}" ]; then
    add_cli_volume "      - ${CODEX_CLI_PATH}:/usr/local/bin/codex:ro"
fi
if [ -n "${CODEX_CONFIG_PATH}" ]; then
    add_cli_volume "      - ${CODEX_CONFIG_PATH}:/root/.codex:ro"
fi

cat > "${INSTALL_DIR}/docker-compose.yml" << DEOF
services:
  orchestrator:
    image: ${REGISTRY}:${IMAGE_TAG}
    ports:
      - "${PORT}:${PORT}"
    volumes:
      # Persistent data
      - ./data:/opt/aiorch/data
      # Compose project dir — needed for self-restart when adding project dirs
      - .:/opt/aiorch/compose
      # Project directories — agents access your code through these mounts
${PROJECT_MOUNTS}
${CLI_VOLUMES}
    env_file:
      - .env
    environment:
      - ORCH_BASE_DIR=/app
      - ORCH_SESSIONS_DIR=/opt/aiorch/data/sessions
      - ORCH_PIPELINES_DIR=/opt/aiorch/data/pipelines
      - ORCH_DATA_DIR=/opt/aiorch/data
      - PYTHONPATH=/app
      - DOCKER_HOST=tcp://docker-proxy:2375
    depends_on:
      docker-proxy:
        condition: service_started
    restart: unless-stopped
    # Runtime security hardening
    read_only: true
    tmpfs:
      - /tmp:size=256M
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${PORT}/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  docker-proxy:
    image: tecnativa/docker-socket-proxy:0.3
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      CONTAINERS: 1
      SERVICES: 1
      TASKS: 1
      POST: 1
      AUTH: 0
      SECRETS: 0
      NETWORKS: 0
      VOLUMES: 0
      EXEC: 0
      IMAGES: 0
      SWARM: 0
      NODES: 0
      PLUGINS: 0
      BUILD: 0
      COMMIT: 0
      CONFIGS: 0
      DISTRIBUTION: 0
      SYSTEM: 0
    read_only: true
    tmpfs:
      - /run
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:2375/_ping || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
DEOF

ok "Docker Compose config → ${INSTALL_DIR}/docker-compose.yml"

# =============================================================================
# Section 7: Start
# =============================================================================
echo ""
step "Starting AIORCH..."
cd "${INSTALL_DIR}"
docker compose up -d

# =============================================================================
# Section 8: Post-install summary
# =============================================================================
echo ""
echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}$(printf "%-${COLS}s" "")${RESET}"
echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}$(printf "%-${COLS}s" "   ✓ AIORCH is running!")${RESET}"
echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}$(printf "%-${COLS}s" "")${RESET}"
echo ""
echo -e "  ${BOLD}Dashboard${RESET}    http://localhost:${PORT}"
echo -e "  ${BOLD}Data${RESET}         ${INSTALL_DIR}/data"
echo -e "  ${BOLD}Config${RESET}       ${INSTALL_DIR}/.env"
echo ""
echo -e "  ${BOLD}First step:${RESET}  Visit ${CYAN}/settings${RESET} to set your"
echo -e "               master password and configure API keys."
echo ""

# CLI status in post-install
CLI_CONFIGURED=0
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Claude CLI mounted — run ${CYAN}claude${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ -n "${KIMI_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Kimi CLI mounted   — run ${CYAN}kimi login${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ -n "${CODEX_CLI_PATH}" ]; then
    echo -e "  ${GREEN}✓${RESET} Codex CLI mounted  — run ${CYAN}codex login${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ ${CLI_CONFIGURED} -eq 0 ]; then
    warn "No CLI agents configured."
    echo -e "    Install any CLI agent on the host, then re-run the installer"
    echo -e "    or manually update ${CYAN}${INSTALL_DIR}/docker-compose.yml${RESET}"
fi

echo ""
if [ -n "${LICENSE_KEY}" ]; then
    echo -e "  ${GREEN}●${RESET} License: configured"
else
    echo -e "  ${YELLOW}●${RESET} License: ${BOLD}14-day trial${RESET} active"
fi

if command -v systemctl &>/dev/null && ! systemctl is-enabled docker &>/dev/null; then
    echo ""
    warn "Docker won't start on boot."
    echo -e "    Run: ${CYAN}sudo systemctl enable docker${RESET}"
fi

echo ""
echo -e "  ${BOLD}Manage:${RESET}"
echo -e "    ${CYAN}cd ${INSTALL_DIR}${RESET}"
echo -e "    ${DIM}docker compose logs -f${RESET}                       ${DIM}# View logs${RESET}"
echo -e "    ${DIM}docker compose restart${RESET}                       ${DIM}# Restart${RESET}"
echo -e "    ${DIM}docker compose down${RESET}                          ${DIM}# Stop${RESET}"
echo -e "    ${DIM}docker compose pull && docker compose up -d${RESET}  ${DIM}# Update${RESET}"
echo ""

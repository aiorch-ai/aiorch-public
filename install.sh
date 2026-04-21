#!/usr/bin/env bash
# =============================================================================
# AIORCH — Interactive Docker Installer
# Usage: curl -fsSL https://aiorch.ai/install.sh | bash
# =============================================================================

set -euo pipefail

# --- Brand palette (aligned with aiorch.ai) ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Primary accent ~ #00ff87
GREEN='\033[38;5;48m'
GREEN_BOLD='\033[1;38;5;48m'

# Negative / warning
ORANGE='\033[38;5;208m'
YELLOW='\033[38;5;214m'
RED='\033[38;5;203m'

# Utility
CYAN='\033[38;5;87m'
WHITE='\033[1;37m'
MUTED='\033[38;5;242m'    # ~ #5a5a70
MUTED2='\033[38;5;238m'   # ~ #3a3a50

# NO_COLOR / non-TTY fallback — disable everything if output isn't a color terminal
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RESET= BOLD= DIM= GREEN= GREEN_BOLD= ORANGE= YELLOW= RED= CYAN= WHITE= MUTED= MUTED2=
fi

# Get terminal width via /dev/tty (works even when piped through curl | bash)
COLS=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" ] && COLS=80
[ "$COLS" -lt 50 ] && COLS=50

# --- Helper functions ---
ok()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()  { echo -e "  ${YELLOW}⚡${RESET}  $*"; }
err()   { echo -e "  ${RED}✗${RESET}  $*"; }
info()  { echo -e "  ${CYAN}◆${RESET}  $*"; }
skip()  { echo -e "  ${MUTED}○  $*${RESET}"; }
next()  { echo -e "  ${GREEN}→${RESET}  $*"; }
ask()   { echo -en "  ${WHITE}$*${RESET}"; }

STEP_COUNTER=0
step() {
    STEP_COUNTER=$((STEP_COUNTER + 1))
    local num
    num=$(printf "%02d" "$STEP_COUNTER")
    local label
    label="$(echo "$*" | tr '[:lower:]' '[:upper:]')"
    local rule_width=$(( COLS > 100 ? 100 : COLS - 4 ))
    [ "$rule_width" -lt 20 ] && rule_width=20
    local rule
    rule=$(printf '─%.0s' $(seq 1 "$rule_width"))
    echo ""
    echo -e "${MUTED2}${rule}${RESET}"
    echo -e "  ${GREEN}${num}${RESET}  ${BOLD}${WHITE}${label}${RESET}"
    echo ""
}

# --- Top marker — mirrors the nav bar on aiorch.ai ---
echo ""
echo -e "  ${GREEN}●${RESET}  ${BOLD}${WHITE}AIORCH${RESET}  ${MUTED}installer${RESET}"
echo ""

# --- ASCII wordmark, brand green, no background ---
echo -e "${GREEN_BOLD}     █████╗ ██╗ ██████╗ ██████╗  ██████╗██╗  ██╗${RESET}"
echo -e "${GREEN_BOLD}    ██╔══██╗██║██╔═══██╗██╔══██╗██╔════╝██║  ██║${RESET}"
echo -e "${GREEN_BOLD}    ███████║██║██║   ██║██████╔╝██║     ███████║${RESET}"
echo -e "${GREEN_BOLD}    ██╔══██║██║██║   ██║██╔══██╗██║     ██╔══██║${RESET}"
echo -e "${GREEN_BOLD}    ██║  ██║██║╚██████╔╝██║  ██║╚██████╗██║  ██║${RESET}"
echo -e "${GREEN_BOLD}    ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝${RESET}"
echo ""
echo -e "    ${MUTED}MULTI-AGENT CODE ORCHESTRATION · BYOK · NO TOKEN MARKUP${RESET}"
echo -e "    ${DIM}${WHITE}Wake up to a PR you can actually merge${RESET}"
echo -e "    ${DIM}${GREEN}https://aiorch.ai${RESET}"
echo ""

# =============================================================================
# Section 1: Prerequisites
# =============================================================================
step "Prerequisites"

# --- Check Docker ---
if ! command -v docker &>/dev/null; then
    err "Docker is required but not installed."
    echo ""
    echo -e "    Install Docker:"
    echo -e "      ${CYAN}curl -fsSL https://get.docker.com | sh${RESET}"
    echo ""
    echo -e "    After installing, run this script again."
    echo ""
    read -p "$(echo -e "  ${MUTED}Press Enter to exit…${RESET}")" < /dev/tty
    exit 1
fi
ok "Docker ${DIM}$(docker --version | grep -oP '\d+\.\d+\.\d+')${RESET}"

# --- Check Docker Compose ---
if ! docker compose version &>/dev/null 2>&1; then
    err "Docker Compose is required but not installed."
    echo -e "    Install: ${CYAN}apt install docker-compose-plugin${RESET}"
    read -p "$(echo -e "  ${MUTED}Press Enter to exit…${RESET}")" < /dev/tty
    exit 1
fi
ok "Docker Compose ${DIM}$(docker compose version --short)${RESET}"

# --- Check Docker starts on boot ---
if command -v systemctl &>/dev/null; then
    if systemctl is-enabled docker &>/dev/null; then
        ok "Docker is enabled to start on boot"
    else
        warn "Docker is NOT enabled to start on boot."
        echo -e "      ${DIM}The orchestrator won't auto-start after a reboot.${RESET}"
        echo -e "      ${DIM}Fix: ${CYAN}sudo systemctl enable docker${RESET}"
    fi
fi

# =============================================================================
# Section 2: CLI Agent Setup
# =============================================================================
step "CLI Agent Setup"
echo -e "  AIORCH can use CLI-based AI agents for code tasks."
echo -e "  Select which CLI agents to configure. Each detected on"
echo -e "  the host will be mounted into the container."
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
    echo -e "  ${MUTED}○${RESET}  Claude CLI  ${DIM}(Anthropic — Claude Opus, Sonnet, Haiku)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}curl -fsSL https://claude.ai/install.sh | bash${RESET}"
    echo -e "      Authenticate:  ${CYAN}claude${RESET}"
    echo ""
    read -p "$(echo -e "  ${GREEN}→${RESET}  Install Claude CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_CLAUDE_NOW < /dev/tty
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
                read -p "$(echo -e "  ${GREEN}→${RESET}  Path to claude binary ${MUTED}(or Enter to skip)${RESET}: ")" CLAUDE_CLI_PATH < /dev/tty
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
        read -p "$(echo -e "  ${GREEN}→${RESET}  Path to claude binary ${MUTED}(or Enter to skip)${RESET}: ")" CLAUDE_CLI_PATH < /dev/tty
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
    echo -e "  ${MUTED}○${RESET}  Kimi CLI  ${DIM}(Moonshot AI — Kimi K2)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}pip install kimi-cli${RESET}"
    echo -e "      Authenticate:  ${CYAN}kimi login${RESET}"
    echo ""
    read -p "$(echo -e "  ${GREEN}→${RESET}  Install Kimi CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_KIMI_NOW < /dev/tty
    if [ "${INSTALL_KIMI_NOW}" = "y" ] || [ "${INSTALL_KIMI_NOW}" = "Y" ]; then
        # Ensure pip is available
        if ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
            warn "pip not found — Python package manager is required for Kimi CLI."
            if command -v apt-get &>/dev/null; then
                info "Installing python3-pip via apt..."
                if apt-get update -qq && apt-get install -y -qq python3-pip >/dev/null 2>&1; then
                    ok "python3-pip installed"
                else
                    err "Failed to install python3-pip. Install manually:"
                    echo -e "      ${CYAN}apt-get install -y python3-pip${RESET}"
                fi
            elif command -v dnf &>/dev/null; then
                info "Installing python3-pip via dnf..."
                if dnf install -y -q python3-pip >/dev/null 2>&1; then
                    ok "python3-pip installed"
                else
                    err "Failed to install python3-pip. Install manually:"
                    echo -e "      ${CYAN}dnf install -y python3-pip${RESET}"
                fi
            elif command -v yum &>/dev/null; then
                info "Installing python3-pip via yum..."
                if yum install -y -q python3-pip >/dev/null 2>&1; then
                    ok "python3-pip installed"
                else
                    err "Failed to install python3-pip. Install manually:"
                    echo -e "      ${CYAN}yum install -y python3-pip${RESET}"
                fi
            else
                err "Could not detect package manager. Install pip manually, then re-run."
            fi
        fi
        if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
            info "Installing Kimi CLI..."
            if pip3 install kimi-cli 2>/dev/null || pip install kimi-cli 2>/dev/null; then
                if command -v kimi &>/dev/null; then
                    KIMI_CLI_PATH="$(command -v kimi)"
                    ok "Kimi CLI installed: ${KIMI_CLI_PATH}"
                    INSTALL_KIMI_CHOICE="y"
                    echo ""
                    info "Run ${CYAN}kimi login${RESET} after setup to authenticate."
                else
                    warn "Kimi CLI installed but binary not found in PATH."
                    read -p "$(echo -e "  ${GREEN}→${RESET}  Path to kimi binary ${MUTED}(or Enter to skip)${RESET}: ")" KIMI_CLI_PATH < /dev/tty
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
        fi
    else
        read -p "$(echo -e "  ${GREEN}→${RESET}  Path to kimi binary ${MUTED}(or Enter to skip)${RESET}: ")" KIMI_CLI_PATH < /dev/tty
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
    echo -e "  ${MUTED}○${RESET}  Codex CLI  ${DIM}(OpenAI — Codex)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}npm install -g @openai/codex${RESET}"
    echo -e "      Authenticate:  ${CYAN}codex login${RESET}"
    echo ""
    read -p "$(echo -e "  ${GREEN}→${RESET}  Install Codex CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_CODEX_NOW < /dev/tty
    if [ "${INSTALL_CODEX_NOW}" = "y" ] || [ "${INSTALL_CODEX_NOW}" = "Y" ]; then
        # Ensure npm is available
        if ! command -v npm &>/dev/null; then
            warn "npm not found — Node.js is required for Codex CLI."
            if command -v apt-get &>/dev/null; then
                info "Installing Node.js via NodeSource..."
                if curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1 \
                   && apt-get install -y -qq nodejs >/dev/null 2>&1; then
                    ok "Node.js $(node --version 2>/dev/null) installed"
                else
                    err "Failed to install Node.js. Install manually:"
                    echo -e "      ${CYAN}curl -fsSL https://deb.nodesource.com/setup_22.x | bash -${RESET}"
                    echo -e "      ${CYAN}apt-get install -y nodejs${RESET}"
                fi
            elif command -v dnf &>/dev/null; then
                info "Installing Node.js via dnf..."
                if dnf install -y -q nodejs npm >/dev/null 2>&1; then
                    ok "Node.js $(node --version 2>/dev/null) installed"
                else
                    err "Failed to install Node.js. Install manually:"
                    echo -e "      ${CYAN}dnf install -y nodejs npm${RESET}"
                fi
            elif command -v yum &>/dev/null; then
                info "Installing Node.js via yum..."
                if yum install -y -q nodejs npm >/dev/null 2>&1; then
                    ok "Node.js $(node --version 2>/dev/null) installed"
                else
                    err "Failed to install Node.js. Install manually:"
                    echo -e "      ${CYAN}yum install -y nodejs npm${RESET}"
                fi
            else
                err "Could not detect package manager. Install Node.js manually, then re-run."
            fi
        fi
        if command -v npm &>/dev/null; then
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
                    read -p "$(echo -e "  ${GREEN}→${RESET}  Path to codex binary ${MUTED}(or Enter to skip)${RESET}: ")" CODEX_CLI_PATH < /dev/tty
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
        read -p "$(echo -e "  ${GREEN}→${RESET}  Path to codex binary ${MUTED}(or Enter to skip)${RESET}: ")" CODEX_CLI_PATH < /dev/tty
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
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    ok "Claude CLI   ${DIM}→ ${CLAUDE_CLI_PATH}${RESET}"
else
    skip "Claude CLI   → skipped"
fi
if [ -n "${KIMI_CLI_PATH}" ]; then
    ok "Kimi CLI     ${DIM}→ ${KIMI_CLI_PATH}${RESET}"
else
    skip "Kimi CLI     → skipped"
fi
if [ -n "${CODEX_CLI_PATH}" ]; then
    ok "Codex CLI    ${DIM}→ ${CODEX_CLI_PATH}${RESET}"
else
    skip "Codex CLI    → skipped"
fi
echo -e "  ${DIM}Other providers (OpenAI, Gemini, Ollama) — configure in Settings.${RESET} ${GREEN}BYOK, zero markup.${RESET}"

# =============================================================================
# Section 3: Installation Configuration
# =============================================================================
step "Installation Configuration"

# --- Install directory ---
read -p "$(echo -e "  ${GREEN}→${RESET}  Install directory ${MUTED}[/opt/aiorch]${RESET}: ")" INSTALL_DIR < /dev/tty
INSTALL_DIR=${INSTALL_DIR:-/opt/aiorch}

if [ -d "${INSTALL_DIR}" ] && [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    warn "Existing installation found at ${INSTALL_DIR}"
    read -p "$(echo -e "  ${GREEN}→${RESET}  Overwrite configuration? ${MUTED}(y/N)${RESET}: ")" OVERWRITE < /dev/tty
    if [ "${OVERWRITE}" != "y" ] && [ "${OVERWRITE}" != "Y" ]; then
        info "Aborting. Existing installation preserved."
        exit 0
    fi
fi

mkdir -p "${INSTALL_DIR}/data"

# --- Port ---
read -p "$(echo -e "  ${GREEN}→${RESET}  Port ${MUTED}[1230]${RESET}: ")" PORT < /dev/tty
PORT=${PORT:-1230}

# --- License key ---
echo ""
read -sp "$(echo -e "  ${GREEN}→${RESET}  License key ${MUTED}(Enter for 14-day trial)${RESET}: ")" LICENSE_KEY < /dev/tty
echo ""

# --- License server URL ---
LICENSE_URL="https://license.aiorch.ai"
if [ -n "${LICENSE_KEY}" ]; then
    read -p "$(echo -e "  ${GREEN}→${RESET}  License server URL ${MUTED}[${LICENSE_URL}]${RESET}: ")" CUSTOM_LICENSE_URL < /dev/tty
    LICENSE_URL=${CUSTOM_LICENSE_URL:-${LICENSE_URL}}
fi

# --- Docker image ---
REGISTRY="aiorch/orchestrator"
IMAGE_TAG="latest"
read -p "$(echo -e "  ${GREEN}→${RESET}  Docker image ${MUTED}[${REGISTRY}:${IMAGE_TAG}]${RESET}: ")" CUSTOM_IMAGE < /dev/tty
if [ -n "${CUSTOM_IMAGE}" ]; then
    REGISTRY="${CUSTOM_IMAGE%%:*}"
    IMAGE_TAG="${CUSTOM_IMAGE##*:}"
    if [ "${IMAGE_TAG}" = "${REGISTRY}" ]; then
        IMAGE_TAG="latest"
    fi
fi

# --- Pull image ---
echo ""
info "Pulling image ${GREEN}→${RESET} ${CYAN}${REGISTRY}:${IMAGE_TAG}${RESET}"
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
step "Writing configuration"

cat > "${INSTALL_DIR}/.env" << ENVEOF
# AIORCH · Generated by install.sh
# Multi-agent code orchestration · BYOK · No token markup
# Your keys. Your cost. Zero middleman.

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

# Provider API keys — BYOK, you pay providers directly at your negotiated rate
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
step "Project Directories"
echo -e "  Agents need access to your code repos via volume mounts."
echo -e "  Default mounts: ${BOLD}/home${RESET}, ${BOLD}/opt${RESET}"
echo -e "  ${DIM}(Container has its own /tmp via tmpfs — host /tmp not mounted.)${RESET}"
echo ""
read -p "$(echo -e "  ${GREEN}→${RESET}  Extra directories ${MUTED}(comma-separated, or Enter to skip)${RESET}: ")" EXTRA_DIRS < /dev/tty

PROJECT_MOUNTS="      - /home:/home
      - /opt:/opt"

if [ -n "${EXTRA_DIRS}" ]; then
    IFS=',' read -ra DIRS <<< "${EXTRA_DIRS}"
    for d in "${DIRS[@]}"; do
        d="$(echo "${d}" | xargs)"
        if [ -n "${d}" ] && [ "${d}" != "/home" ] && [ "${d}" != "/opt" ]; then
            PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${d}:${d}"
        fi
    done
fi

# =============================================================================
# Section 6: Generate docker-compose.yml
# =============================================================================
step "Docker Compose"

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
step "Starting AIORCH"
cd "${INSTALL_DIR}"
docker compose up -d

# =============================================================================
# Section 8: Post-install summary
# =============================================================================
step "Summary"

_rw=$(( COLS > 100 ? 100 : COLS - 4 ))
[ "$_rw" -lt 20 ] && _rw=20
rule=$(printf '─%.0s' $(seq 1 "$_rw"))
echo -e "${GREEN}${rule}${RESET}"
echo -e "  ${GREEN}●${RESET}  ${BOLD}${WHITE}AIORCH IS RUNNING${RESET}   ${MUTED}first PR in ~15 min${RESET}"
echo -e "${GREEN}${rule}${RESET}"
echo ""
echo -e "  ${BOLD}Dashboard${RESET}   ${GREEN}http://localhost:${PORT}${RESET}"
echo -e "  ${BOLD}Data${RESET}        ${MUTED}${INSTALL_DIR}/data${RESET}"
echo -e "  ${BOLD}Config${RESET}      ${MUTED}${INSTALL_DIR}/.env${RESET}"
echo ""
next "${BOLD}Next:${RESET} visit ${CYAN}/settings${RESET} — set master password and configure API keys."
echo -e "      ${DIM}Your keys. Your cost. Zero middleman.${RESET}"
echo ""

# --- CLI status ---
CLI_CONFIGURED=0
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    next "Claude CLI mounted — run ${CYAN}claude${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ -n "${KIMI_CLI_PATH}" ]; then
    next "Kimi CLI mounted   — run ${CYAN}kimi login${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ -n "${CODEX_CLI_PATH}" ]; then
    next "Codex CLI mounted  — run ${CYAN}codex login${RESET} on host to authenticate"
    CLI_CONFIGURED=1
fi
if [ ${CLI_CONFIGURED} -eq 0 ]; then
    skip "No CLI agents configured"
    echo -e "      ${DIM}Install any CLI on the host and re-run, or edit ${INSTALL_DIR}/docker-compose.yml${RESET}"
fi

echo ""

# --- License status ---
if [ -n "${LICENSE_KEY}" ]; then
    echo -e "  ${GREEN}●${RESET}  License: ${BOLD}configured${RESET}"
else
    echo -e "  ${YELLOW}●${RESET}  License: ${BOLD}14-day trial${RESET} active"
fi

# --- Docker autostart warning ---
if command -v systemctl &>/dev/null && ! systemctl is-enabled docker &>/dev/null; then
    echo ""
    warn "Docker won't start on boot."
    echo -e "      ${DIM}Run: ${CYAN}sudo systemctl enable docker${RESET}"
fi

# --- Manage commands ---
echo ""
echo -e "  ${BOLD}MANAGE${RESET}   ${MUTED}cd ${INSTALL_DIR}${RESET}"
echo -e "    ${DIM}docker compose logs -f${RESET}                        ${MUTED}# view logs${RESET}"
echo -e "    ${DIM}docker compose restart${RESET}                        ${MUTED}# restart${RESET}"
echo -e "    ${DIM}docker compose down${RESET}                           ${MUTED}# stop${RESET}"
echo -e "    ${DIM}docker compose pull && docker compose up -d${RESET}   ${MUTED}# update${RESET}"
echo ""

#!/usr/bin/env bash
# =============================================================================
# AIORCH — Interactive Docker Installer
# Usage: curl -fsSL https://aiorch.ai/install.sh | bash
# =============================================================================

set -euo pipefail

# Reset CWD — when run via curl|bash from a deleted/stale directory,
# bash inherits an invalid CWD that breaks nested installers and docker compose.
cd /tmp 2>/dev/null || cd /

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

# --- Helper functions ---
ok()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()  { echo -e "  ${YELLOW}⚡${RESET}  $*"; }
err()   { echo -e "  ${RED}✗${RESET}  $*"; }
info()  { echo -e "  ${CYAN}◆${RESET}  $*"; }
skip()  { echo -e "  ${MUTED}○  $*${RESET}"; }
next()  { echo -e "  ${GREEN}→${RESET}  $*"; }
ask()   { echo -en "  ${WHITE}$*${RESET}"; }

# --- Verify /dev/tty is openable BEFORE any other check that touches it ---
# install.sh reads from /dev/tty for prompts so it can stay interactive when
# piped via `curl ... | bash`. Some invocation patterns strip the controlling
# terminal (`su - user -c '...'`, ssh without -t, cron, systemd ExecStart);
# in those cases the prompts would die with a cryptic
# "/dev/tty: No such device or address" mid-script. Detect that up front and
# explain the fix.
#
# The brace-block wrapper around the redirect is what swallows bash's
# redirect-failure stderr — `2>/dev/null` on the colon command alone wouldn't
# catch it, because bash prints the redirect error before the command's own
# stderr is set up.
if ! { : < /dev/tty; } 2>/dev/null; then
    echo ""
    err "Cannot read from /dev/tty — no controlling terminal."
    echo ""
    echo -e "    ${DIM}The installer needs an interactive terminal for prompts."
    echo -e "    Some shell invocations strip the controlling tty:${RESET}"
    echo ""
    echo -e "      ${CYAN}su - <user> -c '...'${RESET}     ${DIM}→ use ${CYAN}sudo -iu <user> --${RESET}${DIM} instead${RESET}"
    echo -e "      ${CYAN}ssh host '...'${RESET}            ${DIM}→ add ${CYAN}-t${RESET}${DIM}: ${CYAN}ssh -t host '...'${RESET}"
    echo -e "      ${CYAN}cron${RESET}, ${CYAN}systemd ExecStart${RESET}     ${DIM}→ not supported (interactive only)${RESET}"
    echo ""
    exit 1
fi

# Get terminal width via /dev/tty (works when piped via curl|bash). Safe to
# touch /dev/tty here — the pre-flight above guaranteed it's openable.
COLS=$({ stty size </dev/tty | cut -d' ' -f2; } 2>/dev/null)
[ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null || true)
[ -z "$COLS" ] && COLS=80
[ "$COLS" -lt 50 ] && COLS=50

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

# --- Refuse to run as root ---
# AIORCH executes AI-generated code with the privileges of the host user.
# Running as root would give those agents read access to SSH keys, the
# package manager, /etc, every other user's home, and so on. The container
# runtime does not protect against this — entrypoint.sh runs as the host
# UID via setpriv, so root install ⇒ container processes run as root.
if [ "$(id -u)" = "0" ]; then
    err "Running this installer as root is not supported."
    echo ""
    echo -e "    ${DIM}AIORCH runs AI agents that execute arbitrary code with"
    echo -e "    the same privileges as the host user. As root, those agents"
    echo -e "    could read SSH keys, modify system files, install packages,"
    echo -e "    and access every other user's data on this machine. The"
    echo -e "    container runtime does not isolate against this — it runs"
    echo -e "    as your host UID, so root install ⇒ root container.${RESET}"
    echo ""
    # Detect whether Docker is already installed so the remediation steps
    # are presented in the correct order. On a fresh VM the user typically
    # has neither Docker nor the docker group yet — `usermod -aG docker`
    # fails until Docker has been installed, so the install step must come
    # first.
    # Detect existing non-root candidates so we can render a copy-paste-ready
    # command for the user's actual situation rather than a generic placeholder.
    _detected_user=""           # set when we have a clear single best guess
    _candidate_users=""         # whitespace-separated list of plausible users
    _candidate_in_docker=""     # whitespace-separated subset that's in docker grp

    # Signal #1: came in via sudo. SUDO_USER is the original user — by far
    # the most reliable hint about whose box this actually is.
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ] && id "${SUDO_USER}" &>/dev/null; then
        _detected_user="${SUDO_USER}"
    fi

    # Signal #2: enumerate regular users (UID >= 1000, < 65534, real shell).
    # nobody is UID 65534 on most distros and is excluded.
    while IFS=: read -r _u _ _uid _ _ _home _shell; do
        case "${_shell}" in
            */bash|*/zsh|*/sh|*/fish|*/dash) ;;
            *) continue ;;
        esac
        [ "${_uid}" -ge 1000 ] && [ "${_uid}" -lt 65534 ] || continue
        [ -d "${_home}" ] || continue
        _candidate_users="${_candidate_users}${_candidate_users:+ }${_u}"
        # docker group membership — only meaningful if docker is installed
        if id -nG "${_u}" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
            _candidate_in_docker="${_candidate_in_docker}${_candidate_in_docker:+ }${_u}"
        fi
    done < /etc/passwd

    # If SUDO_USER didn't set _detected_user but there's exactly one
    # candidate, use that.
    if [ -z "${_detected_user}" ]; then
        _n_candidates=$(echo "${_candidate_users}" | wc -w)
        if [ "${_n_candidates}" = "1" ]; then
            _detected_user="${_candidate_users}"
        fi
    fi

    _step_n=1
    echo -e "    ${WHITE}Run these steps to set up properly:${RESET}"
    echo ""
    if ! command -v docker &>/dev/null; then
        echo -e "      ${BOLD}${_step_n}.${RESET} Install Docker (creates the ${CYAN}docker${RESET} group):"
        echo -e "         ${CYAN}curl -fsSL https://get.docker.com | sh${RESET}"
        echo -e "         ${CYAN}systemctl enable --now docker${RESET}"
        _step_n=$((_step_n + 1))
        echo ""
    fi

    if [ -n "${_detected_user}" ]; then
        # We have a strong guess. Render it as a SUGGESTION, not a directive,
        # and make clear the user can pick someone else.
        _user="${_detected_user}"
        _in_docker=0
        if echo " ${_candidate_in_docker} " | grep -q " ${_user} "; then
            _in_docker=1
        fi
        echo -e "      ${BOLD}${_step_n}.${RESET} Pick a non-root user. Suggested: ${CYAN}${_user}${RESET}"
        # Mention other candidates if any exist beyond the suggested one.
        _other_users=$(echo " ${_candidate_users} " | sed "s/ ${_user} / /" | tr -s ' ' | sed 's/^ //;s/ $//')
        if [ -n "${_other_users}" ]; then
            echo -e "         ${MUTED}Other users on this host: ${_other_users}${RESET}"
        fi
        if [ "${_in_docker}" = "0" ]; then
            echo -e "         If you go with ${CYAN}${_user}${RESET}, add them to the docker group first:"
            echo -e "         ${CYAN}usermod -aG docker ${_user}${RESET}"
        fi
        echo -e "         ${MUTED}Or create a fresh user: ${CYAN}useradd -m -s /bin/bash <name> && usermod -aG docker <name>${RESET}"
        _step_n=$((_step_n + 1))
        echo ""
        echo -e "      ${BOLD}${_step_n}.${RESET} Re-run the installer as your chosen user"
        echo -e "         ${MUTED}(replace ${CYAN}${_user}${RESET}${MUTED} below if you picked someone else)${RESET}:"
        echo -e "         ${CYAN}sudo -iu ${_user} -- bash -c 'curl -fsSL https://aiorch.ai/install.sh | bash'${RESET}"
        echo ""
    elif [ -n "${_candidate_users}" ]; then
        # Multiple candidates with no clear pick — list them all.
        echo -e "      ${BOLD}${_step_n}.${RESET} Pick a non-root user. Available: ${CYAN}${_candidate_users}${RESET}"
        echo -e "         Make sure they're in the docker group (or create a fresh user):"
        echo -e "         ${CYAN}usermod -aG docker <user>${RESET}     ${MUTED}# only if not already${RESET}"
        echo -e "         ${MUTED}Or create a fresh user: ${CYAN}useradd -m -s /bin/bash <name> && usermod -aG docker <name>${RESET}"
        _step_n=$((_step_n + 1))
        echo ""
        echo -e "      ${BOLD}${_step_n}.${RESET} Re-run the installer as that user:"
        echo -e "         ${CYAN}sudo -iu <user> -- bash -c 'curl -fsSL https://aiorch.ai/install.sh | bash'${RESET}"
        echo ""
    else
        # No usable existing user. Show the create-from-scratch path.
        echo -e "      ${BOLD}${_step_n}.${RESET} No existing non-root user found. Create one:"
        echo -e "         ${CYAN}useradd -m -s /bin/bash aiorch${RESET}"
        echo -e "         ${CYAN}usermod -aG docker aiorch${RESET}"
        echo -e "         ${MUTED}(any name works — replace ${CYAN}aiorch${RESET}${MUTED} with your preferred username)${RESET}"
        _step_n=$((_step_n + 1))
        echo ""
        echo -e "      ${BOLD}${_step_n}.${RESET} Re-run the installer as that user:"
        echo -e "         ${CYAN}sudo -iu aiorch -- bash -c 'curl -fsSL https://aiorch.ai/install.sh | bash'${RESET}"
        echo ""
    fi
    echo -e "    ${DIM}If you genuinely need to run as root (e.g. an air-gapped"
    echo -e "    appliance), set ${CYAN}AIORCH_ALLOW_ROOT=1${RESET}${DIM} and re-run. You"
    echo -e "    accept the security implications by doing so.${RESET}"
    echo ""
    if [ "${AIORCH_ALLOW_ROOT:-0}" != "1" ]; then
        exit 1
    fi
    warn "AIORCH_ALLOW_ROOT=1 — proceeding as root at your own risk."
fi

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

# --- Check Docker daemon access ---
if ! docker info &>/dev/null 2>&1; then
    err "Cannot connect to the Docker daemon."
    echo ""
    echo -e "    ${DIM}If Docker is running, your user may not have permission.${RESET}"
    echo -e "    ${DIM}Add yourself to the docker group and re-login:${RESET}"
    echo -e "      ${CYAN}sudo usermod -aG docker \$USER${RESET}"
    echo -e "      ${DIM}Then log out and back in, or run: ${CYAN}newgrp docker${RESET}"
    echo ""
    read -p "$(echo -e "  ${MUTED}Press Enter to exit…${RESET}")" < /dev/tty
    exit 1
fi

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
INSTALL_CLAUDE_CHOICE="n"

if command -v claude &>/dev/null; then
    CLAUDE_CLI_PATH="$(command -v claude)"
    ok "Claude CLI found: ${CLAUDE_CLI_PATH}"
    INSTALL_CLAUDE_CHOICE="y"
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
fi
echo ""

# --- Detect / select Kimi CLI ---
KIMI_CLI_PATH=""
INSTALL_KIMI_CHOICE="n"

if command -v kimi &>/dev/null; then
    KIMI_CLI_PATH="$(command -v kimi)"
    ok "Kimi CLI found: ${KIMI_CLI_PATH}"
    INSTALL_KIMI_CHOICE="y"
else
    echo -e "  ${MUTED}○${RESET}  Kimi CLI  ${DIM}(Moonshot AI — Kimi K2)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}curl -LsSf https://code.kimi.com/install.sh | bash${RESET}"
    echo -e "      Verify:        ${CYAN}kimi --version${RESET}"
    echo ""
    read -p "$(echo -e "  ${GREEN}→${RESET}  Install Kimi CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_KIMI_NOW < /dev/tty
    if [ "${INSTALL_KIMI_NOW}" = "y" ] || [ "${INSTALL_KIMI_NOW}" = "Y" ]; then
        info "Installing Kimi CLI..."
        if curl -LsSf https://code.kimi.com/install.sh | bash; then
            # Re-detect after installation
            export PATH="${HOME}/.local/bin:${HOME}/.kimi/bin:${PATH}"
            if command -v kimi &>/dev/null; then
                KIMI_CLI_PATH="$(command -v kimi)"
                ok "Kimi CLI installed: ${KIMI_CLI_PATH}"
                INSTALL_KIMI_CHOICE="y"
                echo ""
                info "Run ${CYAN}kimi --version${RESET} to verify, then ${CYAN}kimi login${RESET} to authenticate."
            else
                warn "Kimi CLI installer ran but binary not found in PATH."
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
fi
echo ""

# --- Detect / select Codex CLI ---
CODEX_CLI_PATH=""
INSTALL_CODEX_CHOICE="n"

if command -v codex &>/dev/null; then
    CODEX_CLI_PATH="$(command -v codex)"
    ok "Codex CLI found: ${CODEX_CLI_PATH}"
    INSTALL_CODEX_CHOICE="y"
else
    echo -e "  ${MUTED}○${RESET}  Codex CLI  ${DIM}(OpenAI — Codex)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}npm install -g @openai/codex${RESET}"
    echo -e "      Authenticate:  ${CYAN}codex login${RESET}"
    echo ""
    read -p "$(echo -e "  ${GREEN}→${RESET}  Install Codex CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_CODEX_NOW < /dev/tty
    if [ "${INSTALL_CODEX_NOW}" = "y" ] || [ "${INSTALL_CODEX_NOW}" = "Y" ]; then
        if ! command -v npm &>/dev/null; then
            err "npm not found — Node.js is required for Codex CLI."
            echo -e "      Install Node.js first, then re-run:"
            echo -e "      ${CYAN}curl -fsSL https://deb.nodesource.com/setup_22.x | bash -${RESET}"
            echo -e "      ${CYAN}apt-get install -y nodejs${RESET}"
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
# Default to a path under the user's HOME so the install is fully unprivileged
# (no sudo, no password). Users who want a system-wide install can type
# /opt/aiorch (or any other root-owned path) explicitly — the sudo branch
# below will handle that case.
_default_install_dir="${HOME}/aiorch"
read -p "$(echo -e "  ${GREEN}→${RESET}  Install directory ${MUTED}[${_default_install_dir}]${RESET}: ")" INSTALL_DIR < /dev/tty
INSTALL_DIR=${INSTALL_DIR:-${_default_install_dir}}
# Expand a leading tilde the user may have typed literally — `read` does not
# perform tilde expansion.
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

if [ -d "${INSTALL_DIR}" ] && [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    warn "Existing installation found at ${INSTALL_DIR}"
    read -p "$(echo -e "  ${GREEN}→${RESET}  Overwrite configuration? ${MUTED}(y/N)${RESET}: ")" OVERWRITE < /dev/tty
    if [ "${OVERWRITE}" != "y" ] && [ "${OVERWRITE}" != "Y" ]; then
        info "Aborting. Existing installation preserved."
        exit 0
    fi
    info "Stopping existing containers..."
    docker compose -f "${INSTALL_DIR}/docker-compose.yml" down 2>/dev/null || true
fi

# Data dirs must be writable by the container process (runs as the host user's UID).
# Only require sudo when the chosen INSTALL_DIR is actually rooted somewhere the
# current user can't write — otherwise an unprivileged user installing under
# their own HOME doesn't need sudo at all.
_existing_parent="${INSTALL_DIR}"
while [ ! -d "${_existing_parent}" ]; do
    _existing_parent="$(dirname "${_existing_parent}")"
done

_sudo=""
if [ ! -w "${_existing_parent}" ] && [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo &>/dev/null; then
        err "Root privileges required to create ${INSTALL_DIR}, but sudo is not installed."
        echo -e "    ${DIM}Either install sudo, or re-run and choose a directory you own:${RESET}"
        echo -e "    ${CYAN}\$HOME/aiorch${RESET}"
        exit 1
    fi
    info "Elevated privileges required for ${INSTALL_DIR} (writing under ${_existing_parent})"
    echo -e "      ${DIM}To install without sudo, Ctrl+C and re-run with a path under your HOME${RESET}"
    echo -e "      ${DIM}(e.g. ${CYAN}\$HOME/aiorch${RESET}${DIM} — that's the default if you just hit Enter).${RESET}"
    if ! sudo -n true 2>/dev/null; then
        echo -e "      ${DIM}You'll be prompted for the sudo password for user ${CYAN}$(id -un)${RESET}${DIM}.${RESET}"
    fi
    _sudo="sudo"
fi

${_sudo} mkdir -p "${INSTALL_DIR}/data/sessions" "${INSTALL_DIR}/data/pipelines"
${_sudo} chown -R "$(id -u):$(id -g)" "${INSTALL_DIR}"

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

# Debug logging (system-wide structured JSONL for remote support)
ORCH_DEBUG_LOG_LEVEL=INFO
ORCH_DEBUG_LOG_RETENTION_HOURS=72

# Host user home directory (zero-copy CLI credential discovery)
ORCH_HOST_HOME=${HOME}

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

PROJECT_MOUNTS="      - /home:/home:z
      - /opt:/opt:z"

# If the user's HOME isn't already covered by the default mounts (e.g.
# /Users/foo on Mac, /local/home/foo with LDAP-mounted homes, /data/users/foo
# on custom Linux setups, /root when AIORCH_ALLOW_ROOT=1), bind-mount that
# specific user's HOME so CLI binaries and credentials under it are reachable
# from inside the container. We mount the user's HOME only — not the parent
# directory — to limit blast radius if the container is ever compromised.
case "${HOME}" in
    /home/*|/opt/*) ;;  # already covered by the default mounts
    /|"")
        warn "HOME is unset or '/'; CLI binary discovery may fail." ;;
    *)
        PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${HOME}:${HOME}:z"
        ok "Mounting your HOME (${HOME}) for CLI binaries and credentials"
        ;;
esac

if [ -n "${EXTRA_DIRS}" ]; then
    IFS=',' read -ra DIRS <<< "${EXTRA_DIRS}"
    for d in "${DIRS[@]}"; do
        d="$(echo "${d}" | xargs)"
        if [ -n "${d}" ] && [ "${d}" != "/home" ] && [ "${d}" != "/opt" ]; then
            PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${d}:${d}:z"
        fi
    done
fi

# =============================================================================
# Section 6: Generate docker-compose.yml
# =============================================================================
step "Docker Compose"


# CLI binaries are reachable from the container only if they live under a
# bind-mounted host path. /home, /opt, and (for non-/home users) ${HOME} are
# mounted; everything else — /usr/*, /lib/*, /bin, /sbin — is the container's
# OWN filesystem and would be shadowed by a host-side path of the same name.
# We use the directory of the symlink (or hard path) returned by
# `command -v` — NOT `readlink -f` — because Anthropic's claude installer
# creates ~/.local/bin/claude as a symlink whose target is named after the
# version (e.g. ~/.local/share/claude/versions/2.1.119, not …/claude).
# Resolving the symlink points the container at a directory that doesn't
# contain a file named "claude". The unresolved symlink dir does.
CLI_EXTRA_PATH=""
_cli_unreachable_warned=0
for cli_label_path in "Claude:${CLAUDE_CLI_PATH}" "Kimi:${KIMI_CLI_PATH}" "Codex:${CODEX_CLI_PATH}"; do
    cli_label="${cli_label_path%%:*}"
    cli_path="${cli_label_path#*:}"
    [ -z "${cli_path}" ] && continue
    cli_dir="$(cd "$(dirname "${cli_path}")" && pwd)"

    # Reject system paths that won't be visible inside the container.
    case "${cli_dir}" in
        /usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*)
            warn "${cli_label} CLI is at ${cli_dir} (system path)."
            echo -e "      ${DIM}The container has its own filesystem there; this binary won't be reachable.${RESET}"
            if [ "${cli_label}" = "Codex" ]; then
                echo -e "      ${DIM}Reinstall per-user: ${CYAN}npm install --prefix ~/.local @openai/codex${RESET}"
                echo -e "      ${DIM}or rebuild the orchestrator image with INSTALL_CODEX=true.${RESET}"
            else
                echo -e "      ${DIM}Reinstall per-user under \$HOME, then re-run this installer.${RESET}"
            fi
            _cli_unreachable_warned=1
            continue ;;
    esac

    # Reject paths that fall outside any planned bind mount.
    case "${cli_dir}" in
        /home/*|/opt/*) ;;
        ${HOME}/*|${HOME}) ;;
        *)
            # Outside default and HOME mounts. Warn and skip — the container
            # cannot see this directory.
            warn "${cli_label} CLI at ${cli_dir} is outside the planned mounts."
            echo -e "      ${DIM}Either move it under \$HOME, or add ${cli_dir} to extra mounts above.${RESET}"
            _cli_unreachable_warned=1
            continue ;;
    esac

    case ":${CLI_EXTRA_PATH}:" in
        *":${cli_dir}:"*) ;;
        *) CLI_EXTRA_PATH="${CLI_EXTRA_PATH:+${CLI_EXTRA_PATH}:}${cli_dir}" ;;
    esac
done
if [ "${_cli_unreachable_warned}" = "1" ]; then
    echo -e "    ${DIM}Setup will continue, but the affected CLIs won't work until fixed.${RESET}"
fi

cat > "${INSTALL_DIR}/docker-compose.yml" << DEOF
services:
  orchestrator:
    image: ${REGISTRY}:${IMAGE_TAG}
    ports:
      - "${PORT}:${PORT}"
    volumes:
      # Persistent data
      - ./data:/opt/aiorch/data:z
      # Compose project dir — needed for self-restart when adding project dirs
      - .:/opt/aiorch/compose:z
      # Project directories — agents access your code through these mounts
${PROJECT_MOUNTS}
      # CLI binaries discovered via /home:/home + PATH
    env_file:
      - .env
    environment:
      - ORCH_BASE_DIR=/app
      - ORCH_SESSIONS_DIR=/opt/aiorch/data/sessions
      - ORCH_PIPELINES_DIR=/opt/aiorch/data/pipelines
      - ORCH_DATA_DIR=/opt/aiorch/data
      - PYTHONPATH=/app
      - DOCKER_HOST=tcp://docker-proxy:2375
      - ORCH_HOST_HOME=${HOME}
      - PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${CLI_EXTRA_PATH}
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
      # CHOWN/SETUID/SETGID: required by entrypoint to drop privileges — do not remove
      - CHOWN
      - SETUID
      - SETGID
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: "20m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${PORT}/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  docker-proxy:
    image: tecnativa/docker-socket-proxy:0.3
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro,z
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
    tmpfs:
      - /run
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
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

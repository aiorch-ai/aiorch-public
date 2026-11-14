#!/usr/bin/env bash
# =============================================================================
# AiOrch — Interactive Docker Installer
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

# Brand accent — the aiorch. copper (~ #d7875f; reads on light and dark terminals).
# Used sparingly: the wordmark and active prompts only.
COPPER='\033[38;5;173m'
COPPER_BOLD='\033[1;38;5;173m'

# Utility
CYAN='\033[38;5;87m'
WHITE='\033[1;37m'
MUTED='\033[38;5;242m'    # ~ #5a5a70
MUTED2='\033[38;5;238m'   # ~ #3a3a50

# NO_COLOR / non-TTY fallback — disable everything if output isn't a color terminal.
# Every status word (available / Warning / Error / running / skipped) is carried
# by the TEXT, so the output stays legible with color off.
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RESET= BOLD= DIM= GREEN= GREEN_BOLD= ORANGE= YELLOW= RED= CYAN= WHITE= MUTED= MUTED2= COPPER= COPPER_BOLD=
fi

# --- Helper functions (calm tone; state is in the words, not the color) ---
ok()    { echo -e "  $*"; }
warn()  { echo -e "  ${YELLOW}Warning:${RESET} $*"; }
err()   { echo -e "  ${RED}Error:${RESET} $*"; }
info()  { echo -e "  ${MUTED}$*${RESET}"; }
skip()  { echo -e "  ${MUTED}$*${RESET}"; }
next()  { echo -e "  ${COPPER}→${RESET}  $*"; }
ask()   { echo -en "  ${COPPER}$*${RESET}"; }

# --- Brand logo (the aiorch.ai top-left mark: ring-with-dot + wordmark) ---
# Real inline image where the terminal supports the iTerm2 image protocol
# (iTerm2 / WezTerm / VS Code); a compact copper ANSI rendering otherwise;
# plain text when color is off. No external tools required.
_LOGO_B64='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'
print_logo() {
    if [ -z "${RESET}" ]; then
        echo "  AiOrch installer"
        return
    fi
    if [ -t 1 ] \
       && { [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || [ "${TERM_PROGRAM:-}" = "WezTerm" ] \
            || [ "${TERM_PROGRAM:-}" = "vscode" ] || [ "${LC_TERMINAL:-}" = "iTerm2" ]; } \
       && command -v base64 >/dev/null 2>&1; then
        _logo_bytes=$(printf '%%s' "${_LOGO_B64}" | base64 -d 2>/dev/null | wc -c)
        if [ "${_logo_bytes:-0}" -gt 0 ]; then
            printf '  \033]1337;File=inline=1;size=%%s;height=2;preserveAspectRatio=1:%%s\a\n' "${_logo_bytes}" "${_LOGO_B64}"
            return
        fi
    fi
    echo -e "  ${COPPER_BOLD}◉ aiorch.${RESET}"
}

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

# Section heading — bold, sentence case, separated by whitespace. No numbers,
# no rules; the calm tone comes from space, not ornament.
step() {
    echo ""
    echo -e "  ${BOLD}${WHITE}$*${RESET}"
    echo ""
}

# --- Brand logo + title (matches the aiorch.ai top-left mark) ---
echo ""
print_logo
echo ""
echo -e "  ${BOLD}${WHITE}Install AiOrch${RESET}"
echo ""

# =============================================================================
# Section 1: Prerequisites
# =============================================================================
step "System checks"

# --- Refuse to run as root ---
# AiOrch executes AI-generated code with the privileges of the host user.
# Running as root would give those agents read access to SSH keys, the
# package manager, /etc, every other user's home, and so on. The container
# runtime does not protect against this — entrypoint.sh runs as the host
# UID via setpriv, so root install ⇒ container processes run as root.
if [ "$(id -u)" = "0" ]; then
    err "Don't run the installer as root."
    echo ""
    echo -e "  Run the installer as a non-root user with Docker access."
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

    # If SUDO_USER didn't set _detected_user, prefer users already in the
    # docker group — on Hetzner / DigitalOcean / cloud-init images there's
    # often a `ubuntu` or `deploy` user pre-configured for docker access,
    # and suggesting that user is way better UX than telling them to create
    # a redundant `aiorch` user. If exactly one docker-group member exists,
    # use them. Otherwise fall back to "exactly one regular user" heuristic.
    if [ -z "${_detected_user}" ]; then
        _n_in_docker=$(echo "${_candidate_in_docker}" | wc -w)
        if [ "${_n_in_docker}" = "1" ]; then
            _detected_user="${_candidate_in_docker}"
        else
            _n_candidates=$(echo "${_candidate_users}" | wc -w)
            if [ "${_n_candidates}" = "1" ]; then
                _detected_user="${_candidate_users}"
            fi
        fi
    fi

    _step_n=1
    echo -e "    ${WHITE}Setup steps:${RESET}"
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
        if [ "${_in_docker}" = "0" ]; then
            echo -e "         ${MUTED}(${CYAN}sudo -iu${RESET}${MUTED} starts a fresh login shell so the new docker group${RESET}"
            echo -e "         ${MUTED}membership takes effect. If you instead try to run the installer in${RESET}"
            echo -e "         ${MUTED}an already-open shell of ${CYAN}${_user}${RESET}${MUTED}, you'll need ${CYAN}newgrp docker${RESET}${MUTED} first.)${RESET}"
        fi
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
    echo ""
    echo -e "    ${DIM}Why not root: agents run arbitrary code as the host user, so a root${RESET}"
    echo -e "    ${DIM}install means root containers — reachable SSH keys, /etc and every${RESET}"
    echo -e "    ${DIM}user's data. A user in the ${CYAN}docker${RESET}${DIM} group is the safer default;${RESET}"
    echo -e "    ${DIM}rootless Docker (${CYAN}https://docs.docker.com/engine/security/rootless/${RESET}${DIM}) isolates further.${RESET}"
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
ok "Docker is available. ${DIM}$(docker --version | grep -oP '\d+\.\d+\.\d+')${RESET}"

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
ok "Docker Compose is available. ${DIM}$(docker compose version --short)${RESET}"

# --- Check Docker starts on boot ---
if command -v systemctl &>/dev/null; then
    if systemctl is-enabled docker &>/dev/null; then
        ok "Docker starts on boot."
    else
        warn "Docker is not enabled to start on boot."
        echo -e "      ${DIM}The orchestrator won't auto-start after a reboot.${RESET}"
        echo -e "      ${DIM}Fix: ${CYAN}sudo systemctl enable docker${RESET}"
    fi
fi

# =============================================================================
# Section 2: CLI Agent Setup
# =============================================================================
step "Providers"
echo -e "  ${DIM}AiOrch runs CLI-based coding agents. Codex ships in the image; any${RESET}"
echo -e "  ${DIM}CLI detected on this host is mounted in. Others connect later in Settings.${RESET}"
echo ""

# --- Detect / select Claude CLI ---
CLAUDE_CLI_PATH=""
INSTALL_CLAUDE_CHOICE="n"

if command -v claude &>/dev/null; then
    CLAUDE_CLI_PATH="$(command -v claude)"
    ok "Claude CLI found: ${CLAUDE_CLI_PATH}"
    INSTALL_CLAUDE_CHOICE="y"
else
    echo -e "  ${MUTED}Claude CLI is not installed on this host.${RESET}  ${DIM}(Anthropic — Opus, Sonnet, Haiku)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}curl -fsSL https://claude.ai/install.sh | bash${RESET}"
    echo -e "      Authenticate:  ${CYAN}claude${RESET}"
    echo ""
    read -p "$(echo -e "  ${COPPER}→${RESET}  Install Claude CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_CLAUDE_NOW < /dev/tty
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
                read -p "$(echo -e "  ${COPPER}→${RESET}  Path to claude binary ${MUTED}(or Enter to skip)${RESET}: ")" CLAUDE_CLI_PATH < /dev/tty
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
        read -p "$(echo -e "  ${COPPER}→${RESET}  Path to claude binary ${MUTED}(or Enter to skip)${RESET}: ")" CLAUDE_CLI_PATH < /dev/tty
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
    echo -e "  ${MUTED}Kimi CLI is not installed on this host.${RESET}  ${DIM}(Moonshot AI — Kimi K2)${RESET}"
    echo ""
    echo -e "      Install:       ${CYAN}curl -LsSf https://code.kimi.com/install.sh | bash${RESET}"
    echo -e "      Verify:        ${CYAN}kimi --version${RESET}"
    echo ""
    read -p "$(echo -e "  ${COPPER}→${RESET}  Install Kimi CLI now? ${MUTED}(y/N)${RESET}: ")" INSTALL_KIMI_NOW < /dev/tty
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
                read -p "$(echo -e "  ${COPPER}→${RESET}  Path to kimi binary ${MUTED}(or Enter to skip)${RESET}: ")" KIMI_CLI_PATH < /dev/tty
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
        read -p "$(echo -e "  ${COPPER}→${RESET}  Path to kimi binary ${MUTED}(or Enter to skip)${RESET}: ")" KIMI_CLI_PATH < /dev/tty
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

# Codex is bundled in the orchestrator image starting with 3.9.31. The host
# CLI is now an OPTIONAL OVERRIDE for users who want a newer version than
# what's bundled — host wins because the container PATH puts host bin dirs
# first. Most customers can skip this section entirely.
if command -v codex &>/dev/null; then
    CODEX_CLI_PATH="$(command -v codex)"
    ok "Codex CLI found on host: ${CODEX_CLI_PATH} ${DIM}(will override bundled version)${RESET}"
    INSTALL_CODEX_CHOICE="y"
else
    echo -e "  Codex is included. ${DIM}(OpenAI — bundled in the image, ready to use)${RESET}"
    echo ""
    echo -e "      ${DIM}Codex ships with AiOrch and works out of the box once you${RESET}"
    echo -e "      ${DIM}authenticate inside the container: ${CYAN}docker exec -it aiorch-orchestrator-1 codex login${RESET}"
    echo ""
    echo -e "      ${DIM}Optional: install a host Codex CLI to override the bundled${RESET}"
    echo -e "      ${DIM}version (useful if you want a newer release than the image has).${RESET}"
    echo ""
    read -p "$(echo -e "  ${COPPER}→${RESET}  Install host Codex CLI override? ${MUTED}(y/N)${RESET}: ")" INSTALL_CODEX_NOW < /dev/tty
    if [ "${INSTALL_CODEX_NOW}" = "y" ] || [ "${INSTALL_CODEX_NOW}" = "Y" ]; then
        if ! command -v npm &>/dev/null; then
            warn "npm not found on host — cannot install override here."
            echo -e "      ${DIM}You can either:${RESET}"
            echo -e "      ${DIM}  - skip this and use the bundled Codex (recommended)${RESET}"
            echo -e "      ${DIM}  - install Node.js first, then re-run this installer:${RESET}"
            echo -e "        ${CYAN}curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -${RESET}"
            echo -e "        ${CYAN}sudo apt-get install -y nodejs${RESET}"
        else
            info "Installing Codex CLI override under \$HOME/.local..."
            mkdir -p "${HOME}/.local/lib" "${HOME}/.local/bin"
            # `-g --prefix DIR` = global-style install (creates bin symlinks)
            # but rooted at DIR instead of /usr/local. No sudo, no system pollution.
            # NOTE: do NOT pipe through grep with `|| true` — pipefail + ||true
            # makes the `if` always-true and we'd treat npm failures as success.
            # Show npm output verbatim; warnings are useful for support.
            if npm install -g --prefix "${HOME}/.local" @openai/codex; then
                if [ -x "${HOME}/.local/bin/codex" ]; then
                    CODEX_CLI_PATH="${HOME}/.local/bin/codex"
                    ok "Codex CLI override installed: ${CODEX_CLI_PATH}"
                    INSTALL_CODEX_CHOICE="y"
                    echo ""
                    info "Run ${CYAN}codex login${RESET} after setup to authenticate."
                else
                    warn "npm reported success but ${HOME}/.local/bin/codex was not created."
                    echo -e "      ${DIM}Falling back to the bundled version. You can investigate later.${RESET}"
                fi
            else
                warn "Codex CLI override install failed. Falling back to the bundled version."
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
echo -e "  ${DIM}Other providers (OpenAI, Gemini, Ollama) — configure in Settings. BYOK, zero markup.${RESET}"

# =============================================================================
# Section 3: Installation Configuration
# =============================================================================
step "Install location"

# --- Install directory ---
# Default to a path under the user's HOME so the install is fully unprivileged
# (no sudo, no password). Users who want a system-wide install can type
# /opt/aiorch (or any other root-owned path) explicitly — the sudo branch
# below will handle that case.
_default_install_dir="${HOME}/aiorch"
read -p "$(echo -e "  ${COPPER}→${RESET}  Install directory ${MUTED}[${_default_install_dir}]${RESET}: ")" INSTALL_DIR < /dev/tty
INSTALL_DIR=${INSTALL_DIR:-${_default_install_dir}}
# Expand a leading tilde the user may have typed literally — `read` does not
# perform tilde expansion.
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

if [ -d "${INSTALL_DIR}" ] && [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    warn "Existing installation found at ${INSTALL_DIR}"
    read -p "$(echo -e "  ${COPPER}→${RESET}  Overwrite configuration? ${MUTED}(y/N)${RESET}: ")" OVERWRITE < /dev/tty
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

# --- Dashboard access (port + listen interface, grouped) ---
step "Dashboard access"
echo -e "  ${DIM}127.0.0.1 keeps the dashboard on this host — from another computer,${RESET}"
echo -e "  ${DIM}reach it over an SSH tunnel (shown at the end). For direct access from${RESET}"
echo -e "  ${DIM}your network, enter a VPN/private IP instead (avoid 0.0.0.0 unless a${RESET}"
echo -e "  ${DIM}firewall or reverse proxy fronts it).${RESET}"
echo ""
read -p "$(echo -e "  ${COPPER}→${RESET}  Dashboard port ${MUTED}[1230]${RESET}: ")" PORT < /dev/tty
PORT=${PORT:-1230}
read -p "$(echo -e "  ${COPPER}→${RESET}  Listen address ${MUTED}[127.0.0.1]${RESET}: ")" PUBLISH_HOST < /dev/tty
PUBLISH_HOST=${PUBLISH_HOST:-127.0.0.1}

# --- License key ---
step "License"
read -sp "$(echo -e "  ${COPPER}→${RESET}  License key ${MUTED}(Enter for 14-day trial)${RESET}: ")" LICENSE_KEY < /dev/tty
echo ""

# --- License server URL ---
LICENSE_URL="https://license.aiorch.ai"
if [ -n "${LICENSE_KEY}" ]; then
    read -p "$(echo -e "  ${COPPER}→${RESET}  License server URL ${MUTED}[${LICENSE_URL}]${RESET}: ")" CUSTOM_LICENSE_URL < /dev/tty
    LICENSE_URL=${CUSTOM_LICENSE_URL:-${LICENSE_URL}}
fi

# --- Docker image ---
REGISTRY="aiorch/orchestrator"
IMAGE_TAG="latest"
read -p "$(echo -e "  ${COPPER}→${RESET}  Docker image ${MUTED}[${REGISTRY}:${IMAGE_TAG}]${RESET}: ")" CUSTOM_IMAGE < /dev/tty
if [ -n "${CUSTOM_IMAGE}" ]; then
    REGISTRY="${CUSTOM_IMAGE%%:*}"
    IMAGE_TAG="${CUSTOM_IMAGE##*:}"
    if [ "${IMAGE_TAG}" = "${REGISTRY}" ]; then
        IMAGE_TAG="latest"
    fi
fi

# --- Pull image ---
echo ""
info "Pulling image ${COPPER}→${RESET} ${CYAN}${REGISTRY}:${IMAGE_TAG}${RESET}"
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
# AiOrch · Generated by install.sh
# Multi-agent code orchestration · BYOK · No token markup
# Your keys. Your cost. Zero middleman.

# Server
ORCH_HOST=0.0.0.0
ORCH_PORT=${PORT}
ORCH_PUBLISH_HOST=${PUBLISH_HOST}
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

# Provider-level retry for transient errors (429, 5xx, timeouts)
ORCH_PROVIDER_RETRY_MAX=3
ORCH_PROVIDER_RETRY_BASE_DELAY=2.0
ORCH_PROVIDER_RETRY_MAX_DELAY=60.0
ORCH_REVIEW_RETRY_MAX=2

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
step "Project directories"
echo -e "  Agents need access to your code repos via volume mounts."
echo -e "  ${DIM}For security, AiOrch mounts ONLY the specific project directories you"
echo -e "  name here (plus the exact CLI binary dirs it needs) — never a broad parent"
echo -e "  like /home or /opt. Agents run arbitrary code with full Shell access, so a"
echo -e "  compromised or prompt-injected agent can read/modify anything mounted.${RESET}"
echo -e "  ${DIM}(Container has its own /tmp via tmpfs — host /tmp not mounted.)${RESET}"
echo ""
read -p "$(echo -e "  ${COPPER}→${RESET}  Project directories to mount ${MUTED}(comma-separated absolute paths, or Enter for none)${RESET}: ")" EXTRA_DIRS < /dev/tty

# No broad default: start empty, mount only what the operator names (and, later,
# the specific CLI binary dirs). You can add more any time via Settings → Project
# Directories in the web UI (writes data/docker-compose.override.yml).
PROJECT_MOUNTS=""

# Append a narrow bind mount. A broad parent (/, /home, /opt, /usr, /etc, $HOME…)
# re-opens the blast radius this default exists to close, so it requires explicit
# confirmation and never happens silently.
_add_project_mount() {
    local d="$1"
    case "${d}" in
        /|/home|/opt|/usr|/etc|/var|/root|"${HOME}")
            warn "Mounting ${d} exposes a broad tree to every agent (full read/write)."
            read -p "$(echo -e "      ${BOLD}Type 'yes' to mount ${d} anyway:${RESET} ")" _broad < /dev/tty
            if [ "${_broad}" != "yes" ]; then
                echo -e "      ${DIM}Skipped ${d}.${RESET}"
                return
            fi ;;
    esac
    PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${d}:${d}:z"
}

if [ -n "${EXTRA_DIRS}" ]; then
    IFS=',' read -ra DIRS <<< "${EXTRA_DIRS}"
    for d in "${DIRS[@]}"; do
        d="$(echo "${d}" | xargs)"
        [ -n "${d}" ] && _add_project_mount "${d}"
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

    # Mount the specific CLI binary directory (narrow) so the container can reach
    # it WITHOUT a broad /home or /opt mount. Skip if already covered by a mount
    # the operator added above. This keeps CLI discovery working under the
    # narrow-mount default (zero-trust mount policy — never a broad parent, never
    # a credential dir like ~/.ssh or ~/.aws).
    case "${PROJECT_MOUNTS}" in
        *"- ${cli_dir}:${cli_dir}:z"*) ;;
        *) PROJECT_MOUNTS="${PROJECT_MOUNTS}
      - ${cli_dir}:${cli_dir}:z" ;;
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
      - "${PUBLISH_HOST}:${PORT}:${PORT}"
    volumes:
      # Persistent data
      - ./data:/opt/aiorch/data:z
      # Compose project dir — needed for self-restart when adding project dirs
      - .:/opt/aiorch/compose:z
      # Project directories — agents access your code through these mounts
${PROJECT_MOUNTS}
      # Project + CLI-binary dirs above are narrow bind mounts (no broad /home or
      # /opt); host CLI dirs are also prepended to PATH below.
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
      # Host CLI dirs come FIRST so a host install (e.g. \$HOME/.local/bin/codex)
      # overrides the bundled version inside the image. Order: host > bundled.
      - PATH=${CLI_EXTRA_PATH}${CLI_EXTRA_PATH:+:}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    depends_on:
      docker-proxy:
        condition: service_started
    restart: unless-stopped
    # Runtime security hardening
    read_only: true
    tmpfs:
      - /tmp:size=1G
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
# Section 7: Start + health gate
# =============================================================================
step "Starting AiOrch"
cd "${INSTALL_DIR}"

# Bring the stack up. On success the verbose compose output is noise, so it is
# summarized; on failure it is exactly what the operator needs, so it is shown.
_up_log="$(mktemp 2>/dev/null || echo "/tmp/aiorch-up.$$")"
if docker compose up -d >"${_up_log}" 2>&1; then
    ok "Containers started."
    rm -f "${_up_log}"
else
    err "The containers did not start."
    echo ""
    echo -e "    ${DIM}docker compose reported:${RESET}"
    sed 's/^/      /' "${_up_log}" 2>/dev/null
    rm -f "${_up_log}"
    echo ""
    echo -e "    ${DIM}Fix the problem above, then re-run:${RESET} ${CYAN}cd ${INSTALL_DIR} && docker compose up -d${RESET}"
    exit 1
fi

# Don't call it running until the dashboard actually answers. The bind address
# is reachable from this host at the loopback (bound to 0.0.0.0 / localhost) or
# at the chosen private IP otherwise.
case "${PUBLISH_HOST}" in
    0.0.0.0|::|localhost) HEALTH_HOST=127.0.0.1 ;;
    *)                    HEALTH_HOST="${PUBLISH_HOST}" ;;
esac
HEALTHY=0
HEALTH_CHECKED=0
if command -v curl &>/dev/null; then
    HEALTH_CHECKED=1
    printf '  %sWaiting for the dashboard to respond%s' "${MUTED}" "${RESET}"
    for _i in $(seq 1 30); do
        if curl -fsS -o /dev/null "http://${HEALTH_HOST}:${PORT}/health" 2>/dev/null; then
            HEALTHY=1
            break
        fi
        printf '%s.%s' "${MUTED}" "${RESET}"
        sleep 1
    done
    printf '\n'
fi

# =============================================================================
# Section 8: Post-install summary
# =============================================================================
echo ""
if [ "${HEALTHY}" = "1" ]; then
    echo -e "  ${BOLD}${WHITE}AiOrch is running.${RESET}"
elif [ "${HEALTH_CHECKED}" = "0" ]; then
    echo -e "  ${BOLD}${WHITE}AiOrch is starting.${RESET}"
    echo -e "  ${MUTED}(Install curl to let the installer confirm readiness next time.)${RESET}"
else
    echo -e "  ${BOLD}${WHITE}AiOrch is starting${RESET} ${MUTED}— not responding yet.${RESET}"
    echo -e "  ${MUTED}First boot can take a moment. Watch it come up:${RESET}"
    echo -e "    ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f${RESET}"
fi
echo ""

# --- Open the dashboard (the most visible thing: address + connection method) ---
step "Open the dashboard"
case "${PUBLISH_HOST}" in
    127.0.0.1|localhost)
        # Derive an SSH target: real user@host only when BOTH are known.
        # SSH_CONNECTION is frequently absent (e.g. after `sudo -iu`), so fall
        # back to the USER@HOST placeholder whenever either part is missing.
        _ssh_user="$(id -un 2>/dev/null)"
        _ssh_host=""
        [ -n "${SSH_CONNECTION}" ] && _ssh_host="$(echo "${SSH_CONNECTION}" | awk '{print $3}')"
        if [ -n "${_ssh_user}" ] && [ -n "${_ssh_host}" ]; then
            _ssh_target="${_ssh_user}@${_ssh_host}"
        else
            _ssh_target="USER@HOST"
        fi
        echo -e "    ${BOLD}On this machine${RESET}     ${COPPER}http://127.0.0.1:${PORT}${RESET}"
        echo -e "    ${BOLD}From your computer${RESET}"
        echo -e "      ${CYAN}ssh -N -L 127.0.0.1:${PORT}:127.0.0.1:${PORT} ${_ssh_target}${RESET}"
        echo -e "      ${DIM}Run this on your own computer, then open ${RESET}${COPPER}http://127.0.0.1:${PORT}${RESET}${DIM} while the tunnel is open.${RESET}"
        ;;
    0.0.0.0|::)
        _net_host=""
        [ -n "${SSH_CONNECTION}" ] && _net_host="$(echo "${SSH_CONNECTION}" | awk '{print $3}')"
        echo -e "    ${BOLD}On this machine${RESET}     ${COPPER}http://127.0.0.1:${PORT}${RESET}"
        if [ -n "${_net_host}" ]; then
            echo -e "    ${BOLD}On your network${RESET}     ${COPPER}http://${_net_host}:${PORT}${RESET}"
        else
            echo -e "    ${BOLD}On your network${RESET}     ${COPPER}http://<this-host-ip>:${PORT}${RESET}"
        fi
        warn "Bound to all interfaces (0.0.0.0) — put a firewall or TLS reverse proxy in front."
        ;;
    *)
        echo -e "    ${BOLD}On your network${RESET}     ${COPPER}http://${PUBLISH_HOST}:${PORT}${RESET}"
        echo -e "      ${DIM}Devices that can reach ${PUBLISH_HOST} (same VPN/private network) open this address.${RESET}"
        ;;
esac
echo ""

# --- The real next step ---
step "Next"
echo -e "  Open the dashboard and set your master password."
echo -e "  ${MUTED}Then add a provider under Settings — your keys, your cost, no markup.${RESET}"

# --- Quieter details ---
step "Details"
echo -e "  ${MUTED}Data${RESET}      ${INSTALL_DIR}/data"
echo -e "  ${MUTED}Config${RESET}    ${INSTALL_DIR}/.env"
echo ""

CLI_CONFIGURED=0
if [ -n "${CLAUDE_CLI_PATH}" ]; then
    next "Claude CLI mounted — run ${CYAN}claude${RESET} on the host to authenticate."
    CLI_CONFIGURED=1
fi
if [ -n "${KIMI_CLI_PATH}" ]; then
    next "Kimi CLI mounted — run ${CYAN}kimi login${RESET} on the host to authenticate."
    CLI_CONFIGURED=1
fi
if [ -n "${CODEX_CLI_PATH}" ]; then
    next "Codex CLI mounted — run ${CYAN}codex login${RESET} on the host to authenticate."
    CLI_CONFIGURED=1
fi
if [ ${CLI_CONFIGURED} -eq 0 ]; then
    echo -e "  ${MUTED}No host CLI mounted. Codex is bundled; install others on the host and re-run.${RESET}"
fi
echo ""

if [ -n "${LICENSE_KEY}" ]; then
    echo -e "  License   configured"
else
    echo -e "  License   14-day trial active"
fi

if command -v systemctl &>/dev/null && ! systemctl is-enabled docker &>/dev/null; then
    echo ""
    warn "Docker is not enabled to start on boot — AiOrch won't return after a reboot."
    echo -e "      ${DIM}Fix:${RESET} ${CYAN}sudo systemctl enable docker${RESET}"
fi

echo ""
echo -e "  ${BOLD}${WHITE}Manage${RESET}  ${MUTED}cd ${INSTALL_DIR}${RESET}"
echo -e "    ${CYAN}docker compose logs -f${RESET}                        ${MUTED}# view logs${RESET}"
echo -e "    ${CYAN}docker compose restart${RESET}                        ${MUTED}# restart${RESET}"
echo -e "    ${CYAN}docker compose down${RESET}                           ${MUTED}# stop${RESET}"
echo -e "    ${CYAN}docker compose pull && docker compose up -d${RESET}   ${MUTED}# update${RESET}"
echo ""

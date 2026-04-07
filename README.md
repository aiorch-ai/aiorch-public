# AIORCH

**AI agents write, review, and merge your code. You wake up to a PR you can actually merge.**

Give it a task — AIORCH decomposes the work into parallel agents, each in isolated git worktrees. They write code, review each other through adversarial multi-round reviews, pass deterministic quality gates, resolve merge conflicts, and open a GitHub PR. Your keys, your cost, zero middleman.

## How It Works

1. **You describe the task** — "Refactor the auth module and add rate limiting"
2. **AIORCH decomposes it** — Creates parallel sub-tasks with dependency ordering, classifies each by difficulty
3. **Smart routing assigns models** — Opus for hard tasks, Sonnet for medium, Haiku for simple — mix providers freely
4. **Agents work in isolation** — Each agent gets its own git worktree
5. **Agents review each other** — Automated code review with approve/reject/revise verdicts
6. **Branches merge automatically** — Conflict resolution with dependency-aware ordering
7. **You get a PR** — Reviewed, tested, merged code with cost breakdown and agent summary

## What Makes This Different

- **Git worktree isolation per agent** — full filesystem isolation, not just branches.
- **Multi-round adversarial review** — reviewer and coder go back and forth until consensus.
- **Deterministic quality gates** — compilation, linting, secret scanning run as real checks, not AI prompts.
- **Smart model routing** — assign the right model per task difficulty, mix Claude + OpenAI + Ollama in one session.
- **BYOK — zero token markup** — bring your own API keys, pay providers directly at your rate.
- **Real-time streaming** — watch agents think and code token-by-token.
- **Full cost visibility** — per-agent cost tracking with measured vs estimated labels.
- **Self-hosted** — your code never leaves your server.

## Install

```bash
curl -fsSL https://aiorch.ai/install.sh | bash
```

Requires Docker. Takes under 5 minutes. Works on Ubuntu 22.04/24.04 and any Linux with Docker.

The installer:
- Checks Docker and Docker Compose
- Pulls the AIORCH image
- Prompts for port, license key, and configuration
- Generates config and starts the service

Open `http://localhost:1230` to access the dashboard.

## First Steps

1. Visit `/settings` to set your master password and configure API keys
2. Click `+ Session` to create your first orchestration session
3. Enter a task description, select your project directory, choose models
4. Start the session and watch agents work in real-time
5. When complete, click "Create GitHub PR" to push results

## Supported Models

| Provider | Models | Agent Work | Planning | Review |
|----------|--------|:---:|:---:|:---:|
| **Claude CLI** | Opus, Sonnet, Haiku | Yes | Yes | Yes |
| **OpenAI** | GPT-5.4/5.2/5.1/5 Pro/Mini/Nano, GPT-4.1, GPT-4o, o4-mini, o3 | Yes | Yes | Yes |
| **Ollama** | Any tool-capable local model (Qwen 3, Llama 3.3, Mistral, etc.) | Yes* | Yes | Yes |
| **OpenAI-compatible** | xAI/Grok, Together, Groq, Mistral | Yes | Yes | Yes |

\* Ollama agent work requires a tool-capable model. Browse models at [ollama.com/search?c=tools](https://ollama.com/search?c=tools)

Mix models per role: use a cheap model for planning, a strong model for coding, and a balanced model for review.

### Smart Model Routing

Assign different models per agent based on task difficulty. The planning model classifies each sub-task as high, medium, or low difficulty, then each agent runs on the model configured for its tier.

- **High** (architecture, complex algorithms, security) → Opus, GPT-5.4 Pro
- **Medium** (feature implementation, APIs, services) → Sonnet, GPT-5.4
- **Low** (boilerplate, config, simple tests) → Haiku, GPT-5.4 Mini

Mix providers freely — Claude for hard tasks, OpenAI for medium, Ollama for simple. All in one session, running in parallel. Toggle on/off per session via the dashboard.

Model dropdowns are populated dynamically — only available, tested models appear. Adding a new provider (e.g., Kimi K2, Qwen) is a single-file operation via the extensible provider registry.

## Features

- Smart model routing — difficulty-based model assignment, cross-provider mixing per session
- Dynamic model catalog — UI auto-discovers available models from live provider health probes
- Real-time web dashboard with SSE streaming
- Token-by-token agent output streaming
- Per-agent cost tracking (measured for API, estimated for CLI, free for Ollama)
- GitHub PR auto-creation with summary, cost, and diff stats
- Multi-phase pipelines (sequential and parallel)
- Shared memory between agents
- Dependency graphs with topological ordering
- Secret scanner in pre-review hooks
- Agent resilience: auto-retry, timeout detection, zombie recovery
- One-click restart for stuck or failed agents
- Diagnostic export for remote support
- Settings page with master password for API key management

## Security

- **Dashboard authentication** — API key auto-generated on install, required for all API requests
- **Rate limiting** — 120 requests/minute per IP, configurable via ORCH_RATE_LIMIT_RPM
- **API keys managed** via master-password-protected settings page
- **All API responses sanitized** — 9 regex patterns strip secrets from output
- **Agent subprocesses** run with sensitive env vars removed
- **Tool-use loop sandboxed** — path validation, command blocking, symlink escape prevention
- **Pre-review hooks** scan for hardcoded secrets in code diffs
- **Non-root Docker** — license server runs as unprivileged user
- **Timing-safe auth** — API key comparison uses constant-time algorithm
- **Self-hosted** — code and keys stay on your infrastructure

## Pricing

| Plan | Price | Concurrent Instances |
|------|-------|---------------------|
| Trial | Free (14 days) | 1 |
| Developer | £19.99/month | 2 |
| Team | £74.99/month | 10 |
| Enterprise | Contact us | Custom |

## Support

- **Email:** support@aiorch.ai
- **Issues:** Open an issue in this repository
- **Diagnostics:** Use the "Export Diagnostics" button in the session page to generate a sanitized report

## Requirements

- Docker 20.10+
- Docker Compose v2
- Claude CLI (for Claude models) — [Install guide](https://docs.anthropic.com/en/docs/claude-code)
- OpenAI API key (for OpenAI models) — optional
- Ollama (for local models) — optional

## Links

- **Website:** [aiorch.ai](https://aiorch.ai)
- **Install:** `curl -fsSL https://aiorch.ai/install.sh | bash`

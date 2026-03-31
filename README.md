# Orchestrator — AI Agents That Check Each Other's Work

Multi-agent AI code orchestration platform. Give it a task, get back a reviewed, tested, merged pull request.

Your AI agents don't just write code — they review each other, run quality gates, resolve merge conflicts, and deliver integrated results. You see the PR, not the chaos.

## How It Works

1. **You describe the task** — "Refactor the auth module and add rate limiting"
2. **Orchestrator decomposes it** — Creates parallel sub-tasks with dependency ordering
3. **Agents work in isolation** — Each agent gets its own git branch and worktree
4. **Agents review each other** — Automated code review with approve/reject/revise verdicts
5. **Quality gates enforce standards** — Code must compile, linter must pass, no hardcoded secrets
6. **Branches merge automatically** — Conflict resolution with dependency-aware ordering
7. **You get a PR** — Reviewed, tested, merged code with cost breakdown and agent summary

## What Makes This Different

- **Git isolation per agent** — real worktrees, not shared files. No conflicts during execution.
- **Multi-round adversarial review** — reviewer and coder go back and forth until consensus.
- **Deterministic quality gates** — compilation, linting, secret scanning run as real checks, not AI prompts.
- **Any model for any role** — Claude for coding, GPT-4o for planning, Ollama for local inference.
- **Full cost visibility** — per-agent cost tracking, pre-run estimates, measured vs estimated labels.
- **Self-hosted** — your code never leaves your server. API keys encrypted, secrets redacted.

## Install

```bash
curl -fsSL https://aiorch.ai/install | bash
```

Requires Docker. Takes under 5 minutes. Works on Ubuntu 22.04/24.04 and any Linux with Docker.

The installer:
- Checks Docker and Docker Compose
- Pulls the Orchestrator image
- Prompts for port, license key, and configuration
- Generates `.env` and `docker-compose.yml`
- Starts the service

Open `http://localhost:1230` to access the dashboard.

## First Steps

1. Visit `/settings` to set your master password and configure API keys
2. Click `+ Session` to create your first orchestration session
3. Enter a task description, select your project directory, choose models
4. Start the session and watch agents work in real-time
5. When complete, click "Create GitHub PR" to push results

## Supported Models

| Provider | Models | Used For |
|----------|--------|----------|
| **Claude CLI** | Opus, Sonnet, Haiku | Agent work (coding), review, planning |
| **OpenAI** | GPT-4o, GPT-4o-mini, GPT-4.1, o3, o4-mini | Agent work (tool-use loop), planning, review |
| **Ollama** | Any local model | Planning, review (no tool support) |
| **OpenAI-compatible** | xAI/Grok, Together, Groq, Mistral | Agent work, planning, review (same as OpenAI) |

Mix models per role: use a cheap model for planning, a strong model for coding, and a balanced model for review.

## Features

- Real-time web dashboard with SSE streaming
- Per-agent cost tracking (measured for API, estimated for CLI)
- GitHub PR auto-creation with summary, cost, and diff stats
- Multi-phase pipelines (sequential and parallel)
- Shared memory between agents
- Dependency graphs with topological ordering
- Secret scanner in pre-review hooks
- Zombie detection and one-click restart
- Diagnostic export for remote support
- 14-day free trial, then $99/month per seat

## Security

- API keys encrypted on disk, accessible only after master password authentication
- All API responses sanitized — 9 regex patterns strip secrets from output
- Agent subprocesses run with sensitive env vars removed
- Tool-use loop sandboxed — path validation, command blocking, symlink escape prevention
- Pre-review hooks scan for hardcoded secrets in code diffs
- Self-hosted — code and keys stay on your infrastructure

## Pricing

| Plan | Price | Concurrent Instances |
|------|-------|---------------------|
| Trial | Free (14 days) | 1 |
| Individual | $99/month | 2 |
| Team | $299/month | 10 |
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
- **Install:** `curl -fsSL https://aiorch.ai/install | bash`
- **Documentation:** [aiorch.ai/docs](https://aiorch.ai/docs)

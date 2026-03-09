# The ClawPapa of Everything by Chance

Clawpapa is Chance's ZeroClaw of everything hosted at [claw.chancejiang.com](https://claw.chancejiang.com), admin by node `zeroclaw.ruffe-court.ts.net`.

Deployment configuration and automation scripts for ZeroClaw - an AI-powered agent system with Telegram bot integration.

## Overview

This repository contains the infrastructure-as-code for deploying and managing ZeroClaw on Ubuntu LXC containers with Cloudflare Tunnel exposure.

### Key Components

| Directory | Description |
|-----------|-------------|
| `deploy/` | Shell scripts and Makefile for ZeroClaw deployment |
| `workspace/` | Master copy/backup of ZeroClaw app workspace (syncs to `~/.zeroclaw/workspace/`) |
| `workspace/skills/` | ZeroClaw skills (e.g., `feishu_bot/`) |
| `secrets/` | SSH public keys (private keys excluded via .gitignore) |
| `skills/` | Hardware documentation and community skills for ZeroClaw |
| `skills/open-skills/` | Forked community skills repository (security-audited) |
| `.clinerules/` | Project specifications and feature comparison docs |

### Features

- **ZeroClaw Agent**: Rust-based AI agent with multi-LLM support
- **Telegram Bot**: `@clawpapa` for chat-based control
- **Feishu Bot**: WebSocket Long-Connection SDK for real-time messaging
- **Cloudflare Tunnel**: Secure external access via `claw.chancejiang.com`
- **Yew Dashboard**: Planned web UI for monitoring and control

## Quick Start

### Deploy to Remote Server

```bash
# SSH to target node
ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Clone and deploy
git clone git@github.com:chancejiang/zeroclaw.git ~/zeroclaw
cd ~/zeroclaw && cargo build --release
./target/release/zeroclaw onboard
./target/release/zeroclaw daemon
```

### Local Development

```bash
# Clone this config repo
git clone git@github.com:chancejiang/clawchance.git
cd clawchance

# Use deploy scripts
make -C deploy setup
```

## Directory Structure & Sync

### Remote Server Structure (`ubuntu@zeroclaw.ruffe-court.ts.net`)

```
/home/ubuntu/
├── zeroclaw/                    # ZeroClaw repository (git clone)
│   └── target/release/zeroclaw  # Binary
│
├── workspace/                   # Admin tools ONLY (NOT for ZeroClaw app)
│
└── .zeroclaw/                   # ZeroClaw App Data
    ├── config.toml              # Configuration
    ├── memory.db                # Memory database
    └── workspace/               # ZeroClaw app workspace
        ├── skills/              # Skills (e.g., feishu_bot)
        ├── vuepress-site/       # Projects
        └── ...
```

### Local Workspace Sync

The local `workspace/` directory serves as the **master copy/backup** of the ZeroClaw app's workspace:

```
Local workspace/  ←→  Remote ~/.zeroclaw/workspace/
```

**Sync Command:**
```bash
rsync -avz workspace/ ubuntu@zeroclaw.ruffe-court.ts.net:/home/ubuntu/.zeroclaw/workspace/
```

### Important Distinction

| Path | Purpose |
|------|---------|
| `/home/ubuntu/workspace` | Admin tools only (NOT ZeroClaw) |
| `/home/ubuntu/.zeroclaw/workspace` | ZeroClaw app workspace (skills, projects) |
| Local `workspace/` | Master copy synced to `~/.zeroclaw/workspace/` |

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Telegram Bot  │────▶│    ZeroClaw      │────▶│   LLM Provider  │
│  @clawpapa       │     │   (Gateway)      │     │  (GLM/Ollama)   │
└─────────────────┘     │   Port: 42617    │     └─────────────────┘
                        └────────┬─────────┘
                                 │
┌─────────────────┐     ┌────────▼─────────┐
│   Feishu Bot    │────▶│ Cloudflare Tunnel│
│  (WebSocket)    │     │ claw.chancejiang │
└─────────────────┘     │      .com        │
                        └──────────────────┘
```

### Feishu Bot Integration

ZeroClaw integrates with Feishu (Lark) via **WebSocket Long-Connection SDK** for real-time messaging:

| Component | Protocol | Purpose |
|-----------|----------|---------|
| Event Receiving | WebSocket (`wss://`) | Real-time message events (millisecond latency) |
| Message Sending | REST API | Send replies and messages |
| Document Operations | MCP Service | AI agent document workflows |

**Key Advantage:** WebSocket allows local development without port forwarding or ngrok - just outbound connection to Feishu servers.

See `workspace/skills/feishu_bot/SKILL.md` for full integration documentation.

## Deploy Keys

| Key | Repository | Purpose |
|-----|------------|---------|
| `clawchance` | `chancejiang/clawchance` | This project |
| `github-deploy` | `chancejiang/zeroclaw` | ZeroClaw upstream |
| `chanceskills` | `chancejiang/open-skills` | Community skills fork |

See `.clinerules/SPECS.md` for full deploy key setup instructions.

## Open-Skills Mandate

For security auditing purposes, all ZeroClaw deployments must use the forked community skills repository from this project, **NOT** the upstream/official one.

### Repository

- **Fork**: `git@github.com:chancejiang/open-skills.git`
- **Local Copy**: `skills/open-skills/` in this repository
- **Remote Path**: `~/open-skills` on zeroclaw node

### Why This Matters

1. **Security Auditing**: All skills are reviewed before being used in production
2. **Version Control**: Changes to skills are tracked and auditable
3. **Stability**: Forked version ensures consistent behavior across deployments

### Provisioning on ZeroClaw Node

```bash
# On zeroclaw node - clone the forked repo (NOT upstream)
ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Remove any existing upstream clone
rm -rf ~/open-skills

# Clone from this project's fork
git clone git@github.com:chancejiang/open-skills.git ~/open-skills
```

### Updating Skills

When updating skills, always:
1. Pull changes to this repository's `skills/open-skills/` first
2. Review and audit the changes
3. Push to the `chancejiang/open-skills` fork
4. Then pull on the zeroclaw node

## Related Projects

- [ZeroClaw](https://github.com/chancejiang/zeroclaw) - Main AI agent repository
- [PicoClaw](https://github.com/yu819471/claw-pico) - Ultra-lightweight Go variant
- [Open-Skills Fork](https://github.com/chancejiang/open-skills) - Community skills (audited)

## License

MIT

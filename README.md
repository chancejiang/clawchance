# claw.chancejiang.com

Deployment configuration and automation scripts for ZeroClaw - an AI-powered agent system with Telegram bot integration.

## Overview

This repository contains the infrastructure-as-code for deploying and managing ZeroClaw on Ubuntu LXC containers with Cloudflare Tunnel exposure.

### Key Components

| Directory | Description |
|-----------|-------------|
| `deploy/` | Shell scripts and Makefile for ZeroClaw deployment |
| `secrets/` | SSH public keys (private keys excluded via .gitignore) |
| `skills/` | Hardware documentation for target deployment platforms |
| `.clinerules/` | Project specifications and feature comparison docs |

### Features

- **ZeroClaw Agent**: Rust-based AI agent with multi-LLM support
- **Telegram Bot**: `@clawyeyebot` for chat-based control
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

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Telegram Bot  │────▶│    ZeroClaw      │────▶│   LLM Provider  │
│  @clawyeyebot   │     │   (Gateway)      │     │  (GLM/Ollama)   │
└─────────────────┘     │   Port: 42617    │     └─────────────────┘
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │ Cloudflare Tunnel│
                        │ claw.chancejiang │
                        │      .com        │
                        └──────────────────┘
```

## Deploy Keys

| Key | Repository | Purpose |
|-----|------------|---------|
| `clawchance` | `chancejiang/clawchance` | This project |
| `github-deploy` | `chancejiang/zeroclaw` | ZeroClaw upstream |

See `.clinerules/SPECS.md` for full deploy key setup instructions.

## Related Projects

- [ZeroClaw](https://github.com/chancejiang/zeroclaw) - Main AI agent repository
- [PicoClaw](https://github.com/yu819471/claw-pico) - Ultra-lightweight Go variant

## License

MIT
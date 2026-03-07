# ZeroClaw vs. PicoClaw Feature Parity Review

> **Review Summary**: This document compares **ZeroClaw** (Rust-based) and **PicoClaw** (Go-based, ultra-lightweight variant) for feature parity in LXC/container-focused deployments.

**Key Context**: Low resources, Docker sandbox, Cloudflare Tunnel, multi-LLM via direct config, Yew web UI adaptation, and automation for VuePress/Paragraph sites, plus Telegram bot features (file upload, audio-text transcription).

**Maturity Comparison**: ZeroClaw has 18k-19k GitHub stars vs. PicoClaw's ~6 stars (as of early 2026). ZeroClaw emphasizes flexibility/security; PicoClaw focuses on extreme portability on $10 hardware.

**Overall Parity Score**: **7/10** — High on efficiency/deployment/multi-LLM; moderate on Telegram/media; low on transcription/UI.

---

## 1. Resource Usage and Performance (High Parity)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **RAM Usage** | <5MB (common workflows) | <10MB |
| **Startup Time** | <10ms (release builds) | <1s (even on 0.6GHz cores) |
| **Binary Size** | ~8.8MB | Similar single binary |
| **Target Hardware** | Low-cost boards/cloud | $10 hardware (RISC-V like LicheeRV-Nano) |
| **Benchmarks vs OpenClaw** | 99% less memory, 98% cheaper | 99% smaller footprint, 400x faster startup on low-end |

**Parity Notes**: Near-identical efficiency. Both suit LXC setup; PicoClaw might run slightly better on ultra-constrained hardware, but ZeroClaw's Rust optimizations (e.g., `codegen-units=1`) make it faster in cold starts. Both prebuilt binaries avoid heavy dependencies.

---

## 2. Runtime and Deployment (High Parity)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **Runtime** | Native or Docker | Go-native single binary |
| **Docker Support** | Alpine image, `network="none"`, read-only FS | Docker Compose, no explicit sandbox |
| **Platform Support** | LXC nesting enabled | ARM, x86, RISC-V, MIPS, Termux (Android) |
| **Gateway Port** | 42617 (localhost bind) | 18790 (shared HTTP) |
| **Config Format** | TOML | JSON (overridable via env) |
| **Persistence** | systemd service | Binary/service |

**Parity Notes**: Both lightweight and container-friendly. ZeroClaw has stronger sandboxing (memory/CPU limits, runtime adapters); PicoClaw adds Android/Termux support but lacks ZeroClaw's tunnel providers (e.g., Cloudflare native).

---

## 3. Channels and Messaging Integrations (Moderate Parity)

### ZeroClaw Channels
CLI, Telegram, Discord, Slack, Mattermost, iMessage, Matrix, Signal, WhatsApp, Email, IRC, Lark, DingTalk, QQ, Nostr, Webhook

### PicoClaw Channels
Telegram, Discord, WhatsApp (native/bridge), QQ, DingTalk, LINE, WeCom (Bot/App/AI Bot), Feishu (WebSocket/SDK)

**Parity Notes**: Both support Telegram/Discord/QQ/DingTalk; ZeroClaw has broader options (Signal, Email). PicoClaw's WhatsApp is native (whatsmeow lib, QR pairing); ZeroClaw offers both Web and Business API modes.

---

## 4. Telegram Bot Specifics (Moderate Parity — ZeroClaw Slightly Ahead)

### ZeroClaw
- **Text Handling**: Strong (replies to chat ID, message splitting, timeouts)
- **Outbound Media**: Markers like `[IMAGE:<path/url>]`, `[DOCUMENT:<>]`, `[VIDEO:<>]`, `[AUDIO:<>]`, `[VOICE:<>]`
- **Inbound Media**: Receives as tags (e.g., `media:audio`) but no auto-download/processing
- **Security**: Allowlist via `bind-telegram` command

### PicoClaw
- **Text Handling**: Basic command forwarding (`/show`, `/list`)
- **Media**: No explicit markers; relies on general tools
- **Security**: User restrictions via `allow_from` IDs

**Parity Notes**: ZeroClaw better for media-rich bots (outbound attachments); PicoClaw might require custom tool extensions for uploads.

---

## 5. Audio-Text Transcription (Low Parity — PicoClaw Ahead)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **Built-in Transcription** | No | Yes (Groq/Whisper) |
| **Workaround** | `http_request` to external APIs (e.g., OpenAI Whisper) | Native via model_list config |

**Parity Notes**: PicoClaw has native Groq integration; ZeroClaw requires manual agent prompts/tools. If audio features are key, PicoClaw is stronger.

---

## 6. Tools and Integrations (High Parity)

### ZeroClaw Tools
- **Core**: shell, file, memory, cron/schedule, git, pushover
- **Web**: browser, http_request, screenshot
- **APIs**: composio (1000+ OAuth apps)
- **Spec Config**: git/npm for VuePress, http_request/browser for Paragraph API/UI
- **Browser Backend**: `rust_native`

### PicoClaw Tools
- **Web Search**: DuckDuckGo, Brave, Perplexity, SearXNG
- **File Ops**: read, write, list, edit, append
- **Exec**: Sandboxed execution
- **Agent**: cron, spawn (subagents), message (inter-agent comms)

**Parity Notes**: ZeroClaw more comprehensive (browser, git); PicoClaw's `spawn` adds multi-agent capability.

---

## 7. Memory and Persistence (Moderate Parity)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **Backends** | SQLite, PostgreSQL, Lucid, Markdown, none | File-based only |
| **Search** | Hybrid (vector/keyword) | N/A |
| **Storage** | `~/.zeroclaw/` | `~/.picoclaw/workspace` |
| **Migration** | From OpenClaw | N/A |

**Parity Notes**: ZeroClaw superior for scalable/searchable memory; PicoClaw simpler but less robust.

---

## 8. Autonomy and Security (High Parity)

### ZeroClaw
- **Autonomy Levels**: `readonly`, `supervised`, `full` (default: supervised)
- **Emergency**: `estop` command
- **Sandbox**: `workspace_only`, `allowed_commands`, `forbidden_paths`
- **Secrets**: Encryption, gateway pairing

### PicoClaw
- **Code Generation**: 95% agent-generated
- **Subagents**: Via `spawn`
- **Sandbox**: Restricts to workspace, blocks dangerous commands (e.g., `rm -rf`)
- **Roadmap**: SSRF/prompt injection defenses

**Parity Notes**: Both emphasize security. ZeroClaw's levels/estop fit supervised start; PicoClaw's multi-agent enhances automation but lacks explicit levels.

---

## 9. Multi-LLM Support (High Parity)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **Providers** | Custom endpoints, OpenRouter, Ollama, etc. | OpenAI, Anthropic, Zhipu, Groq, Ollama, OpenRouter |
| **Routing** | Manual (via flags) | Manual (roadmap: smart routing) |
| **Config** | Direct config approach | `model_list` in config |

**Parity Notes**: Both match direct config approach; PicoClaw's future routing could add auto-decision.

---

## 10. Web UI/Dashboard (Low Parity)

| Feature | ZeroClaw | PicoClaw |
|---------|----------|----------|
| **Native UI** | No (CLI/gateway focus) | No (CLI-centric) |
| **Custom UI** | Yew (Rust/Wasm) adaptation | Roadmap: multi-agent collaboration UIs |

**Parity Notes**: Both lack built-in UI; Yew adaptation works for either, but ZeroClaw's Rust aligns better with Yew.

---

## Overall Assessment

### Strengths of ZeroClaw
- Broader tools/channels
- Stronger media outbound in Telegram
- Flexible memory/runtimes
- Mature security (tunnel providers)
- **Ideal for**: Browser for Paragraph, git for VuePress, composio APIs — more "production-ready"

### Strengths of PicoClaw
- Extreme hardware portability ($10 devices)
- Built-in Groq transcription
- Multi-agent `spawn`
- **Ideal for**: Voice-heavy or ultra-low-resource bots

### Recommendation
- **ZeroClaw wins** for: Telegram text/notifications with occasional media
- **PicoClaw wins** for: Voice-heavy or $10 hardware bots
- **Migration path**: Test PicoClaw in duplicate LXC via binary install for comparison

---

# ZeroClaw Deployment Guide

## Target Environment

| Parameter | Value |
|-----------|-------|
| **Target Node** | `ubuntu@zeroclaw.ruffe-court.ts.net` |
| **OS** | Ubuntu 24.04.4 LTS (Noble Numbat) |
| **Kernel** | 6.8.0-101-generic x86_64 |
| **Access** | Tailscale SSH |
| **Repository** | `git@github.com:chancejiang/zeroclaw.git` |

---

## Telegram Bot Configuration

| Parameter | Value |
|-----------|-------|
| **Bot Username** | `@clawyeyebot` |
| **Bot Link** | https://t.me/clawyeyebot |
| **Bot API** | https://core.telegram.org/bots/api |

### Bot Token (Store Securely)

```toml
# ~/.zeroclaw/secrets/telegram.toml (encrypted)
[telegram]
bot_token = "8156887004:AAHLQYaeNioR8KklRBiNDLGrgGoUE6Yzw-A"
```

> ⚠️ **Security Note**: Keep the bot token secure. It can be used by anyone to control your bot. Store encrypted via ZeroClaw's secrets system.

### Binding Telegram to ZeroClaw

After deployment, bind the Telegram bot:

```bash
# On the remote host
zeroclaw bind-telegram --token "8156887004:AAHLQYaeNioR8KklRBiNDLGrgGoUE6Yzw-A"

# Or set via environment variable
export TELEGRAM_BOT_TOKEN="8156887004:AAHLQYaeNioR8KklRBiNDLGrgGoUE6Yzw-A"
zeroclaw daemon
```

### Telegram Allowlist

Configure which users can interact with the bot:

```toml
# ~/.zeroclaw/config.toml
[telegram]
enabled = true
allowed_users = []  # Add your Telegram user ID after first interaction
# Get your user ID by messaging @userinfobot on Telegram
```

---

## Initial Deployment Prompt for Yew Dashboard

After `zeroclaw onboard` and `zeroclaw daemon` (or service start), run this one-time prompt via CLI or Telegram channel:

> "Upon first deploy, design and implement a full Yew-based web dashboard UI for myself:
> 
> 1. Create a new Cargo project in `~/zeroclaw-dashboard` (or workspace subdir).
> 2. Use Yew framework: clone https://github.com/yewstack/yew or use trunk new template.
> 3. Build SPA with these pages (use yew-router):
>    - **Dashboard Home**: Show agent status, uptime, recent tasks.
>    - **Memory Viewer**: Display recent memories from SQLite (fetch via gateway or tool).
>    - **Projects & Config**: Editable form for VuePress, Paragraph.com sites, secrets.
>    - **Workflows**: Buttons to trigger deploys and posts.
>    - **LLM Switcher**: Select provider/model, test prompt box.
>    - **Logs & Controls**: View recent logs, estop button.
> 4. Fetch data via HTTP to `http://127.0.0.1:42617`.
> 5. Use trunk for build/serve; add to `allowed_commands`: `['cargo', 'trunk', 'npm']`.
> 6. Serve on `localhost:8080` initially; suggest Cloudflare Tunnel exposure later.
> 7. Make responsive with Tailwind CSS.
> 8. Commit to git repo for version control."

---

## Yew Dashboard Architecture

### Pages Structure

| Page | Features |
|------|----------|
| **Overview/Status** | Real-time agent status, daemon health, uptime, CPU/RAM usage, heartbeat logs |
| **Memory & History** | Table/grid of memories from SQLite, charts, search/filter by keyword |
| **Projects & Secrets** | Editable forms for VuePress, Paragraph.com configs; encrypted storage |
| **Workflow Controls** | List cron jobs, enable/disable/run-now, manual triggers, logs viewer |
| **LLM & Provider Switcher** | Dropdown to change provider/model, test prompt box |
| **Security & Tools** | View/edit allowlists, estop button, browser tool preview |

### Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Yew + yew-router |
| **State** | yewdux |
| **HTTP** | Reqwest (wasm) |
| **Build** | Trunk |
| **Styling** | Tailwind CSS via trunk |
| **Charts** | Plotters or gloo-net (optional) |

### Security Notes

- Serve only on localhost initially (or via Tailscale/Cloudflare Tunnel)
- No direct secrets exposure in UI — use agent to read/write encrypted
- Start in supervised mode to approve file writes/builds

---

## Project Resources & Secrets Configuration

### `~/.zeroclaw/config.toml`

```toml
[projects.vuepress]
repo_path = "/home/ubuntu/workspace/vuepress-site"
git_remote = "origin"
branch = "main"
build_command = "npm run docs:build"
deploy_trigger = "git push origin main"  # Triggers Cloudflare Pages

[projects.paragraph_1]
api_endpoint = "https://api.paragraph.com/v1"
api_key = "para_sk_..."                   # Encrypted via [secrets].encrypt = true
publication_id = "pub-123456"
default_audience = "subscribers"
post_template = "Weekly Update - {date}"

[projects.paragraph_2]
# Same structure as above for second newsletter

[projects.general]
workspace_root = "/home/ubuntu/workspace"
backup_interval_minutes = 1440            # Daily backups via cron
notify_channel = "telegram"
notify_user_id = "123456789"
```

---

## Deployment Checklist

### Phase 1: Prerequisites
- [ ] Verify Tailscale connectivity to `zeroclaw.ruffe-court.ts.net`
- [ ] Install Rust toolchain (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- [ ] Install build dependencies (`build-essential`, `pkg-config`, `libssl-dev`)
- [ ] Install Git and configure SSH keys for GitHub
- [ ] (Optional) Install Docker for containerized deployment

### Phase 2: Clone and Build
- [ ] Clone repository: `git clone git@github.com:chancejiang/zeroclaw.git ~/zeroclaw`
- [ ] Build release binary: `cd ~/zeroclaw && cargo build --release`
- [ ] Verify binary: `./target/release/zeroclaw --version`

### Phase 3: Configuration
- [ ] Run onboarding: `zeroclaw onboard`
- [ ] Configure `~/.zeroclaw/config.toml` with projects and secrets
- [ ] Set autonomy level: `supervised` (initial)
- [ ] Configure allowed commands: `git`, `npm`, `cargo`, `trunk`
- [ ] Set up Telegram bot token and allowlist

### Phase 4: Service Setup
- [ ] Create systemd service file for `zeroclaw daemon`
- [ ] Enable and start service: `systemctl enable --now zeroclaw`
- [ ] Verify gateway on `http://127.0.0.1:42617`

### Phase 5: Network Exposure (Optional)
- [ ] Configure Cloudflare Tunnel for secure external access
- [ ] Or expose via Tailscale serve

### Phase 6: Yew Dashboard (Optional)
- [ ] Create dashboard project: `cargo new ~/zeroclaw-dashboard`
- [ ] Add Yew dependencies and configure Trunk
- [ ] Implement dashboard pages
- [ ] Build and serve on `localhost:8080`

---

## Quick Reference Commands

```bash
# SSH to node
ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Clone and build (using SSH with deploy key)
git clone git@github.com:chancejiang/zeroclaw.git ~/zeroclaw
cd ~/zeroclaw && cargo build --release

# Onboarding
./target/release/zeroclaw onboard

# Start daemon (foreground)
./target/release/zeroclaw daemon

# Check status
./target/release/zeroclaw status

# Emergency stop
./target/release/zeroclaw estop
```

---

## Cloudflare Configuration

| Parameter | Value |
|-----------|-------|
| **Domain** | `claw.chancejiang.com` |
| **Zone ID** | `5046df782e39f7fe09900418ef469faa` |
| **Account ID** | `b886c026d6e4b19ce09a786af91c4a91` |
| **Service** | ZeroClaw TG Bot + Web UI |
| **Status** | ✅ Deployed |

---

## SSH Keys

### `chance@claw` (Ed25519) - General Access

**Public Key:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILN3L2WnaTRlquBEQZw4uE2Hb7PsHdyFt2vlKgdn9Rqn chance@claw
```

**Fingerprint:** `SHA256:Z9C8zNZ24Rixqypk/YXvX/3YcxyryCS89+xhruFdf1I`

> 📁 Keys stored in `secrets/` directory (private key excluded from git)

### GitHub Deploy Key for `chancejiang/clawchance` (This Project)

**Public Key:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMNuyxk8ZAmJG4SQ4AlHQk9tZTI1zNv+F3ca6sWkD4Gl clawchance@github
```

**Fingerprint:** `SHA256:j/B1n20JRLm7cqsyVoODxQ+89TTxsa2n0OZU+0VCMEk`

**Repository:** `git@github.com:chancejiang/clawchance.git`

**Purpose:** Manage this project (claw.chancejiang.com deployment configs)

#### Setup Instructions

1. Go to https://github.com/chancejiang/clawchance/settings/keys
2. Click "Add deploy key"
3. Title: `clawchance-deploy`
4. Key: Paste the public key above
5. Check "Allow write access" for push capability
6. Click "Add key"

### GitHub Deploy Key for `chancejiang/zeroclaw` (Upstream Contributions)

**Public Key:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICVJ1rmoR5Ft9YiNfCxJX7k1ijx2jbx+iCs8pfn3Dwq5 github-deploy@zeroclaw
```

**Fingerprint:** `SHA256:vq8XAwKlm4B6WDowh8BF1DMCJGU9ArqoM4jQ0dBpGZk`

#### Setup Instructions

1. Go to https://github.com/chancejiang/zeroclaw/settings/keys
2. Click "Add deploy key"
3. Title: `zeroclaw-deploy`
4. Key: Paste the public key above
5. Check "Allow write access" if you need push access
6. Click "Add key"

#### Deploy to Remote Server

```bash
# Copy private key to remote server
ssh ubuntu@zeroclaw.ruffe-court.ts.net "mkdir -p ~/.ssh"
cat secrets/github-deploy | ssh ubuntu@zeroclaw.ruffe-court.ts.net "cat > ~/.ssh/github-deploy && chmod 600 ~/.ssh/github-deploy"

# Add to SSH config on remote
ssh ubuntu@zeroclaw.ruffe-court.ts.net 'cat >> ~/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github-deploy
    IdentitiesOnly yes
EOF'

# Test connection
ssh ubuntu@zeroclaw.ruffe-court.ts.net "ssh -T git@github.com"
```

### Wrangler CLI Commands

```bash
# List tunnels
wrangler tunnels list

# Create tunnel
wrangler tunnels create --name zeroclaw-web

# Configure tunnel routing
wrangler tunnels route add --tunnel <tunnel-id> --service http://localhost:42617
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SSH connection drops | Check Tailscale status: `tailscale status` |
| Build fails | Install missing deps: `sudo apt install build-essential pkg-config libssl-dev` |
| Gateway not responding | Check port 42617: `ss -tlnp | grep 42617` |
| Telegram not working | Verify bot token and run `bind-telegram` command |
| CF Tunnel issues | Check wrangler logs: `wrangler tunnels tail` |
</task_progress>
</write_to_file>
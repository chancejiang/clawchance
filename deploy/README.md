# ZeroClaw Deployment

Deployment scripts and configuration for ZeroClaw AI Agent on Tailscale node.

## Target Environment

| Parameter | Value |
|-----------|-------|
| **Host** | `ubuntu@zeroclaw.ruffe-court.ts.net` |
| **OS** | Ubuntu 24.04.4 LTS (Noble Numbat) |
| **Kernel** | 6.8.0-101-generic x86_64 |
| **Access** | Tailscale SSH |
| **Repository** | `git@github.com:opencaio/zeroclaw.git` |

## Quick Start

```bash
# Make the script executable
chmod +x deploy-zeroclaw.sh

# Run full deployment
./deploy-zeroclaw.sh all

# Or use make
make deploy
```

## Deployment Phases

| Phase | Description | Command |
|-------|-------------|---------|
| **prereq** | Install Rust, build dependencies | `./deploy-zeroclaw.sh prereq` |
| **clone** | Clone/update repository | `./deploy-zeroclaw.sh clone` |
| **build** | Build release binary | `./deploy-zeroclaw.sh build` |
| **config** | Setup initial configuration | `./deploy-zeroclaw.sh config` |
| **service** | Install systemd service | `./deploy-zeroclaw.sh service` |

## Makefile Commands

### Deployment

```bash
make deploy      # Full deployment
make prereq      # Install prerequisites only
make clone       # Clone/update repository
make build       # Build release binary
make config      # Setup configuration
make service     # Install systemd service
```

### Service Management

```bash
make status      # Check service status
make logs        # View logs (follow mode)
make start       # Start the service
make stop        # Stop the service
make restart     # Restart the service
```

### Quick Actions

```bash
make ssh         # SSH into remote host
make check       # Quick health check
make update      # Pull latest and rebuild
make estop       # Emergency stop
make show-config # View configuration
make edit-config # Edit configuration (nano)
```

### Maintenance

```bash
make clean       # Clean build artifacts
make reset       # Full reset (destructive!)
```

## File Structure

```
deploy/
├── README.md              # This file
├── Makefile               # Quick commands
├── deploy-zeroclaw.sh     # Main deployment script
└── systemd/
    └── zeroclaw.service   # Systemd service unit
```

## Remote Directory Structure

After deployment, the remote host will have:

```
/home/ubuntu/
├── zeroclaw/                    # Repository
│   ├── target/release/zeroclaw  # Binary
│   └── ...
├── .zeroclaw/                   # Configuration
│   ├── config.toml              # Main config
│   ├── memory.db                # SQLite memory
│   └── secrets/                 # Encrypted secrets
└── workspace/                   # Working directory
    ├── vuepress-site/           # VuePress project
    └── ...
```

## Configuration

The initial configuration is created at `~/.zeroclaw/config.toml`:

```toml
[agent]
autonomy = "supervised"  # readonly | supervised | full
workspace = "/home/ubuntu/workspace"

[tools]
enabled = ["shell", "file", "memory", "cron", "git", "http_request"]
allowed_commands = ["git", "npm", "cargo", "trunk", "node"]

[memory]
backend = "sqlite"

[gateway]
host = "127.0.0.1"
port = 42617
```

## Gateway Access

The ZeroClaw gateway runs on `http://127.0.0.1:42617` (localhost only).

### Access via Tailscale

```bash
# Port forward through SSH
ssh -L 42617:127.0.0.1:42617 ubuntu@zeroclaw.ruffe-court.ts.net

# Then access locally
curl http://127.0.0.1:42617/health
```

### Access via Tailscale Serve

On the remote host:
```bash
tailscale serve 42617
```

### Access via Cloudflare Tunnel

```bash
cloudflared tunnel --url http://localhost:42617
```

## Troubleshooting

### SSH Connection Issues

```bash
# Check Tailscale status
tailscale status

# Ping the host
ping zeroclaw.ruffe-court.ts.net
```

### Build Fails

```bash
# Install missing dependencies
ssh ubuntu@zeroclaw.ruffe-court.ts.net
sudo apt install build-essential pkg-config libssl-dev
```

### Service Won't Start

```bash
# Check logs
make logs

# Check service status
make status

# Manual start for debugging
ssh ubuntu@zeroclaw.ruffe-court.ts.net
~/zeroclaw/target/release/zeroclaw daemon
```

### Gateway Not Responding

```bash
# Check if port is bound
ssh ubuntu@zeroclaw.ruffe-court.ts.net "ss -tlnp | grep 42617"

# Check if service is running
ssh ubuntu@zeroclaw.ruffe-court.ts.net "sudo systemctl status zeroclaw"
```

## Post-Deployment

After successful deployment:

1. **Configure LLM Provider**: Edit `~/.zeroclaw/config.toml` with your API keys
2. **Setup Telegram**: Run `zeroclaw bind-telegram` with your bot token
3. **Start Service**: `make start`
4. **Verify Gateway**: `curl http://127.0.0.1:42617/health`
5. **Deploy Yew Dashboard** (optional): See SPECS.md for Yew dashboard setup

## Security Notes

- Service runs with `NoNewPrivileges=true`
- Home directory is read-only except for allowed paths
- Private `/tmp` is enabled
- Start with `supervised` autonomy level

## Related Documentation

- [SPECS.md](../.clinerules/SPECS.md) - Feature parity review and detailed specs
- [ZeroClaw Repository](https://github.com/opencaio/zeroclaw)
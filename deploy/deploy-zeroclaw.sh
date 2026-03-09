#!/bin/bash
#
# ZeroClaw Deployment Script
# Target: ubuntu@zeroclaw.ruffe-court.ts.net
# Repository: git@github.com:opencaio/zeroclaw.git
#
# Usage: ./deploy-zeroclaw.sh [phase]
# Phases: all | prereq | clone | build | config | service
#

set -e

# Configuration
REMOTE_HOST="ubuntu@zeroclaw.ruffe-court.ts.net"
REMOTE_DIR="$HOME/zeroclaw"
REPO_URL="git@github.com:opencaio/zeroclaw.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Run command on remote host
remote_run() {
    ssh "$REMOTE_HOST" "$1"
}

# Phase 1: Install Prerequisites
phase_prereq() {
    log_info "Phase 1: Installing prerequisites..."

    remote_run "
        # Update system
        sudo apt update

        # Install build dependencies
        sudo apt install -y build-essential pkg-config libssl-dev git curl

        # Install Rust if not present
        if ! command -v rustc &> /dev/null; then
            echo 'Installing Rust toolchain...'
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source \$HOME/.cargo/env
        fi

        # Verify installations
        echo '=== Installed versions ==='
        rustc --version || echo 'Rust not found'
        cargo --version || echo 'Cargo not found'
        git --version || echo 'Git not found'
        gcc --version | head -1 || echo 'GCC not found'
        pkg-config --version || echo 'pkg-config not found'
    "

    log_info "Prerequisites installed successfully!"
}

# Phase 2: Clone Repository
phase_clone() {
    log_info "Phase 2: Cloning ZeroClaw repository..."

    remote_run "
        # Create directory if not exists
        mkdir -p \$HOME/workspace

        # Clone or update repository
        if [ -d \"$REMOTE_DIR\" ]; then
            echo 'Repository exists, pulling latest changes...'
            cd \"$REMOTE_DIR\" && git pull
        else
            echo 'Cloning repository...'
            git clone \"$REPO_URL\" \"$REMOTE_DIR\"
        fi

        # Verify clone
        ls -la \"$REMOTE_DIR\"
    "

    log_info "Repository cloned successfully!"
}

# Phase 3: Build Release Binary
phase_build() {
    log_info "Phase 3: Building ZeroClaw release binary..."

    remote_run "
        source \$HOME/.cargo/env 2>/dev/null || true
        cd \"$REMOTE_DIR\"

        # Build release
        echo 'Building release binary (this may take a few minutes)...'
        cargo build --release

        # Verify build
        ls -lh target/release/zeroclaw 2>/dev/null || echo 'Binary not found!'
        ./target/release/zeroclaw --version 2>/dev/null || echo 'Could not get version'
    "

    log_info "Build completed successfully!"
}

# Phase 4: Initial Configuration
phase_config() {
    log_info "Phase 4: Setting up configuration..."

    remote_run "
        cd \"$REMOTE_DIR\"

        # Create config directory
        mkdir -p \$HOME/.zeroclaw

        # Run onboarding if binary exists
        if [ -f \"./target/release/zeroclaw\" ]; then
            echo 'Running ZeroClaw onboarding...'
            ./target/release/zeroclaw onboard --help 2>/dev/null || echo 'Onboarding requires interactive mode'
        fi

        # Create initial config.toml if not exists
        if [ ! -f \"\$HOME/.zeroclaw/config.toml\" ]; then
            echo 'Creating initial config.toml...'
            cat > \$HOME/.zeroclaw/config.toml << 'CONFIGEOF'
# ZeroClaw Configuration
# Edit this file to customize your setup

[agent]
autonomy = "supervised"  # readonly | supervised | full
workspace = "/home/ubuntu/.zeroclaw/workspace"

[tools]
enabled = ["shell", "file", "memory", "cron", "git", "http_request"]
allowed_commands = ["git", "npm", "cargo", "trunk", "node"]
forbidden_paths = ["/etc", "/root", "/.ssh"]

[memory]
backend = "sqlite"
path = "/home/ubuntu/.zeroclaw/memory.db"

[gateway]
host = "127.0.0.1"
port = 42617

[projects.vuepress]
repo_path = "/home/ubuntu/.zeroclaw/workspace/vuepress-site"
git_remote = "origin"
branch = "main"
build_command = "npm run docs:build"
deploy_trigger = "git push origin main"

[projects.general]
workspace_root = "/home/ubuntu/.zeroclaw/workspace"
notify_channel = "telegram"
CONFIGEOF
            echo 'Config file created at ~/.zeroclaw/config.toml'
        fi

        ls -la \$HOME/.zeroclaw/
    "

    log_info "Configuration setup completed!"
}

# Phase 5: Install Systemd Service
phase_service() {
    log_info "Phase 5: Installing systemd service..."

    remote_run "
        # Create systemd service file
        sudo tee /etc/systemd/system/zeroclaw.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=ZeroClaw AI Agent Daemon
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/zeroclaw
Environment=PATH=/home/ubuntu/.cargo/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/ubuntu/zeroclaw/target/release/zeroclaw daemon
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/ubuntu/.zeroclaw /home/ubuntu/workspace
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICEEOF

        # Reload systemd
        sudo systemctl daemon-reload

        # Enable service (don't start yet)
        sudo systemctl enable zeroclaw

        echo 'Service installed. Start with: sudo systemctl start zeroclaw'
        echo 'Check status with: sudo systemctl status zeroclaw'
    "

    log_info "Service installed successfully!"
}

# Phase 6: Verify Deployment
phase_verify() {
    log_info "Phase 6: Verifying deployment..."

    remote_run "
        echo '=== System Status ==='
        sudo systemctl status zeroclaw --no-pager || echo 'Service not running yet'

        echo ''
        echo '=== Gateway Check ==='
        curl -s http://127.0.0.1:42617/health 2>/dev/null || echo 'Gateway not responding (start service first)'

        echo ''
        echo '=== Disk Usage ==='
        df -h /home

        echo ''
        echo '=== Memory ==='
        free -h
    "

    log_info "Verification completed!"
}

# Show help
show_help() {
    echo "ZeroClaw Deployment Script"
    echo ""
    echo "Usage: $0 [phase]"
    echo ""
    echo "Phases:"
    echo "  all      - Run all phases (default)"
    echo "  prereq   - Install prerequisites (Rust, build deps)"
    echo "  clone    - Clone/update repository"
    echo "  build    - Build release binary"
    echo "  config   - Setup initial configuration"
    echo "  service  - Install systemd service"
    echo "  verify   - Verify deployment status"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all phases"
    echo "  $0 prereq       # Only install prerequisites"
    echo "  $0 build        # Only build binary"
    echo ""
    echo "Target: $REMOTE_HOST"
}

# Main
case "${1:-all}" in
    all)
        phase_prereq
        phase_clone
        phase_build
        phase_config
        phase_service
        phase_verify
        ;;
    prereq)  phase_prereq ;;
    clone)   phase_clone ;;
    build)   phase_build ;;
    config)  phase_config ;;
    service) phase_service ;;
    verify)  phase_verify ;;
    help|--help|-h) show_help ;;
    *)
        log_error "Unknown phase: $1"
        show_help
        exit 1
        ;;
esac

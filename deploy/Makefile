# ZeroClaw Deployment Makefile
# Quick commands for deploying and managing ZeroClaw
#
# Usage: make [target]

REMOTE_HOST := ubuntu@zeroclaw.ruffe-court.ts.net
REMOTE_DIR := ~/zeroclaw

.PHONY: all help ssh status logs start stop restart deploy prereq clone build config service

# Default target
all: deploy

# Help
help:
	@echo "ZeroClaw Deployment Commands"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy    - Full deployment (prereq + clone + build + config + service)"
	@echo "  prereq    - Install prerequisites only"
	@echo "  clone     - Clone/update repository"
	@echo "  build     - Build release binary"
	@echo "  config    - Setup initial configuration"
	@echo "  service   - Install systemd service"
	@echo ""
	@echo "Remote Management:"
	@echo "  ssh       - SSH into the remote host"
	@echo "  status    - Check service status"
	@echo "  logs      - View service logs"
	@echo "  start     - Start the service"
	@echo "  stop      - Stop the service"
	@echo "  restart   - Restart the service"
	@echo ""
	@echo "Quick Actions:"
	@echo "  check     - Quick health check"
	@echo "  update    - Pull latest and rebuild"
	@echo "  estop     - Emergency stop"
	@echo ""
	@echo "Target: $(REMOTE_HOST)"

# Full deployment
deploy:
	@echo "🚀 Starting full ZeroClaw deployment..."
	./deploy-zeroclaw.sh all

# Individual phases
prereq:
	./deploy-zeroclaw.sh prereq

clone:
	./deploy-zeroclaw.sh clone

build:
	./deploy-zeroclaw.sh build

config:
	./deploy-zeroclaw.sh config

service:
	./deploy-zeroclaw.sh service

# SSH into remote host
ssh:
	@echo "🔌 Connecting to $(REMOTE_HOST)..."
	ssh $(REMOTE_HOST)

# Service management
status:
	@echo "📊 Checking service status..."
	ssh $(REMOTE_HOST) "sudo systemctl status zeroclaw --no-pager"

logs:
	@echo "📜 Viewing logs (Ctrl+C to exit)..."
	ssh $(REMOTE_HOST) "sudo journalctl -u zeroclaw -f --no-pager"

start:
	@echo "▶️  Starting ZeroClaw service..."
	ssh $(REMOTE_HOST) "sudo systemctl start zeroclaw && sudo systemctl status zeroclaw --no-pager"

stop:
	@echo "⏹️  Stopping ZeroClaw service..."
	ssh $(REMOTE_HOST) "sudo systemctl stop zeroclaw"

restart:
	@echo "🔄 Restarting ZeroClaw service..."
	ssh $(REMOTE_HOST) "sudo systemctl restart zeroclaw && sudo systemctl status zeroclaw --no-pager"

# Quick health check
check:
	@echo "🔍 Running health check..."
	ssh $(REMOTE_HOST) "\
		echo '=== System ===' && \
		uname -a && \
		echo '' && \
		echo '=== Memory ===' && \
		free -h && \
		echo '' && \
		echo '=== Disk ===' && \
		df -h / && \
		echo '' && \
		echo '=== Service ===' && \
		sudo systemctl is-active zeroclaw 2>/dev/null || echo 'Not installed/running' && \
		echo '' && \
		echo '=== Gateway ===' && \
		curl -s http://127.0.0.1:42617/health 2>/dev/null || echo 'Not responding'"

# Update: pull latest code and rebuild
update:
	@echo "⬆️  Updating ZeroClaw..."
	ssh $(REMOTE_HOST) "\
		source ~/.cargo/env 2>/dev/null; \
		cd $(REMOTE_DIR) && \
		git pull && \
		cargo build --release && \
		echo 'Build complete. Restart with: make restart'"

# Emergency stop
estop:
	@echo "🚨 Emergency stop..."
	ssh $(REMOTE_HOST) "\
		sudo systemctl stop zeroclaw; \
		$(REMOTE_DIR)/target/release/zeroclaw estop 2>/dev/null || true; \
		echo 'Emergency stop executed'"

# View config
show-config:
	@echo "📄 Current configuration..."
	ssh $(REMOTE_HOST) "cat ~/.zeroclaw/config.toml 2>/dev/null || echo 'Config not found'"

# Edit config (requires interactive terminal)
edit-config:
	ssh -t $(REMOTE_HOST) "nano ~/.zeroclaw/config.toml"

# Install Rust toolchain on remote
install-rust:
	@echo "🦀 Installing Rust on remote host..."
	ssh $(REMOTE_HOST) "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Check if repository exists
check-repo:
	ssh $(REMOTE_HOST) "ls -la $(REMOTE_DIR) 2>/dev/null || echo 'Repository not found'"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	ssh $(REMOTE_HOST) "cd $(REMOTE_DIR) && cargo clean"

# Full reset (WARNING: destructive)
reset:
	@echo "⚠️  This will delete the ZeroClaw installation!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	ssh $(REMOTE_HOST) "\
		sudo systemctl stop zeroclaw 2>/dev/null; \
		sudo systemctl disable zeroclaw 2>/dev/null; \
		sudo rm -f /etc/systemd/system/zeroclaw.service; \
		sudo systemctl daemon-reload; \
		rm -rf $(REMOTE_DIR); \
		rm -rf ~/.zeroclaw; \
		echo 'ZeroClaw removed'"
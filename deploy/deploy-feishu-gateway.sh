#!/bin/bash
#
# Feishu Gateway Deployment Script
# Target: ubuntu@zeroclaw.ruffe-court.ts.net
#
# Usage: ./deploy-feishu-gateway.sh [command]
# Commands: deploy | build | backup | status | logs | restart | stop | start | help
#

set -e

# Configuration
REMOTE_HOST="ubuntu@zeroclaw.ruffe-court.ts.net"
REMOTE_DIR="/home/ubuntu/feishu-gateway"
LOCAL_DIR="$(cd "$(dirname "$0")/feishu-gateway" && pwd)"
BINARY_NAME="feishu-gateway"
SERVICE_NAME="feishu-gateway"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Run command on remote host
remote_run() {
    ssh "$REMOTE_HOST" "$1"
}

# Phase 1: Build the binary locally (cross-compile for Linux AMD64)
phase_build() {
    log_step "Building Feishu Gateway binary..."

    cd "$LOCAL_DIR"

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go 1.21 or higher."
        exit 1
    fi

    # Download dependencies
    log_info "Downloading Go dependencies..."
    go mod download

    # Cross-compile for Linux AMD64
    log_info "Cross-compiling for Linux AMD64..."
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o "$BINARY_NAME" main.go

    # Verify build
    if [ -f "$BINARY_NAME" ]; then
        BINARY_SIZE=$(ls -lh "$BINARY_NAME" | awk '{print $5}')
        log_info "Build successful! Binary size: $BINARY_SIZE"
    else
        log_error "Build failed! Binary not found."
        exit 1
    fi
}

# Phase 2: Create backup on remote server
phase_backup() {
    log_step "Creating backup on remote server..."

    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

    remote_run "
        if [ -f \"$REMOTE_DIR/$BINARY_NAME\" ]; then
            mkdir -p \"$REMOTE_DIR/backups\"
            cp \"$REMOTE_DIR/$BINARY_NAME\" \"$REMOTE_DIR/backups/$BINARY_NAME.$BACKUP_DATE\"
            echo \"Backup created: $BINARY_NAME.$BACKUP_DATE\"

            # Keep only last 5 backups
            cd \"$REMOTE_DIR/backups\"
            ls -t $BINARY_NAME.* 2>/dev/null | tail -n +6 | xargs -r rm -f
            echo \"Old backups cleaned. Current backups:\"
            ls -lh $BINARY_NAME.* 2>/dev/null || echo 'No backups found'
        else
            echo 'No existing binary to backup'
        fi
    "

    log_info "Backup completed!"
}

# Phase 3: Deploy binary to remote server
phase_deploy() {
    log_step "Deploying to remote server..."

    # Build first if binary doesn't exist locally
    if [ ! -f "$LOCAL_DIR/$BINARY_NAME" ]; then
        log_info "Binary not found locally, building..."
        phase_build
    fi

    # Create backup
    phase_backup

    # Stop service before deploying
    log_info "Stopping service..."
    remote_run "sudo systemctl stop $SERVICE_NAME 2>/dev/null || true"

    # Create remote directory if needed
    remote_run "mkdir -p $REMOTE_DIR"

    # Copy binary
    log_info "Copying binary to server..."
    scp "$LOCAL_DIR/$BINARY_NAME" "$REMOTE_HOST:$REMOTE_DIR/$BINARY_NAME"

    # Copy .env if it exists locally (usually it doesn't for security)
    if [ -f "$LOCAL_DIR/.env" ]; then
        log_info "Copying .env file..."
        scp "$LOCAL_DIR/.env" "$REMOTE_HOST:$REMOTE_DIR/.env"
    fi

    # Copy service file if it exists
    if [ -f "$LOCAL_DIR/$SERVICE_NAME.service" ]; then
        log_info "Copying service file..."
        scp "$LOCAL_DIR/$SERVICE_NAME.service" "$REMOTE_HOST:$REMOTE_DIR/$SERVICE_NAME.service"

        # Install service if not already installed
        remote_run "
            if [ ! -f /etc/systemd/system/$SERVICE_NAME.service ]; then
                sudo cp $REMOTE_DIR/$SERVICE_NAME.service /etc/systemd/system/
                sudo systemctl daemon-reload
                sudo systemctl enable $SERVICE_NAME
                echo 'Service installed and enabled'
            fi
        "
    fi

    # Set permissions
    remote_run "
        chmod +x $REMOTE_DIR/$BINARY_NAME
        chmod 600 $REMOTE_DIR/.env 2>/dev/null || true
    "

    log_info "Deployment completed!"
}

# Phase 4: Start service and verify
phase_start() {
    log_step "Starting service..."

    remote_run "
        sudo systemctl start $SERVICE_NAME
        sleep 2
        sudo systemctl status $SERVICE_NAME --no-pager
    "

    log_info "Service started!"
}

# Phase 5: Full deploy (build + deploy + start)
phase_full_deploy() {
    log_info "🚀 Starting full Feishu Gateway deployment..."
    echo ""

    phase_build
    echo ""

    phase_deploy
    echo ""

    phase_start
    echo ""

    log_info "✅ Full deployment completed!"
    echo ""
    echo "Useful commands:"
    echo "  ./deploy-feishu-gateway.sh logs     # View logs"
    echo "  ./deploy-feishu-gateway.sh status   # Check status"
    echo "  ./deploy-feishu-gateway.sh restart  # Restart service"
}

# Quick update (deploy + restart, skip build)
phase_quick_update() {
    log_info "⚡ Quick update (deploying existing binary)..."

    if [ ! -f "$LOCAL_DIR/$BINARY_NAME" ]; then
        log_error "Binary not found! Run './deploy-feishu-gateway.sh deploy' for full deployment."
        exit 1
    fi

    phase_deploy
    phase_start

    log_info "✅ Quick update completed!"
}

# Service management
phase_stop() {
    log_info "Stopping service..."
    remote_run "sudo systemctl stop $SERVICE_NAME"
    log_info "Service stopped."
}

phase_restart() {
    log_info "Restarting service..."
    remote_run "sudo systemctl restart $SERVICE_NAME && sleep 2 && sudo systemctl status $SERVICE_NAME --no-pager"
}

phase_status() {
    remote_run "sudo systemctl status $SERVICE_NAME --no-pager"
}

phase_logs() {
    log_info "Viewing logs (Ctrl+C to exit)..."
    remote_run "sudo journalctl -u $SERVICE_NAME -f --no-pager"
}

phase_logs_recent() {
    log_info "Recent logs..."
    remote_run "sudo journalctl -u $SERVICE_NAME -n 100 --no-pager"
}

# SSH into remote
phase_ssh() {
    log_info "Connecting to remote host..."
    ssh "$REMOTE_HOST"
}

# Check prerequisites
phase_check() {
    log_step "Checking prerequisites..."

    echo ""
    echo "Local environment:"
    echo "  Go version: $(go version 2>/dev/null || echo 'Not installed')"
    echo "  Local directory: $LOCAL_DIR"
    echo "  Binary exists: $([ -f "$LOCAL_DIR/$BINARY_NAME" ] && echo 'Yes' || echo 'No')"

    echo ""
    echo "Remote environment:"
    remote_run "
        echo '  Host: $REMOTE_HOST'
        echo '  Service status:' \$(sudo systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'Not installed')
        echo '  Binary exists:' \$([ -f '$REMOTE_DIR/$BINARY_NAME' ] && echo 'Yes' || echo 'No')
        echo '  .env exists:' \$([ -f '$REMOTE_DIR/.env' ] && echo 'Yes' || echo 'No')
    "
}

# Show help
show_help() {
    echo "Feishu Gateway Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy       - Full deployment (build + deploy + start)"
    echo "  build        - Build binary locally only"
    echo "  backup       - Create backup on remote server"
    echo "  update       - Quick update (deploy existing binary + restart)"
    echo ""
    echo "Service Management:"
    echo "  start        - Start the service"
    echo "  stop         - Stop the service"
    echo "  restart      - Restart the service"
    echo "  status       - Check service status"
    echo ""
    echo "Logs:"
    echo "  logs         - View logs in real-time (follow)"
    echo "  logs-recent  - View recent logs (last 100 lines)"
    echo ""
    echo "Other:"
    echo "  ssh          - SSH into remote host"
    echo "  check        - Check prerequisites and status"
    echo "  help         - Show this help message"
    echo ""
    echo "Target: $REMOTE_HOST"
    echo "Remote directory: $REMOTE_DIR"
    echo ""
    echo "Examples:"
    echo "  $0 deploy          # Full deployment"
    echo "  $0 logs            # View real-time logs"
    echo "  $0 restart         # Restart the service"
}

# Main
case "${1:-deploy}" in
    deploy)
        phase_full_deploy
        ;;
    build)
        phase_build
        ;;
    backup)
        phase_backup
        ;;
    update)
        phase_quick_update
        ;;
    start)
        phase_start
        ;;
    stop)
        phase_stop
        ;;
    restart)
        phase_restart
        ;;
    status)
        phase_status
        ;;
    logs)
        phase_logs
        ;;
    logs-recent)
        phase_logs_recent
        ;;
    ssh)
        phase_ssh
        ;;
    check)
        phase_check
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

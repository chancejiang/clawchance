#!/bin/bash
# Setup ZeroClaw on remote server

set -e
REMOTE="ubuntu@zeroclaw.ruffe-court.ts.net"
CONFIG_DIR="/home/ubuntu/.zeroclaw"
BINARY="/home/ubuntu/zeroclaw/target/release/zeroclaw"

echo "=== ZeroClaw Setup Script ==="

# Wait for build to complete
check_build() {
    for i in {1..30}; do
        if [ -f "$BINARY" ]; then
            echo "Build complete!"
            return 0
        fi
        echo "Waiting for build to complete... ($i/30)"
        sleep 10
    done
    echo "Build did not complete in time"
    return 1
}

# Check if build is complete
if ! check_build; then
    echo "Error: Build failed or timed out"
    exit 1
fi

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create config file
cat > "$CONFIG_DIR/config.toml" << 'EOF'
[llm]
provider = "openai"
base_url = "https://open.bigmodel.cn/api/coding/paas/v4"
model = "glm-4-flash"
api_key = "259cff168b9c4d3ebfe3735c5a4fe1dc.gKrV4HRU0d149Xkp"

[telegram]
enabled = true
bot_token = "8156887004:AAHLQYaeNioR8KklRBiNDLGrgGoUE6Yzw-A"
allowed_users = []

[agent]
autonomy = "supervised"
workspace = "/home/ubuntu/workspace"

[tools]
allowed_commands = ["git", "npm", "yarn", "cargo", "trunk", "python3"]

[memory]
backend = "sqlite"
path = "/home/ubuntu/.zeroclaw/memory.db"

[gateway]
port = 42617
bind = "127.0.0.1"
EOF

echo "Config file created"

# Copy systemd service
cat > /tmp/zeroclaw.service << 'EOF'
[Unit]
Description=ZeroClaw AI Assistant Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu

[Service]
Environment=EnvironmentFile=/home/ubuntu/.zeroclaw/config.toml
ExecStart=/home/ubuntu/zeroclaw/target/release/zeroclaw daemon

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/zeroclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable zeroclaw.service
sudo systemctl start zeroclaw.service

echo "=== ZeroClaw Setup Complete ==="
echo "Service started. Checking status..."
sudo systemctl status zeroclaw.service
EOF

chmod +x /tmp/setup-zeroclaw.sh
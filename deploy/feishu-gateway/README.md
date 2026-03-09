# Feishu Gateway

A WebSocket-based gateway that connects Feishu (飞书) bot messages to ZeroClaw AI backend for intelligent responses.

## Features

- 🚀 WebSocket long connection for real-time message handling
- 🤖 Automatic bot event handling (add/remove from chats)
- 🦀 Integration with ZeroClaw AI webhook
- 🔄 Auto-reconnect on connection failure
- 📝 Proper error handling and logging
- ⚡ systemd service for production deployment

## Architecture

```
Feishu Server ←──WebSocket──→ Feishu Gateway ←──HTTP──→ ZeroClaw AI
                                     │
                                     ├── Event Handlers
                                     │   ├── Message Receive
                                     │   ├── Bot Added
                                     │   └── Bot Removed
                                     │
                                     └── API Client
                                         └── Send Replies
```

## Prerequisites

- Go 1.21 or higher
- Feishu App ID and App Secret
- ZeroClaw webhook endpoint
- Ubuntu server (for production deployment)

## Configuration

Create a `.env` file in the project root:

```bash
# Required
FEISHU_APP_ID=cli_xxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx

# Optional
ZEROCLAW_WEBHOOK_URL=http://127.0.0.1:42617/webhook
LOG_LEVEL=info  # or "debug"
```

## Local Development

### 1. Clone and Setup

```bash
cd /path/to/feishu-gateway
cp .env.example .env
# Edit .env with your credentials
```

### 2. Install Dependencies

```bash
go mod download
```

### 3. Run

```bash
go run main.go
```

### 4. Build

```bash
go build -o feishu-gateway
```

## Production Deployment

### 1. Build the Binary

```bash
# On your local machine
GOOS=linux GOARCH=amd64 go build -o feishu-gateway

# Or build on the server directly
go build -o feishu-gateway
```

### 2. Deploy to Server

```bash
# Create directory on server
ssh ubuntu@zeroclaw.ruffe-court.ts.net "mkdir -p ~/feishu-gateway"

# Copy files to server
scp feishu-gateway ubuntu@zeroclaw.ruffe-court.ts.net:~/feishu-gateway/
scp .env ubuntu@zeroclaw.ruffe-court.ts.net:~/feishu-gateway/
scp feishu-gateway.service ubuntu@zeroclaw.ruffe-court.ts.net:~/feishu-gateway/
```

### 3. Install as systemd Service

```bash
ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Copy service file
sudo cp ~/feishu-gateway/feishu-gateway.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start
sudo systemctl enable feishu-gateway
sudo systemctl start feishu-gateway
```

### 4. Verify Service

```bash
# Check status
sudo systemctl status feishu-gateway

# View logs
sudo journalctl -u feishu-gateway -f

# Restart if needed
sudo systemctl restart feishu-gateway
```

## systemd Service Management

### View Status
```bash
sudo systemctl status feishu-gateway
```

### Start/Stop/Restart
```bash
sudo systemctl start feishu-gateway
sudo systemctl stop feishu-gateway
sudo systemctl restart feishu-gateway
```

### View Logs
```bash
# Follow logs in real-time
sudo journalctl -u feishu-gateway -f

# View recent logs
sudo journalctl -u feishu-gateway -n 100

# View logs from specific time
sudo journalctl -u feishu-gateway --since "1 hour ago"
```

### Enable/Disable Auto-start
```bash
sudo systemctl enable feishu-gateway   # Auto-start on boot
sudo systemctl disable feishu-gateway  # Don't auto-start
```

## Troubleshooting

### Service Won't Start

1. Check logs:
   ```bash
   sudo journalctl -u feishu-gateway -n 50
   ```

2. Verify environment variables:
   ```bash
   cat ~/feishu-gateway/.env
   ```

3. Check if port is already in use:
   ```bash
   sudo netstat -tulpn | grep :42617
   ```

### WebSocket Connection Issues

1. Check Feishu App credentials:
   - App ID format: `cli_xxxxxxxxxxxx`
   - App Secret should be 32+ characters

2. Verify network connectivity:
   ```bash
   # Test connection to ZeroClaw webhook
   curl -X POST http://127.0.0.1:42617/webhook \
     -H "Content-Type: application/json" \
     -d '{"message":"test"}'
   ```

### Bot Not Responding

1. Check if bot is added to the chat
2. Verify message type (only text messages are handled)
3. Check ZeroClaw webhook logs

### Debug Mode

Enable debug logging:
```bash
# Edit .env file
nano ~/feishu-gateway/.env

# Change:
LOG_LEVEL=debug

# Restart service
sudo systemctl restart feishu-gateway
```

## Logs

The service logs to systemd journal. Key log patterns:

- 📩 Message received
- 🤖 Bot added/removed
- 🦀 ZeroClaw response
- ✅ Successful reply
- ❌ Error occurred
- 🚀 Service started
- 🛑 Service stopped

## File Structure

```
feishu-gateway/
├── main.go                  # Main application code
├── go.mod                   # Go module definition
├── go.sum                   # Dependency checksums
├── .env                     # Environment variables (not in git)
├── .env.example             # Example environment file
├── feishu-gateway.service   # systemd service definition
├── feishu-gateway           # Compiled binary
└── README.md                # This file
```

## Security Notes

- Never commit `.env` file to version control
- Use environment variables for secrets
- Ensure `.env` file has restricted permissions: `chmod 600 .env`
- ZeroClaw webhook should be accessible only from localhost

## Updating

### Update Code
```bash
# Pull latest changes
git pull

# Rebuild
go build -o feishu-gateway

# Deploy and restart
scp feishu-gateway ubuntu@zeroclaw.ruffe-court.ts.net:~/feishu-gateway/
ssh ubuntu@zeroclaw.ruffe-court.ts.net "sudo systemctl restart feishu-gateway"
```

### Update Dependencies
```bash
go mod tidy
go mod download
```

## Development

### Code Quality

The codebase follows Go best practices:

- Proper error handling with context
- Defensive nil checks for all pointer dereferences
- Context propagation for cancellation
- Graceful shutdown handling
- Idiomatic use of Feishu SDK v3

### Key Components

1. **Config**: Environment variable loading
2. **FeishuGateway**: Main gateway struct with clients
3. **handleMessage**: Process incoming messages
4. **handleBotAdded/Removed**: Bot lifecycle events
5. **callZeroClaw**: Forward messages to AI backend
6. **replyMessage**: Send responses back to Feishu

## License

MIT License

## Support

For issues or questions:
1. Check the logs: `sudo journalctl -u feishu-gateway -f`
2. Review this README
3. Check Feishu SDK documentation: https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/server-side-sdk/golang-sdk-guide/preparations
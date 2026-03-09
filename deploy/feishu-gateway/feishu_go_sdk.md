# Feishu Go SDK Integration Plan for ZeroClaw

## Learning Summary

### SDK Overview

The Feishu Go SDK (`github.com/larksuite/oapi-sdk-go`) is a comprehensive server-side SDK that provides:

1. **Long Connection (WebSocket)** - `ws` package for real-time event subscription without public webhook endpoints
2. **HTTP API Client** - Standard client for calling Feishu APIs
3. **Event Dispatcher** - Handle various Feishu events (messages, contacts, approvals, etc.)
4. **Card Handler** - Process interactive card callbacks

### Key Components

| Component | Package | Purpose |
|-----------|---------|---------|
| WebSocket Client | `ws` | Long connection for receiving events |
| Event Dispatcher | `event/dispatcher` | Route and handle events |
| API Client | `client` | Call Feishu APIs |
| IM Service | `service/im` | Messaging APIs |
| Contact Service | `service/contact` | User/department management |
| Card Kit | `cardkit` | Interactive message cards |

---

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      ZeroClaw (Rust)                            │
│                   zeroclaw.ruffe-court.ts.net                   │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ FFI / IPC / HTTP
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                 Feishu Go Gateway Service                        │
│                    (New Go Service)                              │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  WebSocket Client│    │   API Client     │                   │
│  │  (Long Connection│    │  (HTTP Client)   │                   │
│  │   for Events)    │    │                  │                   │
│  └────────┬─────────┘    └────────┬─────────┘                   │
│           │                       │                              │
│           │              ┌────────▼─────────┐                    │
│           │              │  Message Handler │                    │
│           │              │  - Send messages │                    │
│           │              │  - Upload files  │                    │
│           │              │  - Create chats  │                    │
│           │              └──────────────────┘                    │
│           │                                                       │
│  ┌────────▼─────────┐                                            │
│  │ Event Dispatcher │                                            │
│  │ - OnMessage      │                                            │
│  │ - OnAddBot       │                                            │
│  │ - OnCardAction   │                                            │
│  └──────────────────┘                                            │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ WebSocket Long Connection
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                      Feishu Server                               │
│                   open.feishu.cn                                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Create Feishu Gateway Service

Create a new Go service that acts as a Feishu gateway:

```
~/zeroclaw/feishu-gateway/
├── main.go              # Entry point
├── config/
│   └── config.go        # Configuration management
├── wsclient/
│   └── client.go        # WebSocket long connection client
├── handlers/
│   ├── message.go       # Message event handlers
│   ├── card.go          # Card action handlers
│   └── bot.go           # Bot lifecycle handlers
├── api/
│   ├── message.go       # Message sending APIs
│   └── contact.go       # Contact APIs
└── bridge/
    └── zeroclaw.go      # Communication with ZeroClaw Rust core
```

### Phase 2: WebSocket Long Connection Setup

The `ws` package provides WebSocket long connection support. Key features:
- **No public endpoint required** - Events are pushed via WebSocket
- **Auto-reconnect** - Built-in reconnection with configurable retry
- **Ping/Pong** - Keepalive mechanism (default 2 minutes)

#### Basic Long Connection Code

```go
package main

import (
    "context"
    "fmt"
    "os"
    
    larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
    "github.com/larksuite/oapi-sdk-go/v3/event/dispatcher"
    larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
    larkws "github.com/larksuite/oapi-sdk-go/v3/ws"
)

func main() {
    // 1. Create event dispatcher
    eventHandler := dispatcher.NewEventDispatcher("", "").
        // Handle message receive event
        OnP2MessageReceiveV1(func(ctx context.Context, event *larkim.P2MessageReceiveV1) error {
            fmt.Printf("Received message: %s\n", larkcore.Prettify(event))
            return handleMessage(ctx, event)
        }).
        // Handle bot added to chat
        OnP1AddBotV1(func(ctx context.Context, event *larkim.P1AddBotV1) error {
            fmt.Printf("Bot added to chat: %s\n", larkcore.Prettify(event))
            return nil
        }).
        // Handle bot removed from chat
        OnP1RemoveBotV1(func(ctx context.Context, event *larkim.P1RemoveBotV1) error {
            fmt.Printf("Bot removed: %s\n", larkcore.Prettify(event))
            return nil
        })
    
    // 2. Create WebSocket client
    wsClient := larkws.NewClient(
        os.Getenv("FEISHU_APP_ID"),
        os.Getenv("FEISHU_APP_SECRET"),
        larkws.WithEventHandler(eventHandler),
        larkws.WithLogLevel(larkcore.LogLevelDebug),
        larkws.WithAutoReconnect(true),  // Auto-reconnect on disconnect
    )
    
    // 3. Start long connection (blocks)
    err := wsClient.Start(context.Background())
    if err != nil {
        panic(err)
    }
}
```

### Phase 3: API Client for Sending Messages

Use the standard API client to send messages and call other APIs:

```go
package api

import (
    "context"
    
    lark "github.com/larksuite/oapi-sdk-go/v3"
    larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
)

type FeishuClient struct {
    client *lark.Client
}

func NewFeishuClient(appID, appSecret string) *FeishuClient {
    return &FeishuClient{
        client: lark.NewClient(appID, appSecret),
    }
}

// SendTextMessage sends a text message to a chat
func (f *FeishuClient) SendTextMessage(ctx context.Context, receiveID, text string) error {
    // Build text content
    content := larkim.NewTextMsgBuilder().
        Text(text).
        Build()
    
    // Create and send message
    resp, err := f.client.Im.Message.Create(ctx,
        larkim.NewCreateMessageReqBuilder().
            ReceiveIdType(larkim.ReceiveIdTypeChatId).
            Body(larkim.NewCreateMessageReqBodyBuilder().
                MsgType(larkim.MsgTypeText).
                ReceiveId(receiveID).
                Content(content).
                Build()).
            Build())
    
    if err != nil {
        return err
    }
    
    if !resp.Success() {
        return fmt.Errorf("send message failed: %s", resp.Msg)
    }
    
    return nil
}

// SendReplyMessage replies to a message
func (f *FeishuClient) SendReplyMessage(ctx context.Context, messageID, text string) error {
    content := larkim.NewTextMsgBuilder().
        Text(text).
        Build()
    
    resp, err := f.client.Im.Message.Reply(ctx,
        larkim.NewReplyMessageReqBuilder().
            MessageId(messageID).
            Body(larkim.NewReplyMessageReqBodyBuilder().
                MsgType(larkim.MsgTypeText).
                Content(content).
                Build()).
            Build())
    
    if err != nil {
        return err
    }
    
    if !resp.Success() {
        return fmt.Errorf("reply message failed: %s", resp.Msg)
    }
    
    return nil
}
```

### Phase 4: Message Handler Implementation

Process incoming messages and integrate with ZeroClaw AI:

```go
package handlers

import (
    "context"
    "encoding/json"
    "fmt"
    
    larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
    larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
)

type MessageHandler struct {
    feishuClient *api.FeishuClient
    zeroclaw     *bridge.ZeroClawBridge
}

func (h *MessageHandler) HandleMessage(ctx context.Context, event *larkim.P2MessageReceiveV1) error {
    // Extract message info
    messageID := *event.Event.Message.MessageId
    chatID := *event.Event.Message.ChatId
    senderID := event.Event.Sender.SenderId.UserId
    
    // Parse message content
    msgType := *event.Event.Message.MessageType
    content := *event.Event.Message.Content
    
    // Only handle text messages
    if msgType != "text" {
        return nil
    }
    
    // Parse text content
    var textContent struct {
        Text string `json:"text"`
    }
    if err := json.Unmarshal([]byte(content), &textContent); err != nil {
        return err
    }
    
    fmt.Printf("Message from %s: %s\n", *senderID, textContent.Text)
    
    // Forward to ZeroClaw AI for processing
    response, err := h.zeroclaw.ProcessMessage(ctx, &bridge.MessageRequest{
        UserID:    *senderID,
        ChatID:    chatID,
        Message:   textContent.Text,
        MessageID: messageID,
    })
    if err != nil {
        return err
    }
    
    // Send AI response back
    return h.feishuClient.SendReplyMessage(ctx, messageID, response)
}
```

### Phase 5: Interactive Card Messages

Create interactive cards for rich UI:

```go
package api

import (
    larkcard "github.com/larksuite/oapi-sdk-go/v3/card"
)

// SendInteractiveCard sends an interactive card message
func (f *FeishuClient) SendInteractiveCard(ctx context.Context, chatID, title, content string) error {
    // Build card
    card := larkcard.NewMessageCard().
        Config(larkcard.NewMessageCardConfig().
            WideScreenMode(true).
            Build()).
        Header(larkcard.NewMessageCardHeader().
            Template(larkcard.TemplateBlue).
            Title(larkcard.NewMessageCardPlainText().
                Content(title).
                Build()).
            Build()).
        Elements([]larkcard.MessageCardElement{
            larkcard.NewMessageCardDiv().
                Text(larkcard.NewMessageCardLarkMd().
                    Content(content).
                    Build()).
                Build(),
        }).
        Build()
    
    // Convert to JSON string
    cardContent, _ := json.Marshal(card)
    
    resp, err := f.client.Im.Message.Create(ctx,
        larkim.NewCreateMessageReqBuilder().
            ReceiveIdType(larkim.ReceiveIdTypeChatId).
            Body(larkim.NewCreateMessageReqBodyBuilder().
                MsgType(larkim.MsgTypeInteractive).
                ReceiveId(chatID).
                Content(string(cardContent)).
                Build()).
            Build())
    
    if err != nil {
        return err
    }
    
    if !resp.Success() {
        return fmt.Errorf("send card failed: %s", resp.Msg)
    }
    
    return nil
}
```

---

## Configuration

### Environment Variables

```bash
# Feishu App Credentials
FEISHU_APP_ID=cli_a9273cb060f85cb0
FEISHU_APP_SECRET=<from-secure-storage>

# Optional: Custom domain (default: open.feishu.cn)
FEISHU_DOMAIN=open.feishu.cn

# Log level: debug, info, warn, error
FEISHU_LOG_LEVEL=info

# ZeroClaw bridge endpoint
ZEROCLAW_BRIDGE_URL=http://localhost:42617
```

### App Configuration in Feishu Developer Console

Based on `workspace/FEISHU_CONFIG.md`:

| Setting | Value |
|---------|-------|
| App ID | `cli_a9273cb060f85cb0` |
| Bot Name | ClawPapa |
| Event Subscription | Use Long Connection (WebSocket) |
| Message Capabilities | Enable |

**Required Permissions:**
- `im:message` - Receive and send messages
- `im:message:send_as_bot` - Send messages as bot
- `contact:user.base:readonly` - Get user basic info
- `im:chat` - Chat management

---

## Deployment Steps

### Step 1: Prepare the SDK

```bash
# On zeroclaw node
ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Clone the Feishu SDK (or use the forked version)
cd ~/skills
git clone git@github.com:chancefcc/oapi-sdk-go.git
# Or use the existing one in the project
```

### Step 2: Create Feishu Gateway Service

```bash
mkdir -p ~/zeroclaw/feishu-gateway
cd ~/zeroclaw/feishu-gateway

# Initialize Go module
go mod init github.com/chancejiang/zeroclaw/feishu-gateway

# Add SDK dependency
go get github.com/larksuite/oapi-sdk-go/v3@latest
```

### Step 3: Set Up Credentials

```bash
# Store credentials securely
export FEISHU_APP_ID="cli_a9273cb060f85cb0"
export FEISHU_APP_SECRET="<your-app-secret>"

# Or use a .env file with proper permissions
echo "FEISHU_APP_ID=cli_a9273cb060f85cb0" > .env
echo "FEISHU_APP_SECRET=<your-app-secret>" >> .env
chmod 600 .env
```

### Step 4: Configure Feishu App

1. Go to [Feishu Developer Console](https://open.feishu.cn/app/cli_a9273cb060f85cb0)
2. Navigate to **Event Subscription**
3. **Do NOT set a webhook URL** - We use long connection
4. Enable the following events:
   - `im.message.receive_v1` - Receive messages
   - `im.chat.member_added_v1` - User added to chat
   - `im.chat.member_deleted_v1` - User removed from chat

### Step 5: Build and Run

```bash
# Build
go build -o feishu-gateway ./main.go

# Run with systemd (recommended)
sudo systemctl enable feishu-gateway
sudo systemctl start feishu-gateway
```

### Step 6: Create Systemd Service

```bash
sudo tee /etc/systemd/system/feishu-gateway.service > /dev/null <<EOF
[Unit]
Description=Feishu Gateway for ZeroClaw
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/zeroclaw/feishu-gateway
ExecStart=/home/ubuntu/zeroclaw/feishu-gateway/feishu-gateway
Restart=always
RestartSec=5
Environment=FEISHU_APP_ID=cli_a9273cb060f85cb0
EnvironmentFile=/home/ubuntu/zeroclaw/feishu-gateway/.env

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable feishu-gateway
sudo systemctl start feishu-gateway
```

---

## ZeroClaw Bridge Integration

### Bridge Interface

The Go gateway needs to communicate with ZeroClaw Rust core. Options:

1. **HTTP Bridge** - ZeroClaw exposes an HTTP API
2. **gRPC** - Use gRPC for efficient communication
3. **Unix Socket** - For local IPC

#### HTTP Bridge Example

```go
package bridge

import (
    "bytes"
    "context"
    "encoding/json"
    "net/http"
)

type ZeroClawBridge struct {
    baseURL string
}

type MessageRequest struct {
    UserID    string `json:"user_id"`
    ChatID    string `json:"chat_id"`
    Message   string `json:"message"`
    MessageID string `json:"message_id"`
}

func (b *ZeroClawBridge) ProcessMessage(ctx context.Context, req *MessageRequest) (string, error) {
    body, _ := json.Marshal(req)
    
    httpReq, err := http.NewRequestWithContext(ctx, "POST", b.baseURL+"/chat", bytes.NewReader(body))
    if err != nil {
        return "", err
    }
    
    httpReq.Header.Set("Content-Type", "application/json")
    
    resp, err := http.DefaultClient.Do(httpReq)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()
    
    var result struct {
        Response string `json:"response"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return "", err
    }
    
    return result.Response, nil
}
```

---

## Key Benefits of Long Connection

1. **No Public Endpoint Required** - Perfect for internal services without public IPs
2. **No Cloudflare Tunnel Needed** - Events come via WebSocket, not HTTP webhook
3. **Automatic Reconnection** - Built-in retry logic
4. **Lower Latency** - Persistent connection vs HTTP polling
5. **Simpler Firewall Rules** - Only outbound WebSocket needed

---

## Monitoring and Logging

### Health Check Endpoint

```go
// Add a simple HTTP health check server
func startHealthServer() {
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })
    go http.ListenAndServe(":8080", nil)
}
```

### Logging

The SDK provides built-in logging:

```go
// Enable debug logging
wsClient := larkws.NewClient(
    appID, appSecret,
    larkws.WithEventHandler(eventHandler),
    larkws.WithLogLevel(larkcore.LogLevelDebug),
)
```

---

## Testing

### Local Testing

```bash
# Run locally with environment variables
FEISHU_APP_ID=cli_a9273cb060f85cb0 \
FEISHU_APP_SECRET=<secret> \
go run main.go
```

### Send Test Message

1. Open Feishu app
2. Search for "ClawPapa" bot
3. Send a message
4. Check logs for received event

---

## Summary

This integration plan enables ZeroClaw to:

1. ✅ Receive Feishu messages via **WebSocket long connection**
2. ✅ Process messages with ZeroClaw AI
3. ✅ Send text and card messages back to Feishu
4. ✅ No public webhook endpoint required
5. ✅ Auto-reconnect on network issues

### Next Steps for Implementation

1. [ ] Create the `feishu-gateway` Go service structure
2. [ ] Implement WebSocket client with event handlers
3. [ ] Implement message sending APIs
4. [ ] Create ZeroClaw bridge (HTTP/gRPC)
5. [ ] Set up systemd service
6. [ ] Test message flow end-to-end
7. [ ] Add monitoring and logging
8. [ ] Document API for future enhancements

---

## References

- SDK Location: `skills/oapi-sdk-go/`
- WebSocket Sample: `skills/oapi-sdk-go/sample/ws/sample.go`
- IM API Sample: `skills/oapi-sdk-go/sample/api/im/im.go`
- Event Sample: `skills/oapi-sdk-go/sample/event/event.go`
- Feishu Config: `workspace/FEISHU_CONFIG.md`

---

*Plan created: 2025-01-09*
*SDK Version: v3 (github.com/larksuite/oapi-sdk-go/v3)*
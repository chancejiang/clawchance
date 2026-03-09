# 🦀 Feishu Bot Skill (SKILL.md)

This skill enables **ZeroClaw** to interface with the Feishu (Lark) Open Platform via **WebSocket Long-Connection SDK**, supporting real-time messaging, document operations, and AI agent integration.

## 🛠 Core Capabilities

* **Real-time Messaging:** Receive and send messages via WebSocket (millisecond latency)
* **Document Operations:** Read, create, update documents via MCP or REST APIs
* **AI Agent Integration:** MCP service for AI workflows
* **Streaming Response:** Real-time streaming AI responses to users
* **Multi-user Sessions:** Concurrent message handling over single WebSocket connection

---

## 🔌 WebSocket Long-Connection Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Feishu Cloud Platform                    │
│  ┌─────────────┐         ┌─────────────────────────────┐    │
│  │Event Center │◄───────│  WebSocket Server (wss://)   │    │
│  └─────────────┘         └─────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ WebSocket Full-Duplex Channel
                              │ (TLS encrypted, auto-heartbeat)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ZeroClaw Server                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────┐   │    │
│  │  │ Feishu SDK  │──│ WebSocket   │──│  Event    │   │    │
│  │  │ (lark-ws)   │  │  Client     │  │  Handler  │   │    │
│  │  └─────────────┘  └─────────────┘  └───────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Key Characteristics:**
- **Protocol:** WebSocket over TLS (`wss://`)
- **Direction:** Application **actively connects** to Feishu server (Outbound)
- **Full-Duplex:** Bidirectional real-time communication
- **Auto Keepalive:** Built-in heartbeat mechanism (Ping/Pong every 30s)
- **Auto Reconnect:** Exponential backoff (1s, 2s, 4s, 8s... max 5 min)

---

## 🔑 Authentication

### App Credentials

```
FEISHU_APP_ID=cli_a9273cb060f85cb0
FEISHU_APP_SECRET=<from-secure-storage>
```

### Token Types

| Token Type | Description | Use Case |
|------------|-------------|----------|
| **App Access Token** | App identity token | WebSocket authentication, API calls |
| **Tenant Access Token (TAT)** | Tenant-level token | API calls with tenant context |
| **User Access Token (UAT)** | User identity token | User-authorized operations |

### Get App Access Token

```http
POST https://open.feishu.cn/open-api/auth/v3/app_access_token/internal
Content-Type: application/json

{
  "app_id": "APP_ID",
  "app_secret": "APP_SECRET"
}
```

**Response:**
```json
{
  "app_access_token": "a-xxx",
  "expire": 7200
}
```

---

## 📡 WebSocket Connection Lifecycle

### Connection Flow

```
ZeroClaw Startup
    │
    ▼
Get App Access Token (HTTP POST /auth/v3/app_access_token/internal)
    │
    ▼
Get WebSocket Endpoint (HTTP GET /event/subscription/endpoints)
    │   Returns: wss://ws.feishu.cn/open-apis/event/subscription/websocket/xxx
    ▼
Establish WebSocket Connection (ZeroClaw ◄────► Feishu Server)
    │
    ├─◄── Feishu: Send Challenge verification
    ├──►── ZeroClaw: Return Challenge Response
    │
    ├─◄── Feishu: Authentication success, start event push
    │
    ▼
Running State ◄──────► Heartbeat Keepalive (Ping/Pong every 30s)
    │
    ├─◄── im.message.receive_v1 (User sends message)
    ├──►── ZeroClaw processes (AI generates response)
    ├──►── POST /im/v1/messages/{message_id}/reply (Send reply via HTTP API)
    │
    ├─◄── Connection dropped
    ▼
Auto Reconnect (Exponential backoff)
```

### WebSocket Endpoint URL

```
wss://ws.feishu.cn/open-apis/event/subscription/websocket/{endpoint_id}
```

---

## 🛠️ SDK Implementation

### Go SDK (lark-ws)

```go
package main

import (
    "context"
    "github.com/larksuite/oapi-sdk-go/v3/ws"
)

type ZeroClawHandler struct {
    // AI Agent, database, etc.
}

func (h *ZeroClawHandler) OnMessage(ctx context.Context, event *ws.Event) error {
    // Parse message event
    var msgEvent struct {
        Sender  struct {
            SenderID struct {
                UserID string `json:"user_id"`
            } `json:"sender_id"`
        } `json:"sender"`
        Message struct {
            MessageID   string `json:"message_id"`
            ChatID      string `json:"chat_id"`
            MessageType string `json:"message_type"`
            Content     string `json:"content"`
        } `json:"message"`
    }
    
    json.Unmarshal(event.Event, &msgEvent)
    
    // Process with AI Agent
    response := h.aiAgent.Process(msgEvent.Message.Content)
    
    // Send reply via REST API
    h.sendReply(msgEvent.Message.MessageID, response)
    
    return nil
}

func main() {
    client := ws.NewClient(
        "APP_ID",
        "APP_SECRET",
        ws.WithEventHandler(&ZeroClawHandler{}),
        ws.WithLogLevel(ws.LogLevelDebug),
    )
    
    // Start WebSocket connection (blocks)
    client.Start(context.Background())
}
```

### Python SDK

```python
import lark_oapi as lark
from lark_oapi.event import BaseEventHandler

class MessageHandler(BaseEventHandler):
    def on_message_receive_v1(self, event: lark.Event) -> lark.Response:
        # Parse message
        msg = event.event.message
        
        # Process with AI Agent
        response = self.ai_agent.process(msg.content)
        
        # Send reply
        self.send_reply(msg.message_id, response)
        
        return lark.Response()

def main():
    client = lark.ws.Client(
        app_id="APP_ID",
        app_secret="APP_SECRET",
        event_handler=MessageHandler()
    )
    
    # Start WebSocket connection
    client.start()
```

---

## 📨 Event Handling

### Common Event Types

| Event Type | Description |
|------------|-------------|
| `im.message.receive_v1` | Receive new message |
| `im.message.read_v1` | Message read by user |
| `im.chat.created_v1` | Chat created |
| `im.chat.member.added_v1` | Member added to chat |
| `im.chat.member.deleted_v1` | Member removed from chat |
| `docx.document.created_v1` | Document created |
| `docx.document.updated_v1` | Document updated |

### Event Message Structure

```json
{
  "schema": "2.0",
  "header": {
    "event_id": "xxxxx",
    "event_type": "im.message.receive_v1",
    "create_time": "1600000000",
    "token": "xxxxx",
    "app_id": "xxxxx",
    "tenant_key": "xxxxx"
  },
  "event": {
    "sender": {
      "sender_id": {
        "union_id": "on_xxx",
        "user_id": "xxxxx"
      },
      "sender_type": "app"
    },
    "message": {
      "message_id": "xxxxx",
      "root_id": "xxxxx",
      "parent_id": "xxxxx",
      "create_time": "1600000000",
      "chat_id": "xxxxx",
      "message_type": "text",
      "content": "{\"text\":\"hello\"}"
    }
  }
}
```

---

## 📤 Sending Messages (REST API)

> After receiving events via WebSocket, use REST APIs to send replies.

### Base URL

```
https://open.feishu.cn/open-api
```

### Authorization Header

```
Authorization: Bearer {tenant_access_token}
```

### Reply to Message

```http
POST /im/v1/messages/{message_id}/reply
Authorization: Bearer t-xxx
Content-Type: application/json

{
  "msg_type": "text",
  "content": "{\"text\":\"Hello from ZeroClaw!\"}"
}
```

### Send Message to User

```http
POST /im/v1/messages?receive_id_type=user_id
Authorization: Bearer t-xxx
Content-Type: application/json

{
  "receive_id": "user_id_here",
  "msg_type": "text",
  "content": "{\"text\":\"Hello!\"}"
}
```

### Send Rich Card Message

```json
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "ZeroClaw Response"
      }
    },
    "elements": [
      {
        "tag": "div",
        "text": {
          "tag": "lark_md",
          "content": "**AI Generated Response**\nThis is a formatted message."
        }
      },
      {
        "tag": "action",
        "actions": [
          {
            "tag": "button",
            "text": {
              "tag": "plain_text",
              "content": "View Details"
            },
            "url": "https://example.com"
          }
        ]
      }
    ]
  }
}
```

---

## 🤖 MCP Service for AI Agents

> MCP (Model Context Protocol) allows AI agents to interact with Feishu documents via JSON-RPC 2.0.

### MCP Endpoint

```
URL: https://mcp.feishu.cn/mcp
Method: POST
Protocol: JSON-RPC 2.0
```

### MCP Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Lark-MCP-TAT` | Yes | Tenant access token |
| `Content-Type` | Yes | `application/json` |
| `X-Lark-MCP-Allowed-Tools` | No | Allowed tools list |

### MCP Methods

```json
// Initialize
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize"
}

// List tools
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}

// Call tool
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "fetch-doc",
    "arguments": {
      "docID": "doxcnxxxxx"
    }
  }
}
```

### MCP Supported Tools

| Tool | Description |
|------|-------------|
| `search-user` | Search users by keyword |
| `get-user` | Get user info |
| `fetch-file` | Get file/attachment content |
| `search-doc` | Search cloud documents |
| `create-doc` | Create new document |
| `fetch-doc` | Read document content |
| `update-doc` | Update document content |
| `list-docs` | List documents in wiki |
| `get-comments` | Get document comments |
| `add-comments` | Add comment to document |

---

## 📋 Required Permissions

### WebSocket Event Permissions

| Scope | Description |
|-------|-------------|
| `im:message` | Send and receive messages |
| `im:message.p2p_msg:readonly` | Read P2P messages |
| `im:message.group_msg:readonly` | Read group messages |

### Document Permissions

| Scope | Description |
|-------|-------------|
| `docx:document:readonly` | Read documents |
| `docx:document:write_only` | Edit documents |
| `docx:document:create` | Create documents |
| `drive:drive:readonly` | Read drive files |
| `wiki:wiki:readonly` | Read wiki |

### Contact Permissions

| Scope | Description |
|-------|-------------|
| `contact:user.base:readonly` | Get user basic info |
| `contact:user:search` | Search users |

---

## ⚡ WebSocket vs Webhook Comparison

| Feature | **WebSocket Long-Connection** | **Webhook** |
|---------|------------------------------|-------------|
| **Connection Direction** | App connects to Feishu | Feishu POSTs to App |
| **Network Requirement** | Outbound only (port 443) | Requires public IP + inbound rules |
| **Latency** | Milliseconds (real-time) | Seconds (HTTP overhead) |
| **Firewall Config** | None required | Port forwarding, whitelist |
| **Deployment** | 5 minutes (local dev OK) | 1 week (domain, HTTPS, ICP) |
| **Use Case** | AI Agent, real-time collaboration | Simple notifications, low-frequency callbacks |

**ZeroClaw uses WebSocket because:**
1. ✅ Local development friendly (no ngrok/frp needed)
2. ✅ Real-time streaming responses
3. ✅ Multi-user concurrent sessions
4. ✅ Auto-reconnect on network issues

---

## 🔧 Setup Checklist

- [x] Create Feishu App in Developer Console
- [x] Obtain App ID and App Secret
- [x] Enable WebSocket event subscription
- [x] Configure event types to receive
- [x] Implement event handler in ZeroClaw
- [x] Test WebSocket connection
- [x] Test message receive and reply
- [ ] Enable document permissions
- [ ] Test MCP service integration

---

## 📚 SDK & Resources

### Official SDKs

| Language | Repository | WebSocket Support |
|----------|------------|-------------------|
| Go | [larksuite/oapi-sdk-go](https://github.com/larksuite/oapi-sdk-go) | ✅ `lark-ws` module |
| Python | [larksuite/oapi-sdk-python](https://github.com/larksuite/oapi-sdk-python) | ✅ `lark-oapi.ws` |
| Java | [larksuite/oapi-sdk-java](https://github.com/larksuite/oapi-sdk-java) | ✅ WebSocket client |
| Node.js | [larksuite/node-sdk](https://github.com/larksuite/node-sdk) | ✅ WebSocket support |

### Documentation Links

- [Feishu Open Platform](https://open.feishu.cn/)
- [WebSocket Long-Connection SDK](https://open.feishu.cn/document/client-docs/bot-v3/events/overview)
- [Server-Side SDK Documentation](https://open.feishu.cn/document/server-docs/server-side-sdk)
- [MCP Service Documentation](https://open.feishu.cn/document/server-docs/server-side-sdk/mcp)
- [Event Subscription Guide](https://open.feishu.cn/document/ukTMukTMukTM/uUTNx4j1ucTM24SN1EjN)

---

## ⚠️ Implementation Notes

1. **WebSocket is Primary:** Use WebSocket for all real-time event receiving
2. **REST API for Replies:** Use HTTP APIs for sending messages and file operations
3. **Token Caching:** Cache `app_access_token` and `tenant_access_token` (2 hour expiry)
4. **Error Handling:** Implement retry logic for API rate limits
5. **Connection Management:** SDK handles auto-reconnect; monitor connection state
6. **Event Processing:** Process events asynchronously to avoid blocking WebSocket

---

*Updated: 2026-01-28 - Migrated to WebSocket long-connection SDK as primary communication method*
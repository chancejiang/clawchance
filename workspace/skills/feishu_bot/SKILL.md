# 🦀 Feishu Bot Skill (`SKILL.md`)

This skill enables **ZeroClaw** to interface with the Feishu (Lark) Open Platform API, supporting messaging, card interactions, and web customer service integration.

## 🛠 Core Capabilities

* **Multi-Chat Types:** Handle messages from private chats, group chats, and channels
* **Rich Card Messages:** Interactive cards with buttons, forms, and dynamic content
* **Web Customer Service:** Embed chat widget on external websites
* **Event Subscriptions:** Real-time message and interaction events via webhook
* **User Authentication:** Identify users via Feishu account, phone, or anonymous session

## 📡 API Reference

| Endpoint | Description |
|----------|-------------|
| `POST /auth/v3/tenant_access_token/internal` | Get tenant access token |
| `POST /im/v1/messages` | Send messages to users |
| `POST /im/v1/messages/:message_id/reply` | Reply to a message |
| `GET /im/v1/conversations/:conversation_id` | Get conversation info |
| `POST /card/v1/actions` | Handle card action callbacks |

## 🔑 Configuration

| Field | Description |
|-------|-------------|
| `APP_ID` | Feishu application ID |
| `APP_SECRET` | Feishu application secret |
| `ENCRYPT_KEY` | (Optional) Message encryption key |
| `VERIFICATION_TOKEN` | (Optional) Request verification token |
| `WEBHOOK_URL` | Public URL for receiving events |

## 🔐 Authentication Flow

1. Call `/auth/v3/tenant_access_token/internal` with APP_ID and APP_SECRET
2. Receive `tenant_access_token` (valid for 2 hours)
3. Use token in `Authorization: Bearer <token>` header for API calls
4. Cache token and refresh before expiration

## 📝 Message Types

### Text Message
```json
{
  "receive_id": "USER_ID",
  "msg_type": "text",
  "content": "{\"text\":\"Hello from ClawPapa!\"}"
}
```

### Card Message
```json
{
  "receive_id": "USER_ID",
  "msg_type": "interactive",
  "content": "{
    \"type\": \"template\",
    \"data\": {
      \"template_id\": \"CARD_TEMPLATE_ID\",
      \"template_variable\": {
        \"title\": \"Welcome\",
        \"content\": \"How can I help you?\"
      }
    }
  }"
}
```

## 🌐 Web Customer Service Integration

Embed chat widget on external websites:

```html
<script src="https://lf-cdn-tos.bytescm.com/obj/static/web-sdk/lark-web-sdk-1.0.0.js"></script>
<script>
  LarkWebSDK.init({
    appId: 'cli_a9273cb060f85cb0',
    locale: 'zh-CN',
    theme: 'light'
  });
</script>
```

## ⚠️ Requirements

To fully enable Feishu bot functionality, ZeroClaw needs:

1. **Public Webhook URL** — For receiving events from Feishu
2. **Event Subscription** — Configured in Feishu Developer Console
3. **Bot Capabilities** — Enabled in app settings (messages, cards, etc.)

## 🔧 Setup Checklist

- [x] Create Feishu App
- [x] Obtain App ID and App Secret
- [ ] Configure event subscription webhook URL
- [ ] Enable bot capabilities in console
- [ ] Deploy webhook handler
- [ ] Test message flow
- [ ] Embed web customer service on website

---

*This skill is under development. Additional features will be added based on usage requirements.*

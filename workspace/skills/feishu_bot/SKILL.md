# 🦀 Feishu Bot Skill (SKILL.md)

This skill enables **ZeroClaw** to interface with the Feishu (Lark) Open Platform API, supporting messaging, documents, and more.

## 🛠 Core Capabilities

* **Messaging:** Handle messages from private chats, group chats, and channels
* **Documents:** Read and analyze Feishu documents (docx, sheets, etc.)
* **Comments:** View document comments and discussions
* **Rich Cards:** Interactive cards with buttons, forms, and dynamic content
* **Web Customer Service:** Embed chat widget on external websites

## 🔑 Authentication

Use tenant access token for API calls:

```
POST /auth/v3/tenant_access_token/internal
Body: { "app_id": "APP_ID", "app_secret": "APP_SECRET" }
Returns: { "tenant_access_token": "t-xxx", "expire": 7200 }
```

Authorization header: `Authorization: Bearer t-xxx`

## 📡 API Reference

### Messaging APIs

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/im/v1/messages` | POST | Send message to user |
| `/im/v1/messages/:message_id/reply` | POST | Reply to a message |
| `/im/v1/conversations/:conversation_id` | GET | Get conversation info |

### Document APIs (NEW)

| Endpoint | Method | Description | Required Scope |
|----------|--------|-------------|----------------|
| `/docx/v1/documents/:document_id` | GET | Get document metadata | `docx:doc:readonly` |
| `/docx/v1/documents/:document_id/blocks/:block_id` | GET | Get document block content | `docx:doc:readonly` |
| `/docx/v1/documents/:document_id/blocks/:block_id/children` | GET | Get block children | `docx:doc:readonly` |
| `/drive/v1/files/:file_id/comments` | GET | Get file comments | `drive:file:readonly` |
| `/sheets/v3/spreadsheets/:spreadsheet_token/sheets/:sheet_id` | GET | Get sheet data | `sheets:sheet:readonly` |

### Document API Usage

**Get document content:**
```
GET /docx/v1/documents/{document_id}
Headers: Authorization: Bearer {tenant_access_token}
```

**Get document blocks:**
```
GET /docx/v1/documents/{document_id}/blocks/{block_id}
Headers: Authorization: Bearer {tenant_access_token}
```

**Get comments:**
```
GET /drive/v1/files/{file_id}/comments
Headers: Authorization: Bearer {tenant_access_token}
```

## 📝 Extracting Document ID from URL

Feishu document URLs follow this pattern:
- Docx: `https://xxx.feishu.cn/docx/{document_id}`
- Sheet: `https://xxx.feishu.cn/sheets/{spreadsheet_token}?sheet={sheet_id}`

## 🔧 Required Permissions (Scopes)

Ask your admin to enable these in Feishu Developer Console:

| Scope | Description |
|-------|-------------|
| `im:message` | Send and receive messages |
| `im:message.p2p_msg:readonly` | Read P2P messages |
| `docx:doc:readonly` | Read documents |
| `drive:drive:readonly` | Read drive files |
| `drive:file:readonly` | Read file metadata and comments |
| `sheets:sheet:readonly` | Read spreadsheets |

## 🌐 Base URL

```
https://open.feishu.cn/open-api
```

## ⚠️ Implementation Notes

1. Always cache tenant_access_token (valid for 2 hours)
2. Parse document URLs to extract document_id
3. Use the token from ClawPapa bot credentials
4. Handle rate limits and errors gracefully

## 🔧 Setup Checklist

- [x] Create Feishu App
- [x] Obtain App ID and App Secret
- [x] Deploy ClawPapa webhook handler
- [ ] Enable document scopes in Feishu Developer Console
- [ ] Test document API access
- [ ] Test comment retrieval

---

*Updated: 2026-03-09 - Added document and comment API support*

# 开发者调用远程 MCP 服务

> 最后更新于 2026-01-28

开发者可以在自己的 AI Agent 或自动化工作流中，通过代码集成的形式，调用飞书 MCP 提供的工具能力，以实现更复杂的定制化业务逻辑。远程调用模式允许开发者通过一个唯一的服务 URL，直接连接到飞书官方部署和维护的 MCP 服务。这种模式免去了本地部署和环境配置的复杂性，让你能以最快速度将飞书能力集成到 AI Agent 中。

当前支持「云文档」场景，查看 [支持的 MCP 工具集](#支持的-mcp 工具) 章节，后续会开放更多场景（如多维表格、日历）。欢迎反馈您的使用场景 🥳

## 开发前准备

在开始接入前，请确保你已完成以下准备工作：

1. **创建自建应用**：在 [飞书开放平台](https://open.feishu.cn/) 创建一个自建应用。
2. **申请权限**：根据你的工具需要，为应用申请对应的 API 权限。例如，如果你的工具需要读写云文档，则必须申请"查看、评论和管理云空间文档" (drive:document) 等相关权限。参考 [申请 API 权限](https://open.feishu.cn/document/ukTMukTMukTM/uQjN3QjL0YzN04CN2QDN)。
3. **获取访问凭证**：
   - **User Access Token (UAT)**：代表用户身份的凭证，适用于需要模拟特定用户操作的场景。获取方式请参考 [获取 user_access_token](https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/authen-v1/oidc-access_token/create)。
   - **Tenant Access Token (TAT)**：代表应用身份的凭证，适用于服务端到服务端的调用场景。获取方式请参考 [获取 tenant_access_token](https://open.feishu.cn/document/uAjLw4CM/ukTMukTMukTM/reference/authen-v3/tenant_access_token/internal/create)。

---

## 支持的 MCP 工具（持续更新中）

> **注意**：MCP 工具入参、出参格式可能灵活调整，调用 MCP 时请勿依赖入参和出参的结构定义。如涉及多个权限，请全部申请。请根据你的调用身份（UAT 或 TAT），参考 [申请 API 权限](https://open.feishu.cn/document/ukTMukTMukTM/uQjN3QjL0YzN04CN2QDN) 完成开通。

### 通用工具

| 工具名称 | 功能描述 | 功能限制 | 典型场景 | 支持 UAT/TAT | 所需权限 |
|---------|---------|---------|---------|-------------|---------|
| **search-user** | 根据关键词搜索企业内的用户，可获取用户的 ID、姓名、头像。如有同名用户，则按照亲密度返回，与你更亲密的用户排序靠前。 | 仅支持通过用户身份（user_access_token）调用该接口。无法搜索到外部企业或已离职的用户。 | 在不知道准确 ID 的情况下，通过姓名或邮箱快速查找同事。需要联系某人或分配任务，但只记得对方名字的一部分，用于定位具体人员。 | UAT | 搜索用户 `contact:user:search` |
| **get-user** | 获取用户本人的个人信息，也可通过用户 ID 获取其他用户的姓名、头像。用户信息仅包含：用户头像、名称、open id | 仅可查询你在通讯录中可见的用户范围，详见管理员设置 组织架构可见性。 | 查询当前登录用户的个人信息（如确认自己的 open id）。在已知用户 ID 的情况下（例如从搜索结果中获得），获取该员工的头像和名称。 | UAT/TAT（TAT 调用时，通讯录权限范围需要包含对应用户） | 获取通讯录基本信息 `contact:contact.base:readonly`<br>获取用户基本信息 `contact:user.base:readonly` |
| **fetch-file** | 获取文件内容。根据文件 ID (file_token)，获取文档中指定资源（文件或图片）的二进制内容。 | 文件大小限制在 5 MB 以内。需要有素材的下载权限，即文档「权限设置」中，当前用户拥有下载权限。 | 读取云文档中嵌入的图片、图表或附件。在自动化流程中，获取文档内特定资源的原始二进制数据以供后续处理。 | UAT/TAT | 下载云文档中的图片和附件 `docs:document.media:download`<br>查看画板节点 `board:whiteboard:node:read` |

### 云文档

> 若使用 TAT 调用，请确保应用已获得目标文档/知识库的授权，参考 [如何为应用或用户开通文档权限](https://open.feishu.cn/document/ukTMukTMukTM/uczNzQjL3QjN04C3QzN)。

| 工具名称 | 功能描述 | 功能限制 | 典型场景 | 支持 UAT/TAT | 所需权限 |
|---------|---------|---------|---------|-------------|---------|
| **search-doc** | 搜索云文档。根据关键词、创建者等条件，在你的飞书云文档中进行精确或模糊搜索。 | 仅可搜索 doc、docx 文档类型 | 快速查找遗忘在海量文档中的关键信息。为撰写报告或方案时，收集内部相关资料。回顾特定时期或特定成员的工作产出。 | UAT | 搜索云文档 `search:docs:read`<br>查看知识库 `wiki:wiki:readonly` |
| **create-doc** | 创建云文档。可在"我的文档库"或指定知识空间节点下创建一个新的云文档。对于超长文档内容，超过客户端输入长度上限后，模型可调用更新文档内容，续写内容。 | 暂不支持插入已有的多维表格、电子表格、OKR、任务、日程、飞书项目等内容。无法创建文档小组件、同步块、旧版流程图、旧版思维笔记。 | 将与 AI 的对话内容、灵感或分析结果，快速沉淀为正式的飞书云文档。自动生成格式化的报告、会议纪要或任务清单。 | UAT/TAT | 创建新版文档 `docx:document:create`<br>查看知识空间节点信息 `wiki:node:read`<br>创建知识空间节点 `wiki:node:create`<br>上传图片和附件到云文档中 `docs:document.media:upload`<br>创建画板节点 `board:whiteboard:node:create`<br>编辑新版文档 `docx:document:write_only`<br>查看新版文档 `docx:document:readonly` |
| **fetch-doc** | 查看云文档。根据文档链接，获取文档内的完整内容。对于超长文档内容，AI 可分段读取。 | 暂不支持多维表格、电子表格、OKR、任务、群名片、日程、飞书项目中的内容。无法读取旧版流程图、旧版思维笔记。 | 让 AI 阅读一篇指定的文档，并基于其内容进行总结、翻译、问答或二次创作。在跨文档信息整合时，作为获取源内容的基础操作。 | UAT/TAT | 查看新版文档 `docx:document:readonly`<br>查看任务信息 `task:task:read`<br>查看群信息 `im:chat:read` |
| **update-doc** | 更新云文档。可在文档指定位置增加内容，也可完善或替换指定内容。 | 暂不支持通过链接锚点定位 | 长文本续写：当生成内容较长时，通过在文档末尾分批追加内容，突破单次输出限制。内容修正与润色：全量覆盖或局部修改指定内容，对已有初稿进行优化。结构化插入：在特定章节（如"业务目标"）后精准插入补充信息（如"技术方案"）。文档动态维护：根据最新进展，在指定层级或位置更新项目状态、会议结论等。 | UAT/TAT | 创建新版文档 `docx:document:create`<br>查看知识空间节点信息 `wiki:node:read`<br>创建知识空间节点 `wiki:node:create`<br>上传图片和附件到云文档中 `docs:document.media:upload`<br>创建画板节点 `board:whiteboard:node:create`<br>编辑新版文档 `docx:document:write_only`<br>查看新版文档 `docx:document:readonly` |
| **list-docs** | 获取指定知识空间节点下的云文档列表。支持分页。 | 知识空间节点下的子知识空间，需要 AI 自行遍历获取。 | 目录浏览：快速了解某个项目文件夹或知识库节点下包含哪些文档。批量处理准备：在对某组文档进行批量总结或分析前，先获取文档清单。 | UAT/TAT | 查看知识库 `wiki:wiki:readonly` |
| **get-comments** | 查看指定云文档中的全文评论和划词评论。 | 仅支持 emoji、文字、文档类型的评论。暂不支持获取评论中的图片。 | 反馈收集：无需打开文档，直接获取同事在文档中留下的修改意见或疑问。待办整理：将文档中的评论提取出来，转化为下一步的工作计划或待办事项。 | UAT/TAT | 获取云文档中的评论 `docs:document.comment:read`<br>获取通讯录基本信息 `contact:contact.base:readonly` |
| **add-comments** | 添加全文评论。在指定云文档中添加文档评论。 | 仅支持添加全文评论，暂不支持划词评论。暂不支持上传图片到评论中。 | 快速互动：在阅读完 AI 总结的文档内容后，直接通过对话发表评价或反馈。审核记录：在协作文档中快速记录审阅意见，提醒文档作者关注。 | UAT/TAT | 添加、回复云文档中的评论 `docs:document.comment:create` |

---

## 接入流程

### 第 1 步：初始化连接

与 MCP 服务建立连接并验证凭证，返回会话信息。

```http
POST /mcp
Header: X-Lark-MCP-TAT: t-gxxxxxxxxxxxxxxxxxxxxx
Content-Type: application/json
X-Lark-MCP-Allowed-Tools:toolname1,toolname2,toolname3
Body: {"method": "initialize", ...}
```

### 第 2 步：列出可用工具

查询当前凭证和 `X-Lark-MCP-Allowed-Tools` 中定义的 MCP 工具列表和工具描述。

```http
POST /mcp
Header: 
X-Lark-MCP-TAT: t-gxxxxxxxxxxxxxxxxxxxxx
Content-Type: application/json
X-Lark-MCP-Allowed-Tools:toolname1,toolname2,toolname3
Body: {"method": "tools/list", ...}
```

### 第 3 步：调用工具

执行一个具体的工具（要求该工具必须在请求 Header `X-Lark-MCP-Allowed-Tools` 列表中）。

```http
POST /mcp
Header:
Content-Type: application/json
X-Lark-MCP-TAT: t-gxxxxxxxxxxxxxxxxxxxxx
X-Lark-MCP-Allowed-Tools:toolname1,toolname2,toolname3
Body: {"method": "tools/call", "params": {"name": "toolname1", ...}}
```

---

## 认证与请求

### 请求路径

所有 MCP 的 API 请求都使用统一的端点和 HTTP 方法。

- **HTTP URL**：`https://mcp.feishu.cn/mcp`
- **HTTP Method**：`POST`

### 请求头

MCP 通过 HTTP 请求头进行认证和配置。

| 请求头 | 必需 | 说明 | 示例 |
|-------|-----|------|------|
| `X-Lark-MCP-UAT` 或 `X-Lark-MCP-TAT` | 是 | 认证凭证，两者任选其一。UAT 代表用户身份，TAT 代表应用身份。 | `X-Lark-MCP-TAT: t-gxxxxxxxx` |
| `Content-Type` | 是 | 请求体的媒体类型，必须为 application/json。 | `application/json` |
| `X-Lark-MCP-Allowed-Tools` | 否 | 允许本次连接调用的工具列表，由工具名称组成，多个名称间用逗号分隔。如果未提供此头，AI 将无法发现和调用任何工具。 | `create-doc,fetch-doc` |

### 请求体

所有请求体都遵循 JSON-RPC 2.0 规范，包含以下核心字段：

- `jsonrpc`: (string) JSON-RPC 协议版本，固定为 `"2.0"`。
- `id`: (integer) 请求的唯一标识符，用于关联请求和响应。
- `method`: (string) 要调用的方法名称。

**示例：**

```http
POST /mcp HTTP/1.1
Host: mcp.feishu.cn
Content-Type: application/json
X-Lark-MCP-UAT: u-gxxxxxxxxxxxxxxxxxxxxx
X-Lark-MCP-Allowed-Tools: create-doc,fetch-doc

{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize"
}
```

---

## 支持的 MCP 方法

| 方法 | 方法作用 |
|-----|---------|
| `initialize` | 初始化一个 MCP 会话，验证认证凭证并返回服务器信息。 |
| `tools/list` | 列出当前会话中可用的工具列表。返回的工具受请求头 `X-Lark-MCP-Allowed-Tools` 的限制。 |
| `tools/call` | 调用一个具体的工具，并通过 `params` 传递工具名称和所需参数。 |

### initialize

初始化一个 MCP 会话，验证认证凭证并返回服务器信息。

**请求体示例：**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize"
}
```

**响应体示例 (成功)：**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "serverInfo": {
      "name": "Lark MCP Server",
      "version": "1.0.0"
    }
  }
}
```

### tools/list

列出当前会话中可用的工具列表。返回的工具受请求头 `X-Lark-MCP-Allowed-Tools` 的限制。

**请求体示例：**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

**响应体示例 (成功)：**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "annotations": {
          "title": "查看云文档",
          "readonlyHint": false,
          "destructiveHint": true,
          "idempotentHint": false,
          "openWorldHint": true
        },
        "description": "获取飞书云文档内容，将",
        "inputSchema": {
          "properties": {
            "docID": {
              "description": "文档 ID",
              "type": "string"
            }
          },
          "required": [
            "docID"
          ],
          "type": "object"
        },
        "name": "fetch-doc"
      }
    ]
  }
}
```

### tools/call

调用一个具体的工具，并通过 `params` 传递工具名称和所需参数。

**请求体示例：**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "fetch-doc",
    "arguments": {
      "docID": "xxxxxx"
    }
  }
}
```

**响应体示例 (成功)：**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"data\": {...}}"
      }
    ]
  }
}
```

---

## 常见框架示例代码

### Node.js

- [Langchain](https://js.langchain.com/docs/integrations/tools/feishu_mcp/)：官方文档
- [ai-sdk](https://sdk.vercel.ai/docs/ai-sdk-core/tools-and-tool-calling#model-context-protocol-mcp)：官方文档
- [typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk)：官方文档

### Python

- [Langchain](https://python.langchain.com/docs/integrations/tools/feishu_mcp/)：官方文档
- [Python-sdk](https://github.com/modelcontextprotocol/python-sdk)：官方文档

### Go

- [Enio](https://github.com/invopop/jsonschema)：官方文档
- [mcp-go](https://github.com/mark3labs/mcp-go)：官方文档
- [Go-sdk](https://github.com/larksuite/oapi-sdk-go)：官方文档

### Java

- [Java-sdk](https://github.com/larksuite/oapi-sdk-java)：官方文档
- [Spring](https://spring.io/blog/2025/01/27/spring-ai-mcp-server-and-client)：官方文档

---

## 错误码

| HTTP 状态码 | 错误码 | 错误信息 | 排查建议 |
|-----------|-------|---------|---------|
| 400 | -32700 | Parse error | 检查请求体是否为合法的 JSON 格式。 |
| 400 | -32600 | Invalid Request | JSON-RPC 请求结构不符合规范。请检查请求体是否为有效的 JSON 对象，并确保包含以下必要字段：<br>- `jsonrpc`：固定值为 `"2.0"`。<br>- `method`：必须为非空字符串。<br>- `id`：请求的唯一标识符。<br>- `params`：数据类型需符合接口定义。 |
| 404 | -32601 | Method not found | 工具不存在：检查 tool 名称是否一致，调用的是否是允许调用的 tool 列表集的方法。<br>调用方法不存在：检查方法名称是否是 `initialize`、`tools/list`、`tools/call`。 |
| 400 | -32602 | Invalid params | 参数错误，请检查响应体中 `error.message` 字段获取详细信息。 |
| 500 | -32603 | Internal error | 服务端内部异常：建议优先尝试重试；若问题持续，请联系技术支持并附上请求时间与关键参数（脱敏）。 |
| 429 | -32030 | Rate Limited | 请求频率超限。请降低调用频率，或联系技术支持调整限流阈值。 |
| 401 | -32011 | UAT TAT Required | 检查请求头中是否提供了 `X-Lark-MCP-UAT` 或 `X-Lark-MCP-TAT`。 |
| 400 | -32003 | Param Validate Error | 参数校验错误，请求的 GrantToken/UAT/TAT 无效或者已过期。 |
| 400 | -32042 | Invalid Content Type | 检查 `Content-Type` 请求头是否为 `application/json`。 |

### 错误响应格式

**工具执行失败**：当 API 请求成功，但工具内部执行出错时，HTTP 状态码仍为 200，但在 `result` 对象中通过 `isError: true` 和 `content` 中的错误信息来体现。

```json
{
    "jsonrpc": "2.0",
    "id": 2,
    "result": {
        "content": [
            {
                "type": "text",
                "text": "{\"error\":\"[VALIDATION:1004] Document ID length is insufficient: 13 < 15\\n💡 Suggestion: Please check if the document token is complete\\n📍 Context: docID=ewqedwqeqwewq, length=13\",\"log_id\":\"202512112222588228F6885BAECF6F6987\"}"
            }
        ],
        "isError": true
    }
}
```

**调用失败**：当请求本身不合法（如认证失败、方法名错误）时，会直接返回顶层的 `error` 对象。

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

---

## 远程 MCP 支持的工具列表

> 最后更新于 2026-01-13
> 
> 目前仅支持云文档场景，工具正在不断扩展中，敬请期待。

### 通用工具

配置远程 MCP 服务时，平台会自动为您开通以下通用的基础工具能力。

| 工具名称 | 功能描述 | 功能限制 | 典型场景 | 提示词样例 |
|---------|---------|---------|---------|-----------|
| **search-user** | 根据关键词搜索企业内的用户，可获取用户的 ID、姓名、头像。如有同名用户，则按照亲密度返回，与你更亲密的用户排序靠前。 | 仅支持通过用户身份（user_access_token）调用该接口。无法搜索到外部企业或已离职的用户。 | 在不知道准确 ID 的情况下，通过姓名或邮箱快速查找同事。需要联系某人或分配任务，但只记得对方名字的一部分，用于定位具体人员。 | "帮我找一下公司里叫'张三'的人"<br>"搜索邮箱包含 'product_team' 的相关用户。" |
| **get-user** | 获取用户本人的个人信息，也可通过用户 ID 获取其他用户的姓名、头像。用户信息仅包含：用户头像、名称、open id | 仅可查询你在通讯录中可见的用户范围，详见管理员设置 组织架构可见性。 | 查询当前登录用户的个人信息（如确认自己的 open id）。在已知用户 ID 的情况下（例如从搜索结果中获得），获取该员工的头像和名称。 | "查询一下张三的个人信息" |
| **fetch-file** | 获取文件内容。根据文件 ID (file_token)，获取文档中指定资源（文件或图片）的二进制内容。 | 文件大小限制在 5 MB 以内。需要有素材的下载权限，即文档「权限设置」中，当前用户拥有下载权限。 | 读取云文档中嵌入的图片、图表或附件。在自动化流程中，获取文档内特定资源的原始二进制数据以供后续处理。 | "读取这篇文档里的架构图（图片）。"<br>"提取文档中那个名为'Q4预算表.xlsx'的附件内容。" |

### 云文档

| 工具名称 | 功能描述 | 功能限制 | 典型场景 | 提示词样例 |
|---------|---------|---------|---------|-----------|
| **search-doc** | 搜索云文档。根据关键词、创建者等条件，在你的飞书云文档中进行精确或模糊搜索。 | 仅可搜索 doc、docx 文档类型 | 快速查找遗忘在海量文档中的关键信息。为撰写报告或方案时，收集内部相关资料。回顾特定时期或特定成员的工作产出。 | "帮我找一下上周由李明写的关于"Q4 规划"的文档。"<br>"搜索一下所有包含"AI Agent"和"RAG 优化"这两个关键词的文档。"<br>"查找我最近一个月内创建的所有周报。" |
| **create-doc** | 创建云文档。可在"我的文档库"或指定知识空间节点下创建一个新的云文档。对于超长文档内容，超过客户端输入长度上限后，模型可调用更新文档内容，续写内容。 | 暂不支持插入已有的多维表格、电子表格、OKR、任务、日程、飞书项目等内容。无法创建文档小组件、同步块、旧版流程图、旧版思维笔记。 | 将与 AI 的对话内容、灵感或分析结果，快速沉淀为正式的飞书云文档。自动生成格式化的报告、会议纪要或任务清单。 | "帮我创建一个会议纪要，标题是"今天下午的产品评审会"，把它放在"项目A/会议记录"文件夹里。"<br>"根据我们刚才的讨论，生成一份"新功能需求文档"，内容包括：用户登录流程优化、增加第三方支付渠道、以及后台数据看板。" |
| **fetch-doc** | 查看云文档。根据文档链接，获取文档内的完整内容。对于超长文档内容，AI 可分段读取。 | 暂不支持多维表格、电子表格、OKR、任务、群名片、日程、飞书项目中的内容。无法读取旧版流程图、旧版思维笔记。 | 让 AI 阅读一篇指定的文档，并基于其内容进行总结、翻译、问答或二次创作。在跨文档信息整合时，作为获取源内容的基础操作。 | "阅读这篇文档 [粘贴文档链接]，然后帮我总结出三个核心要点。"<br>"分析一下这篇技术方案，看看其中提到的架构设计有哪些潜在风险。" |
| **update-doc** | 更新云文档。可在文档指定位置增加内容，也可完善或替换指定内容。 | 暂不支持通过链接锚点定位 | 长文本续写：当生成内容较长时，通过在文档末尾分批追加内容，突破单次输出限制。内容修正与润色：全量覆盖或局部修改指定内容，对已有初稿进行优化。结构化插入：在特定章节（如"业务目标"）后精准插入补充信息（如"技术方案"）。文档动态维护：根据最新进展，在指定层级或位置更新项目状态、会议结论等。 | "在文档 [链接] 的末尾追加一段关于'竞品分析'的总结。"<br>"在这篇周报的末尾，帮我追加一段"下周计划"：1. 完成用户调研报告；2. 跟进设计稿进度。"<br>"把文档中'项目背景'这一段的内容替换成我刚才发给你的最新版本。"<br>"在'产品功能'标题后面，插入一段关于'移动端适配'的具体描述。" |
| **list-docs** | 获取指定知识空间节点下的云文档列表。支持分页。 | 知识空间节点下的子知识空间，需要 AI 自行遍历获取。 | 目录浏览：快速了解某个项目文件夹或知识库节点下包含哪些文档。批量处理准备：在对某组文档进行批量总结或分析前，先获取文档清单。 | "分析 [wiki 链接] 下的所有文档，归纳其中最常见的技术问题。"<br>"列出我的文档库下的所有文档" |
| **get-comments** | 查看指定云文档中的全文评论和划词评论。 | 仅支持 emoji、文字、文档类型的评论。暂不支持获取评论中的图片。 | 反馈收集：无需打开文档，直接获取同事在文档中留下的修改意见或疑问。待办整理：将文档中的评论提取出来，转化为下一步的工作计划或待办事项。 | "帮我提取这篇文档 [链接] 里的所有评论，看看大家都有什么修改意见。"<br>"阅读这篇方案的所有评论，总结三条大家最关注的问题。" |
| **add-comments** | 添加全文评论。在指定云文档中添加文档评论。 | 仅支持添加全文评论，暂不支持划词评论。暂不支持上传图片到评论中。 | 快速互动：在阅读完 AI 总结的文档内容后，直接通过对话发表评价或反馈。审核记录：在协作文档中快速记录审阅意见，提醒文档作者关注。 | "在这篇文档 [链接] 下面评论一句：'方案整体可行，建议细化一下第三部分的预算。'"<br>"帮我根据文档审核要求评审下文档内容，并将评审建议添加到全文评论。" |

---

## 更新日志

### 2025.12.29

**新增**：
- 云文档工具 `update-doc`（更新云文档）
- `list-docs`（获取知识空间节点下的文档列表）
- `get-comments`（查看全文评论与划词评论）
- `add-comments`（添加全文评论）

**更新**：
- `fetch-doc`（查看云文档）：支持分页读取，传入需要获取多少内容，避免单次获取的内容超过了客户端输出长度的限制。
- `create-doc`（创建云文档）：对于超长文档内容，超过客户端输入长度上限后，模型可调用更新文档内容，续写内容。

### 2025.12.19

飞书「云文档」、「基础工具」工具集首次全量发布，支持云文档读写搜场景。
# QQBot Backend

QQ Bot 后端服务，使用 SQLite 存储消息，提供 REST API 和 WebSocket 推送。

## 功能特性

- **QQ Bot Gateway 连接** - 长连接保持，自动重连
- **消息存储** - SQLite 持久化存储所有消息
- **用户认证** - 注册/登录，Token 认证
- **历史消息** - 支持按会话查询历史消息
- **实时推送** - WebSocket 实时推送新消息
- **富媒体支持** - 图片、视频、文件发送
- **消息引用** - 支持引用回复消息
- **自定义配置** - 支持自定义会话头像和昵称

## 快速开始

### 安装

```bash
cd qqbot-backend
npm install
```

### 启动

```bash
# 生产模式
npm start

# 开发模式（自动重启）
npm run dev
```

服务默认运行在 `http://localhost:3000`

## API 接口

### 认证

#### 注册 Bot

```
POST /api/register
Content-Type: application/json

{
  "appId": "你的AppID",
  "secret": "你的Secret",
  "wsUrl": "wss://sandbox.api.sgroup.qq.com",
  "intents": 33554431
}

Response:
{
  "success": true,
  "data": {
    "userId": 1,
    "token": "xxx",
    "appId": "xxx"
  }
}
```

#### 登录

```
POST /api/login
Content-Type: application/json

{
  "appId": "你的AppID",
  "secret": "你的Secret"
}

Response:
{
  "success": true,
  "data": {
    "userId": 1,
    "token": "xxx",
    "appId": "xxx",
    "isConnected": true
  }
}
```

#### 获取用户信息

```
GET /api/profile
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "userId": 1,
    "appId": "xxx",
    "wsUrl": "wss://...",
    "intents": 33554431,
    "isConnected": true,
    "botInfo": { ... },
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

### 会话管理

#### 获取会话列表

```
GET /api/conversations
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": [
    {
      "conversation_id": "xxx",
      "name": "会话名称",
      "type": "private|group",
      "custom_name": "自定义昵称",
      "custom_id": "自定义ID",
      "last_message": "最后一条消息",
      "last_message_time": "2024-01-01T00:00:00.000Z",
      "unread_count": 5
    }
  ]
}
```

#### 更新会话自定义信息

```
PUT /api/conversations/:conversationId/custom
Authorization: Bearer <token>
Content-Type: application/json

{
  "customName": "自定义昵称",
  "customId": "群号或QQ号"
}

说明：
- customName: 自定义显示昵称
- customId: 群号或QQ号，用于生成头像链接
  - 群头像: https://p.qlogo.cn/gh/{customId}/{customId}/0
  - 好友头像: https://q1.qlogo.cn/g?b=qq&s=0&nk={customId}
```

### 消息操作

#### 获取历史消息

```
GET /api/messages/:conversationId?limit=50&offset=0
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": [
    {
      "id": 1,
      "message_id": "ROBOT1.0_xxx",
      "reference_message_id": "REFIDX_xxx",
      "event_type": "GROUP_MESSAGE_CREATE",
      "content": "消息内容",
      "author_name": "发送者",
      "author_id": "xxx",
      "author_avatar": "https://...",
      "author_bot": 0,
      "conversation_id": "xxx",
      "is_incoming": 1,
      "timestamp": "2024-01-01T00:00:00.000Z",
      "attachments": [...]
    }
  ]
}
```

#### 发送文本消息

```
POST /api/messages/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "conversationId": "会话ID",
  "content": "消息内容",
  "type": "private|group",
  "msgType": 0,
  "message_reference": {
    "message_id": "REFIDX_xxx"  // 可选，引用消息ID
  }
}
```

#### 发送 Markdown 消息

```
POST /api/messages/markdown
Authorization: Bearer <token>
Content-Type: application/json

{
  "conversationId": "会话ID",
  "markdown": "# 标题\n\n**粗体** *斜体*\n\n```code```",
  "type": "private|group"
}
```

#### 上传文件并发送

```
POST /api/upload/file
Authorization: Bearer <token>
Content-Type: multipart/form-data

Fields:
- file: 文件
- conversationId: 会话ID
- type: private|group

支持的文件类型：
- 图片: image/*
- 视频: video/*
- 音频: audio/*
- 文件: 其他
```

### 其他接口

#### 重连 Bot

```
POST /api/reconnect
Authorization: Bearer <token>
```

#### 更新配置

```
PUT /api/config
Authorization: Bearer <token>
Content-Type: application/json

{
  "wsUrl": "wss://新的WebSocket地址"
}
```

## WebSocket 推送

连接地址: `ws://localhost:3000/ws`

### 认证

连接后发送认证消息：

```json
{
  "type": "auth",
  "data": {
    "userId": 1
  }
}
```

认证成功响应：

```json
{
  "type": "auth_success",
  "data": {
    "userId": 1
  }
}
```

### 接收消息推送

```json
{
  "type": "new_message",
  "data": {
    "eventType": "GROUP_MESSAGE_CREATE",
    "content": "消息内容",
    "authorName": "发送者",
    "authorId": "xxx",
    "authorAvatar": "https://...",
    "authorBot": false,
    "conversationId": "xxx",
    "isIncoming": true,
    "faceText": null,
    "attachments": [...],
    "messageId": "ROBOT1.0_xxx",
    "referenceMessageId": "REFIDX_xxx",
    "referenceContent": "引用内容",
    "timestamp": "2024-01-01T00:00:00.000Z"
  }
}
```

### 心跳

```json
// 客户端发送
{ "type": "ping" }

// 服务端响应
{ "type": "pong", "data": { "timestamp": 1704067200000 } }
```

## 数据库

SQLite 数据库文件保存在 `data/qqbot.db`

### 表结构

#### users - 用户表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| app_id | TEXT | AppID |
| secret | TEXT | Secret |
| ws_url | TEXT | WebSocket 地址 |
| intents | INTEGER | 订阅意图 |
| token | TEXT | 登录 Token |

#### conversations - 会话表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| user_id | INTEGER | 用户ID |
| conversation_id | TEXT | 会话ID |
| name | TEXT | 会话名称 |
| custom_name | TEXT | 自定义昵称 |
| custom_id | TEXT | 自定义ID（群号/QQ号）|
| type | TEXT | 会话类型 |
| last_message | TEXT | 最后消息 |
| last_message_time | DATETIME | 最后消息时间 |
| unread_count | INTEGER | 未读数量 |

#### messages - 消息表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| user_id | INTEGER | 用户ID |
| message_id | TEXT | 消息ID |
| reference_message_id | TEXT | 引用消息ID |
| event_type | TEXT | 事件类型 |
| content | TEXT | 消息内容 |
| author_name | TEXT | 发送者名称 |
| author_id | TEXT | 发送者ID |
| author_avatar | TEXT | 发送者头像 |
| author_bot | INTEGER | 是否为Bot |
| conversation_id | TEXT | 会话ID |
| is_incoming | INTEGER | 是否为接收消息 |
| timestamp | DATETIME | 时间戳 |

#### message_attachments - 附件表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| message_id | INTEGER | 消息ID |
| url | TEXT | 文件URL |
| content_type | TEXT | 文件类型 |
| filename | TEXT | 文件名 |
| width | INTEGER | 宽度 |
| height | INTEGER | 高度 |

## 消息类型

| msg_type | 说明 |
|----------|------|
| 0 | 文本消息 |
| 2 | Markdown 消息 |
| 7 | 富媒体消息（图片/视频/文件）|

## 文件类型

| file_type | 说明 |
|-----------|------|
| 1 | 图片 |
| 2 | 视频 |
| 3 | 音频 |
| 4 | 文件 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| PORT | 3000 | 服务端口 |

## 错误码

| 错误码 | 说明 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 未授权 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

## 开发

```bash
# 安装依赖
npm install

# 开发模式（自动重启）
npm run dev

# 生产模式
npm start
```

## 许可证

© 2026 ZY沂沨. All rights reserved.

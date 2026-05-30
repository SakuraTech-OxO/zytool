# ZYTool

ZY沂沨的个人工具箱应用，基于 Flutter 开发。

## 预览

### Android 端

| | |
|:---:|:---:|
| ![Android1](img/Android1.jpg) | ![Android2](img/Android2.jpg) |

### PC 端

![PC](img/PC.png)

## 功能特性

### 🎪 欢迎页面
- 个人主页展示
- 背景图片轮播（Ken Burns 动画效果）
- 倒计时动画

### 🤖 QQBot Chat
- QQ 机器人消息收发
- 支持私聊、群聊消息
- Markdown 消息渲染
- LaTeX 公式渲染
- 图片/视频/文件发送
- 消息引用回复
- 图片/视频点击预览
- 自定义会话头像和昵称
- 消息持久化存储
- 实时消息推送

### 📤 临时传输
- 文件上传到腾讯云 COS
- 支持多文件同时上传
- 上传进度实时显示
- 上传成功后可复制/跳转分享链接
- 上传失败可复制错误信息
- 显示文件大小和上传时间

### 💡 异想天开（彩蛋页）
- 生日倒计时
- 圆形进度条动画
- 需点击标题 12 次解锁

### 🌏 站点一览
- ZY沂沨的博客和导航站点链接
- 点击跳转到对应网站

### 🍬 关于ZY沂沨
- 个人介绍
- 聊天气泡样式展示

### 📧 联系ZY沂沨
- Email、QQ群、OICQ、Github、Gitee、Blog 等联系方式
- 点击直接跳转

## 项目结构

```
lib/
├── main.dart                    # 入口、全局状态、背景动画、侧边栏
├── models/
│   └── upload_file.dart         # UploadFile、SiteLink 数据类
├── pages/
│   ├── home_page.dart           # 欢迎主页
│   ├── qqbot_auth_page.dart     # QQBot 登录/注册页面
│   ├── qqbot_chat_page.dart     # QQBot 聊天页面
│   ├── transfer_page.dart       # 临时传输
│   ├── when_page.dart           # 异想天开（彩蛋页）
│   ├── register_page.dart       # 站点一览
│   ├── about_page.dart          # 关于ZY沂沨
│   └── contact_page.dart        # 联系ZY沂沨
├── widgets/
│   ├── page_navigation.dart     # 底部导航按钮
│   ├── chat_message.dart        # 聊天气泡
│   ├── avatar.dart              # 头像组件
│   ├── contact_item.dart        # 联系条目
│   └── file_item.dart           # 文件列表项
└── utils/
    ├── formatters.dart          # 文件大小、日期格式化
    └── url_launcher.dart        # URL跳转工具

qqbot-backend/                   # QQBot 后端服务
├── src/
│   ├── index.js                 # 主入口
│   ├── database.js              # SQLite 数据库
│   ├── qqbot-client.js          # QQ Bot SDK 客户端
│   ├── qqbot.js                 # Bot 连接管理
│   ├── api.js                   # REST API 路由
│   └── websocket.js             # WebSocket 推送服务
├── data/                        # SQLite 数据库文件
├── package.json
└── README.md
```

## QQBot 后端服务

### 功能

- QQ Bot Gateway WebSocket 长连接
- 消息自动接收和 SQLite 存储
- 用户注册/登录认证
- 历史消息查询
- 实时消息推送
- 自动重连机制

### 安装和启动

```bash
cd qqbot-backend
npm install
npm start
```

服务默认运行在 `http://localhost:3000`

### API 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/register` | POST | 注册 Bot |
| `/api/login` | POST | 登录 |
| `/api/profile` | GET | 获取用户信息 |
| `/api/conversations` | GET | 获取会话列表 |
| `/api/conversations/:id/custom` | PUT | 更新会话自定义信息 |
| `/api/messages/:conversationId` | GET | 获取历史消息 |
| `/api/messages/send` | POST | 发送文本消息 |
| `/api/messages/markdown` | POST | 发送 Markdown 消息 |
| `/api/upload/file` | POST | 上传文件并发送 |

### WebSocket 推送

连接地址: `ws://localhost:3000/ws`

```json
// 认证
{ "type": "auth", "data": { "userId": 1 } }

// 接收消息
{ "type": "new_message", "data": { ... } }

// 心跳
{ "type": "ping" }
```

详细文档请查看 [qqbot-backend/README.md](qqbot-backend/README.md)

## 依赖项

### Flutter 前端

- `http` - HTTP 请求
- `url_launcher` - URL 跳转
- `file_picker` - 文件选择
- `web_socket_channel` - WebSocket 连接
- `flutter_markdown` - Markdown 渲染
- `flutter_math_fork` - LaTeX 公式渲染
- `liquid_glass_widgets` - 液态玻璃 UI 组件
- `cupertino_icons` - iOS 风格图标

### Node.js 后端

- `express` - Web 框架
- `ws` - WebSocket 服务
- `sql.js` - SQLite 数据库
- `axios` - HTTP 客户端
- `multer` - 文件上传处理
- `cors` - 跨域支持

## 开发环境

- Flutter SDK: ^3.12.0
- Dart SDK: ^3.12.0
- Node.js: >= 16

## 运行项目

### 前端

```bash
# 获取依赖
flutter pub get

# 运行开发模式
flutter run

# 构建 APK
flutter build apk

# 构建 iOS
flutter build ios

# 构建 Web
flutter build web

# 构建 Windows
flutter build windows

# 构建 macOS
flutter build macos

# 构建 Linux
flutter build linux
```

### 后端

```bash
cd qqbot-backend

# 安装依赖
npm install

# 启动服务
npm start

# 开发模式（自动重启）
npm run dev
```

## 自动构建

项目配置了 GitHub Actions 自动构建，支持以下平台：

| 平台 | 触发条件 | 产物 |
|------|----------|------|
| Android | push to main | APK |
| Windows | push to main | exe |
| Linux | push to main | bundle |
| macOS | push to main | app |
| Web | push to main | html/js |

### 发布新版本

```bash
# 创建 tag 并推送，自动触发 Release 构建
git tag v1.0.0
git push origin v1.0.0
```

## 应用图标

应用图标使用 `assets/image/headimg_dl.jpg`，可通过以下命令生成：

```bash
flutter pub run flutter_launcher_icons
```

## 资源文件

- `assets/image/` - 背景图片、头像等
- `assets/cursor/` - 自定义光标文件

## 许可证

© 2026 ZY沂沨. All rights reserved.

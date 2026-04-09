# Requirements: wzxClaw Android

**Defined:** 2026-04-09
**Core Value:** 手机端能实时和桌面端 wzxClaw 的 AI Agent 对话，看到流式回复和工具调用过程，且在广域网环境下稳定可用。

## v1 Requirements

### Connection

- [ ] **CONN-01**: App 能通过 NAS WebSocket Relay 连接到桌面端 wzxClaw（广域网）
- [ ] **CONN-02**: App 支持配置 NAS 地址和连接 token
- [ ] **CONN-03**: WebSocket 断开后自动重连（指数退避）
- [ ] **CONN-04**: 连接状态实时显示（已连接/断开/重连中）

### Chat

- [ ] **CHAT-01**: 用户能发送文本指令到桌面端 wzxClaw
- [ ] **CHAT-02**: 用户能看到 AI 回复的流式文本（逐字显示）
- [ ] **CHAT-03**: 用户能看到 AI 调用工具的过程（显示工具名 badge，如文件读写、命令执行）
- [ ] **CHAT-04**: 用户能停止正在生成的回复
- [ ] **CHAT-05**: 聊天历史本地持久化，重新打开 app 能看到之前的对话
- [ ] **CHAT-06**: 支持清空当前会话

### Push Notifications

- [ ] **NOTI-01**: AI 任务完成时，app 在后台收到推送通知
- [ ] **NOTI-02**: 用户点击通知跳转到对应会话
- [ ] **NOTI-03**: 用户能开关推送通知

### Project Management

- [ ] **PROJ-01**: 用户能查看桌面端当前活跃的项目列表
- [ ] **PROJ-02**: 用户能切换活跃项目（发送切换指令到桌面端）
- [ ] **PROJ-03**: 显示每个项目的基本状态（是否有任务在运行）

### Voice Input

- [x] **VOICE-01**: 用户能通过麦克风语音输入指令
- [x] **VOICE-02**: 支持中文语音识别
- [x] **VOICE-03**: 语音识别结果可编辑后再发送

### NAS Relay Server

- [ ] **RELAY-01**: NAS Docker 部署 WebSocket Relay 服务
- [ ] **RELAY-02**: 桌面端 wzxClaw 连接到 Relay 注册自己
- [ ] **RELAY-03**: 手机端通过 Relay 与桌面端双向通信
- [ ] **RELAY-04**: 手机端离线时，Relay 缓存消息并触发推送通知
- [ ] **RELAY-05**: Token 鉴权，防止未授权访问
- [ ] **RELAY-06**: 通过 5945.top 域名 HTTPS 反代对外暴露

## v2 Requirements

### Notifications

- **NOTI-04**: 通知分类（错误/完成/等待输入）
- **NOTI-05**: 自定义通知铃声

### Chat

- **CHAT-07**: Markdown 渲染（代码块高亮）
- **CHAT-08**: 复制消息内容
- **CHAT-09**: 搜索历史对话

### Project

- **PROJ-04**: 查看项目文件结构
- **PROJ-05**: 查看文件内容（只读）

### Settings

- **SETT-01**: 深色/浅色主题切换
- **SETT-02**: 多桌面端管理（切换连接不同电脑）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 代码编辑器 | 手机屏幕不适合编辑代码，核心场景是指令+结果 |
| 本地 LLM 调用 | 所有 AI 走桌面端，手机不做推理 |
| iOS 版本 | 先做 Android，后续可扩展 |
| 多用户/账户 | 个人工具 |
| 文件上传 | v1 不需要，指令为主 |
| P2P 直连 | 复杂度高，NAS 中转足够 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONN-01 | Phase 1 | Pending |
| CONN-02 | Phase 1 | Pending |
| CONN-03 | Phase 1 | Pending |
| CONN-04 | Phase 1 | Pending |
| RELAY-01 | Phase 2 | Pending |
| RELAY-02 | Phase 2 | Pending |
| RELAY-03 | Phase 2 | Pending |
| RELAY-05 | Phase 2 | Pending |
| RELAY-06 | Phase 2 | Pending |
| CHAT-01 | Phase 3 | Pending |
| CHAT-02 | Phase 3 | Pending |
| CHAT-03 | Phase 3 | Pending |
| CHAT-04 | Phase 3 | Pending |
| CHAT-05 | Phase 3 | Pending |
| CHAT-06 | Phase 3 | Pending |
| PROJ-01 | Phase 4 | Pending |
| PROJ-02 | Phase 4 | Pending |
| PROJ-03 | Phase 4 | Pending |
| VOICE-01 | Phase 5 | Complete |
| VOICE-02 | Phase 5 | Complete |
| VOICE-03 | Phase 5 | Complete |
| NOTI-01 | Phase 6 | Pending |
| NOTI-02 | Phase 6 | Pending |
| NOTI-03 | Phase 6 | Pending |
| RELAY-04 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25
- Unmapped: 0

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 after initial definition*

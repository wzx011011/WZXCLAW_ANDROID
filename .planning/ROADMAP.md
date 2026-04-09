# Roadmap: wzxClaw Android

**Created:** 2026-04-09
**Granularity:** Standard
**Total Phases:** 6
**Total Requirements:** 25

---

## Phase 1: Flutter Project Foundation + WebSocket Client

**Goal:** 搭建 Flutter 项目骨架，实现 WebSocket 连接基础，能连上桌面端 wzxClaw 收发消息。

**Requirements:** CONN-01, CONN-02, CONN-03, CONN-04

**Plans:** 3/3 plans complete

Plans:
- [x] 01-01-PLAN.md — Flutter project skeleton + ConnectionManager (state machine, heartbeat, reconnection, send queue)
- [x] 01-02-PLAN.md — UI layer: settings page, connection status bar, home page with test send/receive
- [x] 01-03-PLAN.md — Gap closure: Android resource files (styles.xml, launch_background.xml) + INTERNET permission

**Success Criteria:**
1. Flutter 项目能在 Android 模拟器和真机上运行
2. 能配置 NAS 地址和 token，通过 WebSocket 连接到桌面端
3. 连接状态实时显示在 UI 上（已连接/断开/重连中）
4. 断开后自动重连（指数退避）

**Dependencies:** None
**UI hint:** yes

---

## Phase 2: NAS WebSocket Relay Server

**Goal:** 在 NAS Docker 部署 WebSocket Relay 服务，桌面端和手机端通过 Relay 双向通信，token 鉴权，HTTPS 反代。

**Requirements:** RELAY-01, RELAY-02, RELAY-03, RELAY-05, RELAY-06

**Plans:** 3/3 plans complete

Plans:
- [x] 02-01-PLAN.md — Node.js WebSocket relay server with token auth, room pairing, and message forwarding
- [x] 02-02-PLAN.md — Docker deployment (Dockerfile, docker-compose, nginx reverse proxy config)
- [x] 02-03-PLAN.md — Flutter app update (URL construction with role=mobile, settings hint)

**Success Criteria:**
1. Relay Docker 容器在 NAS 上稳定运行
2. 桌面端 wzxClaw 能连接 Relay 注册自己
3. 手机端通过 5945.top HTTPS 连接 Relay，与桌面端双向通信
4. Token 鉴权生效，无效 token 被拒绝
5. Phase 1 的直连测试切换为通过 Relay 连接，功能不变

**Dependencies:** Phase 1
**UI hint:** no

---

## Phase 3: Chat UI + Streaming

**Goal:** 完整的聊天界面，支持发送指令、流式接收回复、显示工具调用过程、历史持久化。

**Requirements:** CHAT-01, CHAT-02, CHAT-03, CHAT-04, CHAT-05, CHAT-06

**Plans:** 2/2 plans complete

Plans:
- [x] 03-01-PLAN.md — Data layer: ChatMessage model, ChatDatabase (SQLite), ChatStore state manager with streaming accumulation
- [x] 03-02-PLAN.md — Chat UI: rewrite HomePage with message bubbles, streaming cursor, tool badges, send/stop, history, clear session

**Success Criteria:**
1. 用户输入文本指令，桌面端 AI Agent 收到并回复
2. AI 回复逐字流式显示
3. 工具调用显示为 badge（如 🔧 ReadFile, 🔧 RunCommand）
4. 能停止正在生成的回复
5. 聊天历史本地持久化，重启 app 后可查看

**Dependencies:** Phase 2
**UI hint:** yes

---

## Phase 4: Project Management

**Goal:** 查看桌面端活跃项目列表，切换项目，查看项目运行状态。

**Requirements:** PROJ-01, PROJ-02, PROJ-03

**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md — Data layer: Project model + ProjectStore singleton (command sending, response parsing, SharedPreferences persistence)
- [x] 04-02-PLAN.md — UI layer: ProjectListTile widget, ProjectDrawer widget, HomePage drawer integration

**Success Criteria:**
1. 能看到桌面端当前打开的项目列表
2. 能切换活跃项目，桌面端响应切换
3. 显示每个项目是否有 AI 任务在运行

**Dependencies:** Phase 3
**UI hint:** yes

---

## Phase 5: Voice Input

**Goal:** 语音输入指令，中文语音识别，识别结果可编辑后发送。

**Requirements:** VOICE-01, VOICE-02, VOICE-03

**Plans:** 2 plans

Plans:
- [ ] 05-01-PLAN.md — Add speech_to_text + permission_handler dependencies, Android manifest permissions, VoiceInputService singleton with tests
- [ ] 05-02-PLAN.md — MicButton widget (long-press gesture, recording animation), HomePage input bar integration, voice error SnackBar handling

**Success Criteria:**
1. 按住麦克风按钮说话，松开后识别为文字
2. 中文语音识别准确率满足日常使用
3. 识别结果显示在输入框，用户可编辑后再发送

**Dependencies:** Phase 3
**UI hint:** yes

---

## Phase 6: Push Notifications + Offline Queue

**Goal:** AI 任务完成时推送通知到手机，离线消息缓存，点击通知跳转。

**Requirements:** NOTI-01, NOTI-02, NOTI-03, RELAY-04

**Success Criteria:**
1. AI 任务完成时，手机收到推送通知（app 在后台）
2. 点击通知跳转到对应会话页面
3. 用户可在设置中开关推送
4. 手机离线期间的消息在上线后同步

**Dependencies:** Phase 2, Phase 3
**UI hint:** yes

---

## Phase Dependency Graph

```
Phase 1 (Foundation + WS Client)
  ↓
Phase 2 (NAS Relay Server)
  ↓
Phase 3 (Chat UI + Streaming)
  ↓         ↓
Phase 4    Phase 5
(Project)  (Voice)
  ↑         ↑
  └─────────┴── Phase 6 (Push Notifications)
```

**Parallelizable:** Phases 4 and 5 can run in parallel after Phase 3.

---

## Requirement Traceability

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
| VOICE-01 | Phase 5 | Pending |
| VOICE-02 | Phase 5 | Pending |
| VOICE-03 | Phase 5 | Pending |
| NOTI-01 | Phase 6 | Pending |
| NOTI-02 | Phase 6 | Pending |
| NOTI-03 | Phase 6 | Pending |
| RELAY-04 | Phase 6 | Pending |

**Coverage:** 25/25 requirements mapped (100%)

---
*Roadmap created: 2026-04-09*

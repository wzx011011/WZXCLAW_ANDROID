# wzxClaw Android

## What This Is

wzxClaw 的安卓端客户端，通过 NAS 中转 WebSocket 连接桌面端 wzxClaw IDE。用户在手机上发送编程指令、查看 AI Agent 实时执行过程、管理项目、接收任务完成推送、使用语音输入。个人工具，不考虑商业化。

## Core Value

手机端能实时和桌面端 wzxClaw 的 AI Agent 对话，看到流式回复和工具调用过程，且在广域网环境下稳定可用。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 手机端通过 NAS WebSocket Relay 连接桌面端 wzxClaw，支持广域网访问
- [ ] 聊天界面：发送指令、接收流式文本回复、显示工具调用过程
- [ ] 推送通知：AI 任务完成时手机收到通知（app 在后台）
- [ ] 项目管理：查看/切换桌面端的活跃项目
- [ ] 语音输入：通过手机麦克风输入指令

### Out of Scope

- 代码编辑器 — 手机端不做代码编辑，只做指令发送和结果查看
- 本地 LLM 调用 — 所有 AI 能力走桌面端 wzxClaw，手机端不直接调 LLM API
- 多用户/账户体系 — 个人工具，不需要登录注册
- iOS 版本 — 先做 Android

## Context

- **wzxClaw 桌面端**：Electron + React + TypeScript 的 AI IDE，支持多 LLM 后端（OpenAI/Anthropic/DeepSeek），已有 WebSocket server 和 web mobile-client
- **NAS 中转架构**：群晖 918+（32GB RAM），Docker 环境，域名 5945.top 配有 HTTPS 反向代理
- **现有 mobile-client**：src/mobile-client/ 下有 HTML/JS/CSS 的 Web 客户端，通过 WebSocket 连桌面端，支持流式消息和工具调用展示。新的 Android 端将复用桌面端 WebSocket 协议
- **NAS 已有服务**：anthropic-proxy、dify、langfuse、moltbot-gateway 等已在运行，DDNS 和反向代理就绪

## Constraints

- **Tech Stack**: Flutter (Dart) — 用户选择，追求轻量和快速开发
- **Target Platform**: Android only — 先不做 iOS
- **Network**: 必须支持广域网访问（手机不在同一局域网），通过 NAS 5945.top 中转
- **Server**: NAS Docker 部署 WebSocket Relay 服务，复用现有 5945.top 域名和 HTTPS
- **Desktop Integration**: 复用 wzxClaw 桌面端已有的 WebSocket 协议和消息格式
- **Scope**: 个人工具，不考虑商业化、付费、多用户

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter (Dart) | 轻量、原生体验、WebSocket/推送/语音库成熟 | — Pending |
| NAS WebSocket Relay | 手机无法直连桌面端 NAT，需要中转；NAS 已有 Docker+域名+HTTPS | — Pending |
| 复用 wzxClaw WebSocket 协议 | 桌面端已有 WebSocket server 和消息格式，避免重复造轮子 | — Pending |
| 不做代码编辑 | 手机屏幕不适合编辑代码，核心场景是发指令和看结果 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-09 after initialization*

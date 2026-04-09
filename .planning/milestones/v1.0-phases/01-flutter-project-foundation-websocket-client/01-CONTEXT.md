# Phase 1: Flutter Project Foundation + WebSocket Client - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase)

<domain>
## Phase Boundary

搭建 Flutter 项目骨架，实现 WebSocket 连接基础，能连上桌面端 wzxClaw 收发消息。包括：Flutter 项目初始化、项目结构设计、WebSocket 客户端实现、连接状态管理、自动重连机制、基础 UI 显示连接状态。

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — infrastructure phase. Use ROADMAP phase goal, success criteria, and research findings to guide decisions.

Key technical guidance from PITFALLS.md research:
- WebSocket must include application-level heartbeat (ping/pong with timeout) — Android silently drops connections without firing close/error events
- Connection Manager should be singleton with state machine (disconnected → connecting → connected → reconnecting)
- Exponential backoff for reconnection (start 1s, cap 30s, jitter)
- Use `web_socket_channel` package for Flutter WebSocket client
- Test against wzxClaw desktop's existing WebSocket server (same protocol as mobile-client/app.js)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- wzxClaw desktop already has WebSocket server at `src/main/` (serves mobile-client)
- WebSocket message protocol already defined in `src/mobile-client/app.js`:
  - Send: `{ event: "command:send", data: { content } }`, `{ event: "command:stop" }`
  - Receive: `message:user`, `message:assistant`, `stream:text_delta`, `stream:tool_use_start`, `stream:done`, `stream:error`, `session:messages`
  - Auth via URL query param `?token=`

### Established Patterns
- wzxClaw uses Zustand for state management, similar pattern in Flutter would be Riverpod or simple ChangeNotifier
- Dark theme UI with accent color #6366f1 (indigo)

### Integration Points
- Flutter app connects to wzxClaw desktop WebSocket server (direct connection for Phase 1, NAS relay in Phase 2)
- WebSocket URL format: `ws://{host}:{port}/?token={token}`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Follow standard Flutter project structure and conventions.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

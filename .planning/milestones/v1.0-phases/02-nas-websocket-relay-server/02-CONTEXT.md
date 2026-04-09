# Phase 2: NAS WebSocket Relay Server - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

在 NAS Docker 部署 WebSocket Relay 服务，桌面端和手机端通过 Relay 双向通信，token 鉴权，HTTPS 反代。包括：
1. Relay 服务端实现（Node.js，可 Docker 化）
2. 桌面端 wzxClaw 连接 Relay 注册自己
3. 手机端 Flutter app 从直连模式切换为通过 Relay 连接
4. Token 鉴权机制
5. NAS Docker 部署 + HTTPS 反向代理（复用 5945.top 域名）

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — this is a pure infrastructure phase. Use ROADMAP phase goal, success criteria, and established codebase patterns to guide decisions.

Key considerations from Phase 1:
- Flutter app uses ConnectionManager singleton with WebSocket — need to change URL construction from direct `ws://host:port/?token=` to relay URL `wss://5945.top/relay/?token=`
- Desktop wzxClaw protocol uses event/data JSON format — relay must transparently forward these
- NAS already has 5945.top domain with HTTPS — relay should work behind existing reverse proxy

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/connection_manager.dart` — Phase 1 WebSocket manager, URL-agnostic, should work with relay URL
- `lib/config/app_config.dart` — Connection constants
- `lib/pages/settings_page.dart` — Server URL config, will need to support relay URL

### Established Patterns
- WebSocket connection via `web_socket_channel` package
- Event/data JSON protocol matching desktop wzxClaw
- SharedPreferences for persistent config

### Integration Points
- ConnectionManager.connect() takes URL string — relay URL is a drop-in replacement
- Settings page server URL field — may need to change default hint text

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>

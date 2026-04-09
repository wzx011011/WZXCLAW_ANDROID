# Phase 3: Chat UI + Streaming - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

完整的聊天界面，支持发送指令、流式接收回复、显示工具调用过程、历史持久化。包括：
1. 替换 Phase 1 的简单消息列表为完整的聊天 UI
2. 流式文本显示（逐字）
3. 工具调用 badge 显示
4. 停止生成按钮
5. 聊天历史本地持久化（SQLite）
6. 清空会话功能

</domain>

<decisions>
## Implementation Decisions

### Message Layout & Style
- User messages: right-aligned blue bubbles
- AI messages: full-width blocks on left, no bubble (better for code-heavy content)
- No avatars — clean minimal look (personal tool)
- Timestamps: hidden by default, tap to reveal

### Streaming & Tool Calls
- Streaming cursor: blinking ▌ at end of text during generation
- Tool call badge: compact inline `🔧 ReadFile` name only
- Tool call status: dot indicator (yellow=running, green=done)
- Stop button: replaces send button during streaming

### History & Storage
- Storage: SQLite via `sqflite` package
- Session model: single session, clear resets it
- Load limit: last 100 messages, load more on scroll up
- Auto-scroll: always scroll to bottom during streaming

### Claude's Discretion
- Exact widget structure, state management approach, animation details
- SQLite schema design
- Message model implementation details

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/connection_manager.dart` — WebSocket manager with messageStream broadcasting WsMessage objects
- `lib/models/ws_message.dart` — WsMessage with event/data, WsEvents constants (streamTextDelta, streamToolUseStart, streamDone, streamError, messageAssistant, messageUser, etc.)
- `lib/pages/home_page.dart` — Current simple message list (to be replaced)
- `lib/widgets/connection_status_bar.dart` — Status bar widget (keep)
- `lib/config/app_config.dart` — Constants

### Established Patterns
- Dark theme: scaffold #1a1a2e, surfaces #16213e, accent #6366f1
- StreamBuilder for reactive UI
- ConnectionManager.instance singleton access
- SharedPreferences for simple persistence

### Integration Points
- HomePage will be rewritten to show chat UI instead of simple message list
- ConnectionManager.messageStream provides all incoming events
- Settings page and connection status bar stay unchanged
- home_page.dart auto-connect logic should be preserved

</code_context>

<specifics>
## Specific Ideas

- Tool call badge format from ROADMAP: `🔧 ReadFile, 🔧 RunCommand`
- Streaming events from desktop protocol: `stream:text_delta` (incremental text), `stream:tool_use_start` (tool name), `stream:done` (generation complete), `stream:error`
- Full message events: `message:assistant` (complete message), `message:user` (user message echo)
- Dark theme established in Phase 1 (#1a1a2e, #16213e, #6366f1)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

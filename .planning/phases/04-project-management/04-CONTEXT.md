# Phase 4: Project Management - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

查看桌面端活跃项目列表，切换项目，查看项目运行状态。通过命令式协议（/projects, /switch）与桌面端交互。

</domain>

<decisions>
## Implementation Decisions

### Protocol & Interaction
- Project list query: send `command:send` with content `/projects` — reuse existing protocol
- Project switch: send `command:send` with content `/switch <project-name>` — command-style
- Desktop responds with structured data via `message:assistant` event

### UI Layout
- Project list in a Drawer (side panel) opened from app bar or swipe
- Green dot = AI task running, grey dot = idle
- Switching sends command, result shown as assistant message in chat

### Claude's Discretion
- Drawer widget structure, project list parsing, exact response format handling
- How to detect project status from desktop responses

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/chat_store.dart` — sendMessage() already handles sending text to desktop
- `lib/pages/home_page.dart` — Chat UI with AppBar (add drawer icon)
- `lib/services/connection_manager.dart` — stateStream, messageStream
- `lib/models/chat_message.dart` — ChatMessage for display
- Dark theme: #1a1a2e, #16213e, #6366f1

### Integration Points
- ChatStore.sendMessage() can send `/projects` and `/switch` commands
- No new WebSocket events needed — desktop responds via existing message:assistant
- Project data arrives as text in assistant messages — may need structured parsing if desktop sends JSON

</code_context>

<specifics>
## Specific Ideas

- Desktop wzxClaw may not support /projects and /switch commands yet — this phase defines the mobile side contract
- Consider graceful handling when desktop doesn't recognize these commands

</specifics>

<deferred>
## Deferred Ideas

None

</deferred>

# Feature Landscape

**Domain:** Mobile client for remote AI coding assistant (wzxClaw Android)
**Researched:** 2026-04-09
**Overall confidence:** HIGH

## Methodology

Analyzed feature sets from:
- **Claude Code Remote Control** (Feb 2026) -- the closest analog; mobile control of local AI coding sessions
- **GitHub Copilot Mobile** -- mobile chat interface for coding Q&A and code review
- **OpenClaw** -- self-hosted AI agent with remote interaction via WhatsApp/Telegram
- **Cursor/Windsurf** -- desktop-only AI IDEs with no mobile app (confirms mobile coding is still a greenfield space)
- **WebSocket relay patterns** for NAS-based mobile-to-desktop connectivity

## Table Stakes

Features users expect. Missing = product feels incomplete or unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **WebSocket connection to desktop IDE** | Core value prop -- mobile cannot connect to desktop directly, relay is essential. Without this, nothing works. | Med | Must handle reconnection, heartbeat, auth token. wzxClaw desktop already has WebSocket server; NAS relay is the new piece. |
| **Chat interface with text input** | Primary interaction model. User types commands, receives responses. Every AI assistant has this. | Med | TextField + send button. Must support multiline input. Standard Flutter widget work. |
| **Streaming text responses** | Users expect to see AI output appear token-by-token, not wait for complete response. Claude Code, Copilot, ChatGPT all stream. | Med | Server-sent events or WebSocket streaming chunks. Must render incrementally in chat bubbles. |
| **Markdown rendering in responses** | AI responses contain code blocks, lists, bold, links. Without markdown rendering, output is unreadable. | Low | Use `flutter_markdown`. Code blocks with syntax highlighting via `highlight` package. |
| **Connection status indicator** | User must know if phone is connected to desktop. Dropped connections are common on mobile (switching cells, WiFi to LTE). | Low | Icon/badge showing Connected / Connecting / Offline. Auto-reconnect in background. |
| **Message history persistence** | User scrolls up to see earlier conversation. Losing history on app restart is unacceptable. | Med | Local SQLite/Drift database. Sync on reconnect if needed. Pagination for long histories. |
| **Session management (view active sessions)** | wzxClaw desktop may have multiple projects/sessions. User needs to see which are active and select one. | Med | List view of desktop sessions. Show name, status (idle/working). Tap to connect. |
| **Reconnection on network change** | Mobile networks are unstable. App must transparently reconnect without user intervention. | Med | Exponential backoff. Preserve message queue during disconnect. Show status change. |

## Differentiators

Features that set product apart. Not expected by default, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Tool call visualization (real-time)** | Shows what the AI agent is doing: reading files, writing files, running commands. Claude Code Remote Control does this. wzxClaw desktop already has this in web client -- port to Flutter. | High | Parse tool call events from WebSocket stream. Display as collapsible cards with status (running/success/error). File diffs for write operations. Command output for exec. This is the #1 differentiator for an AI coding mobile app. |
| **Push notification on task completion** | User sends a long-running task, puts phone away, gets notified when done. No other mobile AI coding client does this well. Requires background service + FCM or local notification. | High | Two parts: (1) WebSocket listener in background isolate, (2) notification trigger when task completes. On Android, use `flutter_local_notifications` + foreground service for WebSocket keepalive. For true push when app is killed, need FCM relay through NAS. |
| **Voice input for commands** | Hands-free coding instructions while walking, driving, cooking. Unique to mobile form factor. Claude app supports voice. | Med | Use `speech_to_text` Flutter plugin (platform-native, works offline on most Android devices). Tap-to-talk button. Convert speech to text, insert into chat input. |
| **Project switching** | Quickly switch between active desktop projects without opening laptop. See project status at a glance. | Med | Requires desktop API to list/switch projects. Show project cards with: name, last activity, active agents, file count changed. |
| **File preview (read-only)** | Show file contents that the AI is reading or modifying, without editing capability. Lets user verify what AI is doing. | Med | Read-only code viewer with syntax highlighting. Tap on file path in tool call to open preview. No editing -- this is not a code editor. |
| **Dark/light theme** | Developer expectation. Late-night coding sessions need dark mode. | Low | Flutter `ThemeData` with `ThemeMode` toggle. Mostly config work. |
| **Conversation search** | Find a previous command or response. Critical when you have dozens of conversations. | Med | Full-text search over local message database. Search bar in conversation list. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Code editor** | Phone screens are terrible for code editing. Builds a complex feature that nobody will use well. wzxClaw desktop is the editor. | Show file content read-only. Send edit instructions via chat. Let the desktop IDE handle actual editing. |
| **Direct LLM API calls from mobile** | Phone should not call OpenAI/Anthropic directly. Adds API key management, latency, and duplicates desktop logic. All AI runs on desktop wzxClaw. | All requests go through WebSocket to desktop. Mobile is a thin client/viewer. |
| **User accounts / auth system** | Personal tool. One user. Adding auth is unnecessary complexity. | Simple device pairing or token-based auth for WebSocket relay. No login screen, no registration, no password reset. |
| **iOS support (for now)** | Targeting Android only per project scope. iOS adds Apple developer account costs, TestFlight complexity, and different notification patterns. | Build Android first. iOS is future consideration only if the Android version proves useful. |
| **Real-time collaboration (multiple users)** | Personal tool, not a team product. No need for shared sessions, user cursors, or presence. | Single user, single device connecting to their own desktop. |
| **Git operations UI** | Git commit/push/pull UI is complex to build well. Desktop handles this. | Send git commands via chat: "commit these changes with message X". Let desktop wzxClaw execute. |
| **App store distribution** | Personal tool. Play Store review process, signing, compliance are overhead for a single-user app. | Sideload APK. Build release APK and install directly. |
| **Chat with multiple AI models** | Model selection is desktop's job. Mobile should not need to know which LLM is running. | Mobile sends commands, desktop routes to whatever model wzxClaw is configured to use. |

## Feature Dependencies

```
WebSocket Connection (NAS Relay)
  --> Chat Interface (sends messages over connection)
    --> Streaming Response Renderer (parses streamed chunks)
      --> Markdown Rendering (formats streamed text)
    --> Tool Call Visualization (parses tool events from stream)
      --> File Preview (opened from tool call cards)
  --> Connection Status Indicator (monitors connection state)
    --> Auto-Reconnection (handles network changes)

Local Database (message persistence)
  --> Chat Interface (loads history on open)
  --> Conversation Search (queries over history)

Background Service (Android foreground service)
  --> Push Notifications (triggers on task-complete events)
  --> Connection keepalive (maintains WebSocket during background)

Speech-to-Text
  --> Chat Interface (inserts transcribed text into input)

Project/Sessions API (desktop-side)
  --> Session Management (lists available sessions)
  --> Project Switching (changes active session)
```

## NAS WebSocket Relay Pattern (Key Architecture Feature)

The relay pattern is central to this app. Research findings:

**Pattern:** Both mobile client and desktop IDE connect outbound to a WebSocket relay server running on the NAS (Synology 918+ in Docker). The relay bridges messages between them. Neither side needs inbound ports.

**Why this works for wzxClaw:**
- Desktop is behind NAT (home network) -- cannot accept direct connections from WAN
- NAS at 5945.top already has DDNS + HTTPS reverse proxy configured
- Docker on NAS can host a lightweight relay container
- WebSocket over HTTPS looks like normal web traffic -- no firewall issues

**Implementation options for the relay server:**
1. **Custom Node.js relay** (RECOMMENDED) -- simplest, matches wzxClaw's Node.js/TypeScript stack. ~100 lines of code. Routes messages by session/client ID.
2. **StealthRelay** (Rust) -- zero-knowledge WebSocket relay, self-hosted, very lightweight. Overkill for single-user but well-designed.
3. **RabbitMQ with Web-STOMP** -- heavy but battle-tested. Adds message queuing. Unnecessary for single-user personal tool.

**Relay architecture:**
```
Phone (Flutter app) --wss://--> NAS:443 --docker--> Relay Server <----ws---- Desktop wzxClaw
                              (5945.top)                         (bridges by session ID)
```

**Key relay concerns:**
- Message ordering must be preserved (streaming chunks arrive in sequence)
- Relay must handle desktop disconnect gracefully (queue messages briefly, notify mobile)
- Auth: simple shared token or HMAC per session -- not user accounts
- TLS termination at NAS reverse proxy, relay inside Docker on internal network

## MVP Recommendation

**Phase 1 -- Must have to be usable:**
1. WebSocket relay server on NAS (custom Node.js in Docker)
2. Chat interface with streaming responses and markdown rendering
3. Connection status + auto-reconnect
4. Message history persistence (local SQLite)

**Phase 2 -- Makes it genuinely useful:**
1. Tool call visualization (file reads/writes, command execution shown in real-time)
2. Push notifications when AI tasks complete (Android foreground service)
3. Session/project listing and switching

**Phase 3 -- Polish and differentiation:**
1. Voice input (speech-to-text)
2. File preview (read-only code viewer)
3. Dark/light theme
4. Conversation search

**Defer entirely:**
- Code editor: forever -- phone is not for editing
- iOS: until Android version proves daily-use value
- Multi-user/auth: forever -- personal tool
- Direct LLM calls: forever -- desktop is the brain

## Competitor Feature Matrix

| Feature | Claude Code Remote Control | GitHub Copilot Mobile | OpenClaw | wzxClaw Android (planned) |
|---------|---------------------------|----------------------|----------|--------------------------|
| Chat interface | Yes | Yes | Via WhatsApp/Telegram | Yes |
| Streaming responses | Yes | Yes | Yes | Yes |
| Tool call visualization | Yes | No | No | Yes (planned) |
| Push notifications | No (web only) | Partial (GitHub push) | Via messaging app | Yes (planned) |
| Voice input | Yes (Claude app) | No | No | Yes (planned) |
| Session management | Yes (multi-session) | No | No | Yes (planned) |
| File preview | Yes (code view) | Yes (PR files) | No | Yes (read-only) |
| Connection via relay | Anthropic cloud relay | GitHub cloud | Self-hosted | NAS self-hosted relay |
| Requires cloud account | Yes (claude.ai) | Yes (GitHub) | No | No (self-hosted) |
| Self-hosted / private | No | No | Yes | Yes (NAS) |

**Key differentiation for wzxClaw Android:**
1. Fully self-hosted -- no cloud account, no third-party relay. Data stays on your NAS and desktop.
2. Tool call visualization is rare in mobile AI coding clients. Combined with push notifications, this enables "send task, get notified with results" workflow that no competitor does well.
3. Voice input for coding commands is unique to the mobile form factor.

## Sources

- [Claude Code Remote Control Official Docs](https://code.claude.com/docs/en/remote-control) -- HIGH confidence, official Anthropic documentation
- [GitHub Copilot Chat in Mobile](https://docs.github.com/en/copilot/responsible-use/chat-in-github-mobile) -- HIGH confidence, official GitHub docs
- [GitHub Copilot Mobile Chat How-To](https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-mobile) -- HIGH confidence, official GitHub docs
- [GitHub Blog: Copilot Coding Agent + Mobile](https://github.blog/developer-skills/github/completing-urgent-fixes-anywhere-with-github-copilot-coding-agent-and-mobile/) -- HIGH confidence, official GitHub blog
- [OpenClaw GitHub](https://github.com/openclaw/openclaw) -- HIGH confidence, official repo
- [OpenClaw + OpenCode Integration](https://www.meta-intelligence.tech/en/insight-openclaw-opencode) -- MEDIUM confidence, third-party analysis
- [StealthRelay WebSocket Relay](https://github.com/Olib-AI/StealthRelay) -- MEDIUM confidence, open-source project
- [Synology Docker WebSocket Setup](https://mariushosting.com/synology-some-docker-containers-need-websocket/) -- HIGH confidence, well-known Synology community guide
- [Flutter speech_to_text package](https://pub.dev/packages/speech_to_text) -- HIGH confidence, official pub.dev
- [Flutter ai_chatview package](https://pub.dev/packages/ai_chatview) -- MEDIUM confidence, community package
- [Flutter FCM Push Notifications](https://firebase.flutter.dev/docs/messaging/usage/) -- HIGH confidence, official FlutterFire docs
- [Claude Code Remote Control Analysis](https://sealos.io/blog/claude-code-on-phone/) -- MEDIUM confidence, third-party blog
- [Anthropic Remote Control Launch News](https://mlq.ai/news/anthropic-launches-remote-control-feature-for-claude-code-enabling-terminal-operations-from-mobile-devices/) -- MEDIUM confidence, tech news

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table stakes features | HIGH | Based on direct analysis of Claude Code, Copilot Mobile, and general chat app patterns. Well-established. |
| Differentiators | HIGH | Tool call visualization confirmed in Claude Code Remote Control docs. Push notification patterns well-documented for Flutter/Android. |
| Anti-features | HIGH | Project scope explicitly defines these in PROJECT.md. Consistent with mobile AI coding limitations. |
| NAS WebSocket relay pattern | HIGH | Well-documented pattern (Synology Docker + reverse proxy). StealthRelay and wsrelay-server provide reference implementations. wzxClaw desktop already has WebSocket server. |
| Feature dependencies | HIGH | Standard client-server architecture. Dependencies are straightforward. |
| Competitor matrix | MEDIUM | Based on official docs + community sources. Some features (e.g., OpenClaw's exact capabilities) may have changed since sources were published. |

# Phase 6: Push Notifications + Offline Queue - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

AI 任务完成时推送通知到手机（app 在后台），离线消息在 Relay 缓存并在上线后同步，用户点击通知跳转到对应会话，设置中可开关推送。覆盖 NOTI-01, NOTI-02, NOTI-03, RELAY-04。

</domain>

<decisions>
## Implementation Decisions

### Push Notification Platform
- Use FCM (Firebase Cloud Messaging) — free, standard Android, mature Flutter plugin (`firebase_messaging`)
- Relay server calls FCM API when phone is offline, sends notification with message summary
- Firebase project scope: minimal FCM-only, no Firestore/Auth/Analytics bloat

### Notification Content & Behavior
- Notification shows: agent name + "completed" + first 50 chars of last message
- Multiple notifications grouped by session (single summary notification, latest content)
- 2 notification channels: "task_complete" (default) and "error" (high priority)

### Offline Sync Strategy
- Relay caches offline messages for 24 hours, then discards
- Timestamp-based merge on reconnect: append queued messages to existing chat history in order

### Claude's Discretion
- FCM setup details (google-services.json configuration, topic/subscription model)
- Notification tap navigation implementation (deep links vs named routes)
- Relay server FCM integration details (which FCM API to use, error handling)
- Offline cache storage format on relay (in-memory vs persistent)
- Push notification toggle implementation in settings (shared_preferences vs state management)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/services/connection_manager.dart` — WebSocket connection singleton, has connection state stream
- `lib/services/chat_store.dart` — Chat message state management, already handles message persistence via `chat_database.dart`
- `lib/services/chat_database.dart` — SQLite-based chat history persistence
- `lib/pages/settings_page.dart` — Existing settings page for notification toggle
- `lib/pages/home_page.dart` — Main chat UI, handles message display and WebSocket messages

### Established Patterns
- Singleton + StreamController.broadcast() for services
- Material 3 theming (Colors #1A1A2E dominant, #16213E secondary, #6366F1 accent)
- Services initialized in main.dart and accessed via `.instance`

### Integration Points
- `connection_manager.dart` — connection state changes (connected → trigger offline message sync)
- `chat_store.dart` — new messages from relay after offline sync
- `settings_page.dart` — push notification toggle UI
- Android manifest — FCM permissions and services
- Relay server (Phase 2 artifact) — needs FCM integration for push triggers

</code_context>

<specifics>
## Specific Ideas

- Push notification should work even when the app is force-killed (use high-priority FCM data messages)
- Notification should not show if user is actively viewing the conversation
- RELAY-04 requires changes to the NAS Relay server code (separate codebase from Flutter app)

</specifics>

<deferred>
## Deferred Ideas

- NOTI-04: Notification categories (error/complete/waiting) — v2 requirement
- NOTI-05: Custom notification sounds — v2 requirement
- Message retry/resend on failed offline delivery

</deferred>

---
*Phase: 06-push-notifications-offline-queue*
*Context gathered: 2026-04-09 via smart discuss (autonomous mode)*

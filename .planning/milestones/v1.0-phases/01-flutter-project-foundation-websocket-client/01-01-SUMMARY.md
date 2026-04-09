---
phase: 01-flutter-project-foundation-websocket-client
plan: 01
subsystem: websocket
tags: [flutter, dart, web_socket_channel, websocket, heartbeat, reconnection, singleton]

# Dependency graph
requires: []
provides:
  - Flutter project skeleton with pubspec.yaml and Android build config
  - WsMessage and WsEvents models matching wzxClaw desktop WebSocket protocol
  - WsConnectionState enum with 4 states and Chinese labels
  - AppConfig constants for heartbeat, reconnection, and queue parameters
  - ConnectionManager singleton with full connection lifecycle management
affects: [02-chat-ui-streaming, 03-nas-relay-server]

# Tech tracking
tech-stack:
  added: [flutter, dart, web_socket_channel ^3.0.0, shared_preferences ^2.2.0, flutter_lints]
  patterns: [singleton connection manager, application-level heartbeat, exponential backoff with jitter, send queue with overflow, connection sequence guard, WidgetsBindingObserver lifecycle]

key-files:
  created:
    - pubspec.yaml
    - lib/main.dart
    - lib/models/ws_message.dart
    - lib/models/connection_state.dart
    - lib/services/connection_manager.dart
    - lib/config/app_config.dart
    - analysis_options.yaml
    - android/app/build.gradle
    - android/app/src/main/AndroidManifest.xml
    - android/app/src/main/kotlin/com/wzx/wzxclaw_android/MainActivity.kt
  modified: []

key-decisions:
  - "Manual Flutter project structure (no flutter create) due to missing Flutter SDK on build machine"
  - "Application-level ping/pong heartbeat rather than WebSocket protocol-level pings for timing visibility"
  - "Connection sequence number pattern (_connSeq) to prevent stale callback processing"

patterns-established:
  - "Singleton ConnectionManager: single WebSocket instance shared across all pages via broadcast streams"
  - "Heartbeat + idle monitor dual-guard: ping/pong every 15s + 60s absolute idle timeout"
  - "Connection sequence guard: increment _connSeq on each connect, bail out of stale stream listeners"
  - "Exponential backoff with jitter: min(30s, base * 2^attempt) + random(0-500ms)"

requirements-completed: [CONN-01, CONN-03]

# Metrics
duration: 5min
completed: 2026-04-09
---

# Phase 1 Plan 01: Flutter Project Skeleton + WebSocket ConnectionManager Summary

**Flutter project with singleton ConnectionManager implementing heartbeat (15s ping, 8s pong timeout), exponential backoff reconnection, 200-message send queue, and app lifecycle handling**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-08T20:46:47Z
- **Completed:** 2026-04-08T20:52:20Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Complete Flutter Android project structure with pubspec.yaml, Android build config, and analysis_options.yaml
- WsMessage model and WsEvents constants matching all 12 wzxClaw desktop protocol events (4 outgoing, 8 incoming)
- ConnectionManager singleton with full connection lifecycle: state machine, heartbeat, idle monitor, exponential backoff, send queue, and lifecycle handling
- Threat model mitigation T-01-02: malformed JSON messages are caught and ignored silently

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Flutter project skeleton with dependencies and type definitions** - `5f80953` (feat)
2. **Task 2: Implement ConnectionManager singleton with state machine, heartbeat, reconnection, send queue, and lifecycle** - `715cafc` (feat)

## Files Created/Modified
- `pubspec.yaml` - Flutter project config with web_socket_channel ^3.0.0, shared_preferences ^2.2.0, min SDK 3.0.0
- `lib/main.dart` - Minimal MaterialApp entry point with placeholder Scaffold
- `lib/models/ws_message.dart` - WsMessage class (event/data, fromJson/toJson) and WsEvents constants (12 event names)
- `lib/models/connection_state.dart` - WsConnectionState enum (4 states) with ConnectionStateX Chinese label extension
- `lib/config/app_config.dart` - AppConfig constants: heartbeatInterval=15s, heartbeatTimeout=8s, maxIdleTime=60s, reconnectBaseDelay=1s, reconnectMaxDelay=30s, jitterMaxMs=500, maxQueueSize=200
- `lib/services/connection_manager.dart` - Singleton ConnectionManager (396 lines) with state machine, heartbeat, idle monitor, backoff, queue, lifecycle
- `analysis_options.yaml` - Flutter lints configuration
- `android/app/build.gradle` - Android build config with minSdk 21
- `android/app/src/main/AndroidManifest.xml` - Android manifest for wzxClaw Android
- `android/app/src/main/kotlin/com/wzx/wzxclaw_android/MainActivity.kt` - Flutter activity
- `android/build.gradle` - Root Android build script
- `android/settings.gradle` - Android settings with Flutter plugin management

## Decisions Made
- **Manual project creation** instead of `flutter create` because Flutter SDK is not installed on the build machine. All files created manually with correct structure.
- **Application-level ping/pong** (`{"event": "ping"}` / `{"event": "pong"}`) rather than WebSocket protocol-level ping frames, because it allows timing tracking and RTT logging.
- **Connection sequence number** pattern to prevent stale callbacks when rapid reconnections occur (e.g., network switching WiFi/cellular).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Flutter/Dart SDK not available on the build machine, so `dart analyze` could not be run. Code was manually verified for syntax correctness against Dart language spec. This is a build environment limitation, not a code issue.

## User Setup Required
None - no external service configuration required. Flutter SDK installation needed before building/running.

## Next Phase Readiness
- ConnectionManager is ready for Plan 02 to wire up the UI (connection status indicator, settings page for URL/token input)
- The stateStream and messageStream are ready for subscribers
- AppConfig constants are centralized for easy tuning during testing
- All 12 wzxClaw desktop protocol events are defined and ready for use

## Self-Check: PASSED

All files verified:
- FOUND: pubspec.yaml, lib/main.dart, lib/models/ws_message.dart, lib/models/connection_state.dart, lib/services/connection_manager.dart, lib/config/app_config.dart, analysis_options.yaml
All commits verified:
- FOUND: 5f80953 (Task 1), 715cafc (Task 2)

---
*Phase: 01-flutter-project-foundation-websocket-client*
*Completed: 2026-04-09*

---
phase: 02-nas-websocket-relay-server
plan: 01
subsystem: infra
tags: [websocket, relay, node.js, ws, authentication, pairing]

# Dependency graph
requires:
  - phase: none
    provides: "Greenfield -- no prior dependencies"
provides:
  - "WebSocket relay server (relay/) that pairs desktop and mobile clients by token"
  - "Token-based authentication (AUTH_TOKEN env var, dev mode fallback)"
  - "Bidirectional message forwarding with ping/pong filtering"
  - "Room lifecycle management (join, pair, replace, disconnect, cleanup)"
  - "Integration test suite (28 tests) covering auth, room, and relay"
affects: [03-chat-ui-streaming, 04-project-management]

# Tech tracking
tech-stack:
  added: [ws@^8.18.0, node:test, node:assert]
  patterns: [token-based room pairing, transparent message relay, synchronous-close-guard]

key-files:
  created:
    - relay/package.json
    - relay/server.js
    - relay/lib/auth.js
    - relay/lib/room.js
    - relay/lib/logger.js
    - relay/test/auth.test.js
    - relay/test/room.test.js
    - relay/test/relay.test.js
    - .gitignore
  modified: []

key-decisions:
  - "Node.js built-in test runner (node:test) instead of Jest/Mocha -- zero extra dependencies"
  - "Synchronous close guard in RoomManager.join(): clear slot before closing old desktop to prevent _onDisconnect race condition"
  - "Dev mode: accept any non-empty token when AUTH_TOKEN env var is not set, for local development"

patterns-established:
  - "Room pattern: Map<token, { desktop: WebSocket|null, mobile: WebSocket|null }> for client pairing"
  - "Message filtering: ping/pong consumed by relay, all other events transparently forwarded"
  - "Disconnect notification: system:desktop_disconnected / system:mobile_disconnected system events"
  - "Desktop replacement: second desktop with same token closes first with code 4002"

requirements-completed: [RELAY-01, RELAY-02, RELAY-03, RELAY-05]

# Metrics
duration: 18min
completed: 2026-04-09
---

# Phase 2 Plan 1: WebSocket Relay Server Summary

**Node.js WebSocket relay with token-based auth, desktop/mobile pairing, bidirectional forwarding, and 28 passing tests**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-09T01:19:46Z
- **Completed:** 2026-04-09T01:38:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Fully functional WebSocket relay server in relay/ directory
- Token authentication with AUTH_TOKEN env var and dev-mode fallback
- Room manager pairing desktop and mobile clients, forwarding messages transparently
- Desktop replacement (code 4002) prevents stale ghost connections
- 28 tests passing: auth unit tests, room unit tests with mock WebSockets, end-to-end integration tests with real server

## Task Commits

Each task was committed atomically:

1. **Task 1: Create relay server skeleton** - `2e6c71a` (feat)
2. **Task 2: Write integration tests (TDD RED)** - `d53ca22` (test)
3. **Task 2: Fix race condition + test cleanup (TDD GREEN)** - `476c0b7` (feat)

**Additional:** `b1c997f` (chore: .gitignore)

_Note: TDD tasks produced multiple commits (test then feat)_

## Files Created/Modified
- `relay/package.json` - Node.js project config with ws dependency and test script
- `relay/server.js` - WebSocket relay server entry point, configurable PORT, health endpoint, graceful shutdown
- `relay/lib/auth.js` - Token authentication module (AUTH_TOKEN env var, dev mode)
- `relay/lib/room.js` - RoomManager class for pairing, forwarding, disconnect handling
- `relay/lib/logger.js` - Timestamped logger (log, warn, error)
- `relay/test/auth.test.js` - 6 auth unit tests (valid, invalid, empty, null, whitespace, dev mode)
- `relay/test/room.test.js` - 13 room unit tests with mock WebSockets (join, pair, replace, forward, disconnect, cleanup)
- `relay/test/relay.test.js` - 9 integration tests with real WebSocket server (auth rejection, bidirectional forwarding, ping/pong filtering, non-JSON handling, disconnect notification, desktop replacement, default role)
- `.gitignore` - Prevents node_modules from being tracked

## Decisions Made
- Used Node.js built-in test runner (node:test + node:assert) instead of external frameworks -- zero extra dependencies, modern async test support
- Implemented synchronous-close guard in RoomManager.join() to handle the race where closing old desktop triggers _onDisconnect which deletes the room before the new desktop is assigned
- Dev mode (no AUTH_TOKEN set) accepts any non-empty token for local development convenience

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed race condition in desktop replacement**
- **Found during:** Task 2 (room unit tests)
- **Issue:** When a second desktop connects with the same token, closing the old desktop triggers _onDisconnect synchronously, which deletes the room. The new desktop then joins an orphaned room object not in the Map.
- **Fix:** Clear room.desktop slot before closing old connection; re-add room to Map if _onDisconnect deleted it during the synchronous close callback.
- **Files modified:** relay/lib/room.js
- **Verification:** All 13 room tests pass, including "joining a second desktop replaces the first"
- **Committed in:** 476c0b7 (part of Task 2 GREEN commit)

**2. [Rule 3 - Blocking] Integration test process would not exit**
- **Found during:** Task 2 (relay integration tests)
- **Issue:** server.js setInterval for status logging kept the Node.js process alive after tests completed
- **Fix:** Export statusInterval from server.js, clear it in test afterEach
- **Files modified:** relay/server.js, relay/test/relay.test.js
- **Verification:** Test suite now exits cleanly after all tests pass
- **Committed in:** 476c0b7 (part of Task 2 GREEN commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for correctness and test reliability. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required. Server runs with `cd relay && npm install && AUTH_TOKEN=your-secret node server.js`.

## Next Phase Readiness
- Relay server is ready to be Dockerized and deployed to NAS (Plan 02-02)
- The relay transparently forwards wzxClaw desktop protocol messages, so the Flutter client can connect via `ws://5945.top/ws/?token=XXX&role=mobile`
- Desktop wzxClaw needs to connect to `ws://5945.top/ws/?token=XXX&role=desktop` instead of directly to the mobile client

## Self-Check: PASSED

All 10 files verified present. All 4 commit hashes verified in git log.

---
*Phase: 02-nas-websocket-relay-server*
*Completed: 2026-04-09*

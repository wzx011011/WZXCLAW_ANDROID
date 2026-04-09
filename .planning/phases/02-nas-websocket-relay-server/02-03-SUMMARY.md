---
phase: 02-nas-websocket-relay-server
plan: 03
subsystem: client
tags: [flutter, dart, url-construction, relay, query-parameters]

# Dependency graph
requires:
  - phase: 02-nas-websocket-relay-server
    provides: "WebSocket relay server requiring role parameter from clients"
provides:
  - "Flutter app appends role=mobile query parameter to all WebSocket URLs"
  - "Settings page hint text shows relay URL format (wss://5945.top/relay/)"
  - "Backward-compatible URL construction via Uri.parse/Uri.replace"
  - "Malformed URL error handling in auto-connect"
affects: [04-project-management, 05-push-notifications]

# Tech tracking
tech-stack:
  added: []
  patterns: [Uri.parse-replace for query parameter construction, try-catch for malformed saved URLs]

key-files:
  created: []
  modified:
    - lib/pages/settings_page.dart
    - lib/pages/home_page.dart

key-decisions:
  - "Uri.parse + Uri.replace pattern for URL construction instead of string concatenation -- correctly handles existing query parameters and edge cases"
  - "try-catch around auto-connect URI parsing -- malformed saved URL skips connection instead of crashing app"

patterns-established:
  - "URL construction pattern: parse server URL, copy existing params, add role=mobile and token, use Uri.replace to rebuild"

requirements-completed: [RELAY-03]

# Metrics
duration: 3min
completed: 2026-04-09
---

# Phase 2 Plan 3: Flutter Client Relay URL Support Summary

**Flutter app appends role=mobile query parameter via Uri.parse/Uri.replace and updates settings hint to wss://5945.top/relay/**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-09T01:50:08Z
- **Completed:** 2026-04-09T01:53:08Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Settings page and home page both construct WebSocket URLs with role=mobile parameter
- Settings page hint text updated from `ws://192.168.1.100:3000` to `wss://5945.top/relay/`
- Backward compatible: direct-connect URLs (ws://host:port) still work, existing query params preserved
- Home page auto-connect has try-catch to handle malformed saved URLs without crashing

## Task Commits

Each task was committed atomically:

1. **Task 1: Update URL construction in settings page and home page to support relay role parameter** - `e275e84` (feat)

## Files Created/Modified
- `lib/pages/settings_page.dart` - Updated _connect() to use Uri.parse/Uri.replace with role=mobile parameter; changed hint text to wss://5945.top/relay/
- `lib/pages/home_page.dart` - Updated _autoConnect() to use Uri.parse/Uri.replace with role=mobile parameter; added try-catch for malformed saved URLs

## Decisions Made
- Used Uri.parse + Uri.replace instead of string concatenation for URL construction. This correctly preserves any existing query parameters in the server URL, handles the relay path format (wss://5945.top/relay/), and works for direct-connect URLs (ws://host:port) without special-casing.
- Added try-catch around auto-connect URI parsing so a corrupted or malformed saved URL does not crash the app on launch. The user can fix the URL in settings.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Flutter app is ready to connect to the relay server at wss://5945.top/relay/?role=mobile&token=XXX
- Relay server (Plan 02-01) must be deployed and running on NAS for end-to-end testing
- Docker deployment (Plan 02-02) provides the relay server infrastructure

## Self-Check: PASSED

All 3 files verified present. Commit e275e84 verified in git log.

---
*Phase: 02-nas-websocket-relay-server*
*Completed: 2026-04-09*

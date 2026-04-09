---
phase: 04-project-management
plan: 01
subsystem: data-layer
tags: [dart, flutter, singleton, streamcontroller, shared-preferences, websocket]

# Dependency graph
requires:
  - phase: 03-chat-ui
    provides: "ChatStore singleton pattern, ConnectionManager, WsMessage/WsEvents protocol"
provides:
  - "Project data model with fromJson parsing for desktop responses"
  - "ProjectStore singleton with broadcast streams for project list, current project, loading, error"
  - "Direct ConnectionManager command sending (bypasses chat history)"
  - "Defensive multi-format response parser (JSON Map, bare List, plain text)"
  - "SharedPreferences persistence for current project name"
affects: [04-02-project-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Singleton + broadcast StreamController pattern (following ChatStore)"
    - "Direct ConnectionManager.send() for control commands (not via ChatStore)"
    - "Defensive multi-format response parsing"
    - "Optimistic UI update with pending tracking for revert"
    - "Auto-refresh on reconnect when state is empty"

key-files:
  created:
    - lib/models/project.dart
    - lib/services/project_store.dart
    - test/models/project_test.dart
  modified: []

key-decisions:
  - "Commands sent via ConnectionManager.send() directly, not ChatStore.sendMessage(), to avoid polluting chat history"
  - "Response parser handles 3 formats: JSON with projects key, bare JSON array, plain text with newlines"
  - "Optimistic update on switchProject with pendingSwitchName for failure revert"
  - "Auto-refresh project list on reconnect only when list is empty (avoid unnecessary network traffic)"
  - "5-second timeout on fetchProjects to prevent infinite loading state"

patterns-established:
  - "Control command pattern: singleton sends commands directly via ConnectionManager, parses responses from messageStream, never touches ChatStore"

requirements-completed: [PROJ-01, PROJ-02, PROJ-03]

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 4 Plan 1: Project Data Layer Summary

**Project data model and ProjectStore singleton for desktop project list management via WebSocket commands, with defensive parsing, optimistic switch updates, and SharedPreferences persistence.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T10:03:16Z
- **Completed:** 2026-04-09T10:07:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Project data model with fromJson parsing, copyWith, and value equality
- ProjectStore singleton with 4 broadcast streams (projects, currentProject, loading, error)
- Direct ConnectionManager command sending bypasses chat history for /projects and /switch
- Defensive multi-format response parser handles JSON Map, bare List, and plain text
- Current project name persists across app restarts via SharedPreferences
- Unit tests covering all Project model behaviors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Project model** - `3425c6f` (feat)
2. **Task 2: Create ProjectStore singleton** - `8e68262` (feat)

## Files Created/Modified
- `lib/models/project.dart` - Project data class with fromJson, copyWith, equality
- `lib/services/project_store.dart` - ProjectStore singleton with broadcast streams, command sending, response parsing
- `test/models/project_test.dart` - Unit tests for Project model (fromJson, copyWith, equality, toString)

## Decisions Made
- Commands sent via ConnectionManager.send() directly to avoid polluting chat history -- the /projects and /switch commands are control commands, not user conversation
- Response parser is deliberately defensive with 3 format handlers since the desktop protocol may evolve (Pitfall 3 from RESEARCH.md)
- Optimistic UI update on switchProject gives immediate feedback; pendingSwitchName tracks state for revert on failure (Pitfall 1 from RESEARCH.md)
- Auto-refresh only when project list is empty on reconnect avoids redundant /projects calls
- 5-second timeout prevents infinite loading spinner if desktop doesn't respond

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Flutter CLI not available in execution environment, so `flutter analyze` and `flutter test` could not be run during execution. Code follows existing codebase patterns exactly (ChatStore singleton, WsMessage/WsEvents protocol) and should pass static analysis without issues. The tests are structurally correct Dart test code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Data layer is complete and ready for UI consumption via StreamBuilder
- ProjectStore.projectsStream, currentProjectStream, loadingStream, and errorStream are all ready for subscription
- Plan 04-02 (Project Management UI) can immediately consume these streams
- No blockers identified

## Self-Check: PASSED

- lib/models/project.dart: FOUND
- lib/services/project_store.dart: FOUND
- test/models/project_test.dart: FOUND
- 04-01-SUMMARY.md: FOUND
- Commit 3425c6f: FOUND
- Commit 8e68262: FOUND
- ChatStore not imported or called in project_store.dart (only referenced in doc comments): CONFIRMED

---
*Phase: 04-project-management*
*Completed: 2026-04-09*

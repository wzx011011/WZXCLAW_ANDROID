---
phase: 04
fixed_at: 2026-04-09T00:00:00Z
review_path: .planning/phases/04-project-management/04-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-04-09
**Source review:** .planning/phases/04-project-management/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: Optimistic switch update is never reverted if no `switch_result` response arrives

**Files modified:** `lib/services/project_store.dart`
**Commit:** 2c50e04
**Applied fix:** Added a 5-second timeout to `switchProject()` that reverts the optimistic update if no `switch_result` is received. Saves `previousName` before the optimistic update and restores it in the timeout callback, clearing `_pendingSwitchName` and emitting a timeout error message.

### WR-02: Empty catch block silently swallows errors in `_autoConnect`

**Files modified:** `lib/pages/home_page.dart`
**Commit:** 131f08a
**Applied fix:** Changed `catch (_) {}` to `catch (e) { debugPrint('Auto-connect failed: $e'); }` so auto-connect failures produce diagnostic log output instead of being silently swallowed. `debugPrint` is already available via the `flutter/material.dart` import.

### WR-03: `_revealedTimestamps` uses index-based keys that drift when messages are added/removed

**Files modified:** `lib/pages/home_page.dart`
**Commit:** 68bdb5a
**Applied fix:** Replaced `_revealedTimestamps` (a `Set<int>` of list indices) with `_revealedMessageIds` (a `Set<int>` of stable message identifiers). Keys are derived from `msg.id ?? msg.createdAt.millisecondsSinceEpoch`, which provides a stable identifier even for messages not yet persisted to the database. Updated all references: the `_toggleTimestamp` method signature, both `GestureDetector.onTap` call sites in user and assistant bubbles, both `contains` checks for conditional timestamp display, and the `_clearSession` callback.

### WR-04: `ProjectDrawer` reads `ConnectionManager.instance.state` in `build()` without a stream subscription for the disconnected check

**Files modified:** `lib/widgets/project_drawer.dart`
**Commit:** 136491e
**Applied fix:** Wrapped the entire `_buildProjectList()` body in a `StreamBuilder<WsConnectionState>` that subscribes to `ConnectionManager.instance.stateStream`. The disconnected state check now reacts to connection state changes in real time, rather than only reading the snapshot value at build time. The inner `StreamBuilder<List<Project>>` and `StreamBuilder<String?>` for current project are nested inside the connection state builder.

---

_Fixed: 2026-04-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

---
phase: 04-project-management
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/models/project.dart
  - lib/services/project_store.dart
  - lib/widgets/project_list_tile.dart
  - lib/widgets/project_drawer.dart
  - lib/pages/home_page.dart
  - test/models/project_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the project management feature files: data model, singleton store, drawer UI, list tile widget, home page integration, and unit tests. The code is well-structured with good separation of concerns. The Project model has solid test coverage and the store uses defensive parsing for multiple response formats. No critical security or crash-level bugs found. The warnings below relate to robustness edge cases in the store and home page, and one UI issue in the drawer.

## Warnings

### WR-01: Optimistic switch update is never reverted if no `switch_result` response arrives

**File:** `lib/services/project_store.dart:225-241`
**Issue:** When `switchProject()` is called, the current project is optimistically updated immediately (line 232: `_currentProjectName = name`). The revert path only exists in `_handleSwitchResult()` when `success == false` (line 183). However, if the desktop never sends a `switch_result` message at all -- for example, the command is silently ignored, or the response arrives in an unexpected format -- the optimistic update persists permanently with no timeout to revert it. This could leave the UI showing the wrong active project with no indication of failure.
**Fix:** Add a timeout (similar to the 5-second timeout in `fetchProjects`) that reverts the optimistic update if no `switch_result` is received:

```dart
void switchProject(String name) {
  if (ConnectionManager.instance.state != WsConnectionState.connected) {
    _errorController.add('未连接 -- 无法切换项目');
    return;
  }
  final previousName = _currentProjectName;
  _pendingSwitchName = name;
  _currentProjectName = name;
  _notifyListeners();

  ConnectionManager.instance.send(
    WsMessage(
      event: WsEvents.commandSend,
      data: {'content': '/switch $name'},
    ),
  );

  // Timeout: revert if no switch_result within 5 seconds
  Future.delayed(const Duration(seconds: 5), () {
    if (_pendingSwitchName != null && _currentProjectName == name) {
      _currentProjectName = previousName;
      _pendingSwitchName = null;
      _errorController.add('切换项目超时');
      _notifyListeners();
    }
  });
}
```

### WR-02: Empty catch block silently swallows errors in `_autoConnect`

**File:** `lib/pages/home_page.dart:72`
**Issue:** The `catch (_) {}` block on line 72 silently swallows all exceptions during URL parsing and connection initiation. While auto-connect failure is non-critical, a malformed `server_url` in SharedPreferences would cause the app to silently fail to connect on every launch with no diagnostic information. At minimum, this should log the error for debugging since this is a personal tool.
**Fix:** Log the error instead of silently swallowing it:

```dart
} catch (e) {
  debugPrint('Auto-connect failed: $e');
}
```

### WR-03: `_revealedTimestamps` uses index-based keys that drift when messages are added/removed

**File:** `lib/pages/home_page.dart:118-126`
**Issue:** The `_revealedTimestamps` set stores list indices. When new messages arrive and are prepended or inserted (e.g., `loadMoreMessages`), the indices shift, causing the wrong timestamps to be revealed or hidden. This is a logic error that manifests as a UI glitch -- tapping to reveal a timestamp on one message may instead reveal the timestamp on a different message after the list updates.
**Fix:** Use the message's unique identifier (if `ChatMessage` has one) or a combination of role + content hash instead of the list index. For example:

```dart
// If ChatMessage has an id field:
final _revealedMessageIds = <String>{};

void _toggleTimestamp(String messageId) {
  setState(() {
    if (_revealedMessageIds.contains(messageId)) {
      _revealedMessageIds.remove(messageId);
    } else {
      _revealedMessageIds.add(messageId);
    }
  });
}
```

### WR-04: `ProjectDrawer` reads `ConnectionManager.instance.state` in `build()` without a stream subscription for the disconnected check

**File:** `lib/widgets/project_drawer.dart:102-103`
**Issue:** The `_buildProjectList()` method reads `ConnectionManager.instance.state` directly on line 102 (`final connectionState = ConnectionManager.instance.state;`). This value is read during build but the widget does not listen to the connection state stream for this particular check (the footer does via `StreamBuilder`, but the disconnected state guard in the project list does not). If the connection drops after the drawer opens, the disconnected state message will not appear until the drawer is reopened and rebuilt.
**Fix:** Wrap the entire project list builder in a `StreamBuilder<WsConnectionState>` or move the `ConnectionManager.instance.stateStream` StreamBuilder higher up so that the disconnected state check reacts to state changes:

```dart
Widget _buildProjectList() {
  return StreamBuilder<WsConnectionState>(
    stream: ConnectionManager.instance.stateStream,
    initialData: ConnectionManager.instance.state,
    builder: (context, stateSnapshot) {
      final isDisconnected = stateSnapshot.data == WsConnectionState.disconnected;
      return StreamBuilder<List<Project>>(
        stream: ProjectStore.instance.projectsStream,
        initialData: ProjectStore.instance.projects,
        builder: (context, snapshot) {
          final projects = snapshot.data ?? [];
          if (isDisconnected) {
            return /* disconnected state */;
          }
          // ... rest of list
        },
      );
    },
  );
}
```

## Info

### IN-01: `Project.fromJson` accepts empty string as valid project name

**File:** `lib/models/project.dart:21`
**Issue:** When `json['name']` is missing or null, the factory defaults to an empty string. While the tests document this behavior, an empty-named project can be added to the list and displayed in the drawer, which looks odd in the UI. Consider whether this should be filtered out in `_parseProjectList` or treated as invalid.
**Fix:** In `ProjectStore._parseProjectList`, skip projects with empty names:

```dart
if (item is Map<String, dynamic>) {
  final p = Project.fromJson(item);
  if (p.name.isNotEmpty) parsed.add(p);
}
```

### IN-02: `ProjectDrawer.initState` auto-fetch logic runs on every state rebuild if `_hasFetchedOnce` check is insufficient

**File:** `lib/widgets/project_drawer.dart:29-34`
**Issue:** The `_hasFetchedOnce` flag is an instance variable on the `State` object, so it correctly prevents multiple fetches across rebuilds of the same State instance. However, if the drawer is disposed and recreated (e.g., after hot restart or if the Scaffold recreates the drawer), it will fetch again. This is likely fine behavior, but worth noting that it could cause a redundant fetch if the drawer is closed and quickly reopened before the first fetch completes.
**Fix:** Consider adding a timestamp-based throttle (e.g., don't re-fetch if last fetch was within 3 seconds) to avoid redundant network requests.

### IN-03: `_parseTextProjectList` heuristic is fragile

**File:** `lib/services/project_store.dart:125`
**Issue:** The plain text fallback parser on line 125 uses the heuristic `trimmed.contains('\n') || trimmed.contains('项目')` to determine whether incoming text is a project list. Any multi-line assistant response containing the word "项目" (project) would be falsely parsed as a project list, overwriting the actual project data.
**Fix:** This is inherently fragile by design (documented as a fallback), but consider making the heuristic more restrictive, for example requiring both a newline AND a project-like pattern, or checking for the absence of conversational markers before attempting to parse.

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

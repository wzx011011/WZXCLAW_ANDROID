---
phase: 04-project-management
verified: 2026-04-09T12:00:00Z
status: human_needed
score: 13/13 must-haves verified
overrides_applied: 0

human_verification:
  - test: "Open the app, tap hamburger icon in AppBar, verify drawer opens with project list UI"
    expected: "Drawer slides in from left, 304px wide, dark theme (#1A1A2E), header shows '项目' with current project name, project list area appears below, footer shows connection status dot and label"
    why_human: "Visual rendering and animation cannot be verified by code inspection alone"
  - test: "Connect to desktop, verify project list populates from /projects command"
    expected: "After connection, /projects is auto-sent, drawer shows list of project names with status dots (green for running, grey for idle), active project has accent tint and check icon"
    why_human: "Requires actual desktop wzxClaw running to send /projects and receive response"
  - test: "Tap a project in the drawer, verify /switch command is sent and drawer closes"
    expected: "Drawer closes, current project name updates in header, /switch <name> is sent to desktop via WebSocket (bypassing chat history)"
    why_human: "End-to-end command flow requires desktop connection to verify"
  - test: "Pull-to-refresh on project list while connected"
    expected: "RefreshIndicator appears, /projects command re-sent, list updates with latest desktop project data"
    why_human: "Gestural interaction and network behavior need runtime testing"
  - test: "Open drawer while disconnected, verify error state"
    expected: "Shows '未连接 -- 无法获取项目' centered text instead of project list"
    why_human: "State-dependent UI rendering needs runtime verification"
  - test: "Kill and restart the app, open drawer, verify current project name persists"
    expected: "Current project name from previous session still shown in drawer header"
    why_human: "SharedPreferences persistence needs device runtime to verify"
---

# Phase 4: Project Management Verification Report

**Phase Goal:** 查看桌面端活跃项目列表，切换项目，查看项目运行状态。
**Verified:** 2026-04-09T12:00:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ProjectStore can send /projects command and receive project list from desktop | VERIFIED | `fetchProjects()` calls `ConnectionManager.instance.send()` with `WsMessage(event: WsEvents.commandSend, data: {'content': '/projects'})` at line 207-209 of `project_store.dart`. Response parsing via `_handleWsMessage` -> `_tryParseProjectResponse` handles JSON Map, bare List, and plain text formats (lines 85-136). |
| 2 | ProjectStore can send /switch <name> command to switch active project | VERIFIED | `switchProject(String name)` calls `ConnectionManager.instance.send()` with `WsMessage(event: WsEvents.commandSend, data: {'content': '/switch $name'})` at lines 237-242. Includes optimistic update with timeout revert (lines 245-252). |
| 3 | Project model correctly parses desktop response with name and running status | VERIFIED | `Project.fromJson()` at lines 19-24 of `project.dart`: `name` from `json['name']` with empty string fallback, `isRunning = json['status'] == 'running'`. Unit tests cover all edge cases in `test/models/project_test.dart` (13 tests). |
| 4 | Control commands (/projects, /switch) do NOT appear in chat history | VERIFIED | `project_store.dart` uses `ConnectionManager.instance.send()` directly (line 207, 237). No import of `chat_store.dart`. Only reference to ChatStore is in documentation comments (lines 13, 197). |
| 5 | Current project name persists across app restarts via SharedPreferences | VERIFIED | `_loadSavedProject()` reads from SharedPreferences key `current_project_name` (lines 67-74). `_persistCurrentProject()` writes to same key on successful switch (lines 265-268). |
| 6 | Tapping hamburger icon in AppBar opens a Drawer showing project list | VERIFIED | `home_page.dart` line 163: `drawer: const ProjectDrawer()`. Flutter automatically adds hamburger icon to AppBar when `Scaffold.drawer` is set. No custom icon button needed. |
| 7 | Each project shows a status dot (green = running, grey = idle) and name | VERIFIED | `project_list_tile.dart` lines 34-41: 8px circle, `Colors.green` when `project.isRunning`, `Colors.white38` when idle. Name rendered at 15px with `TextOverflow.ellipsis` (lines 44-54). |
| 8 | Currently active project has accent background tint and check icon | VERIFIED | `project_list_tile.dart` line 30: `Color(0xFF6366F1).withOpacity(0.12)` background when `isActive`. Lines 56-61: `Icons.check_circle` in `Color(0xFF6366F1)` when `isActive`. Active comparison: `project.name == currentSnapshot.data` (drawer line 179). |
| 9 | Tapping a project sends /switch command, closes drawer, result appears in chat | VERIFIED | `project_drawer.dart` line 184: `ProjectStore.instance.switchProject(project.name)`. Line 185: `Navigator.pop(context)` closes drawer. The switch result (success/failure) appears as assistant message in chat because the desktop responds via `message:assistant` event. |
| 10 | Pull-to-refresh on project list re-fetches from desktop | VERIFIED | `project_drawer.dart` lines 163-170: `RefreshIndicator` wrapping `ListView.builder`, `onRefresh` calls `ProjectStore.instance.fetchProjects()`. |
| 11 | When disconnected, drawer shows 'not connected' message instead of project list | VERIFIED | `project_drawer.dart` lines 102-129: Outer `StreamBuilder<WsConnectionState>` on `ConnectionManager.instance.stateStream`. When `isDisconnected`, shows centered "未连接 -- 无法获取项目" text. |
| 12 | On first open with empty list, /projects command is auto-sent | VERIFIED | `project_drawer.dart` lines 30-34: `initState()` checks `ProjectStore.instance.projects.isEmpty && !_hasFetchedOnce`, then calls `ProjectStore.instance.fetchProjects()` via `Future.microtask`. Additionally, `project_store.dart` lines 77-81: `_handleConnectionState` auto-refreshes when `connected && _projects.isEmpty`. |
| 13 | Drawer footer shows connection status | VERIFIED | `project_drawer.dart` lines 199-249: `_buildFooter()` with `StreamBuilder<WsConnectionState>`, 8px status dot (green/yellow/red) and `state.label` text at 13px. Follows ConnectionStatusBar pattern. |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/models/project.dart` | Project data model with fromJson parsing | VERIFIED | 44 lines. Has constructor, fromJson, copyWith, operator==, hashCode, toString. No stubs. |
| `lib/services/project_store.dart` | Project list state management, command sending, response parsing | VERIFIED | 292 lines. Singleton with 4 broadcast streams. Sends /projects and /switch via ConnectionManager. Defensive multi-format parser. SharedPreferences persistence. 5s timeout on fetch and switch. |
| `lib/widgets/project_list_tile.dart` | Single project row widget with status dot, name, active highlight | VERIFIED | 67 lines. Status dot (8px, green/grey), name text, check icon for active, InkWell tap handler. |
| `lib/widgets/project_drawer.dart` | Drawer widget with header, project list, empty state, footer | VERIFIED | 250 lines. 304px width, 120px header, StreamBuilder project list, RefreshIndicator, empty/disconnected states, connection status footer. |
| `lib/pages/home_page.dart` | HomePage with drawer property added to Scaffold | VERIFIED | Line 11: `import '../widgets/project_drawer.dart'`. Line 163: `drawer: const ProjectDrawer()`. All existing functionality (messages, streaming, input, connection status) unchanged. |
| `test/models/project_test.dart` | Unit tests for Project model | VERIFIED | 126 lines. 13 tests covering fromJson, constructor defaults, copyWith, equality, toString. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `project_store.dart` | `connection_manager.dart` | `ConnectionManager.instance.send()` for /projects and /switch | WIRED | Lines 207-209 (`/projects`), 237-242 (`/switch`). Both use `WsMessage(event: WsEvents.commandSend, ...)`. |
| `project_store.dart` | `connection_manager.dart` | `ConnectionManager.instance.messageStream.listen()` | WIRED | Line 59-60: subscribes to `messageStream` in `_init()`. Filters on `WsEvents.messageAssistant` (line 86). |
| `project_store.dart` | `connection_manager.dart` | `ConnectionManager.instance.stateStream.listen()` | WIRED | Line 62: subscribes to `stateStream` for auto-refresh on reconnect. |
| `project_drawer.dart` | `project_store.dart` | `StreamBuilder` on `projectsStream` and `currentProjectStream` | WIRED | Lines 80, 110, 172: StreamBuilder subscriptions. Lines 33, 167, 184: method calls to `fetchProjects()` and `switchProject()`. |
| `project_drawer.dart` | `connection_manager.dart` | `StreamBuilder` on `stateStream` | WIRED | Lines 102-103 (outer connection state), 207-209 (footer connection status). |
| `home_page.dart` | `project_drawer.dart` | `Scaffold.drawer` property | WIRED | Line 163: `drawer: const ProjectDrawer()`. Flutter auto-adds hamburger icon to AppBar. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| ProjectDrawer | `_projects` via `projectsStream` | `ProjectStore._projectsController` | FLOWING (conditional) | ProjectStore populates `_projects` from WebSocket messages via `_parseProjectList()` and `_parseTextProjectList()`. Data flows: ConnectionManager._messageController -> ProjectStore._handleWsMessage -> _tryParseProjectResponse -> _parseProjectList -> _projectsController.add(). Requires desktop connection. |
| ProjectDrawer | `_currentProjectName` via `currentProjectStream` | `ProjectStore._currentProjectController` | FLOWING (conditional) | Populated from: (1) SharedPreferences on init (`_loadSavedProject`), (2) `_handleSwitchResult` on successful switch, (3) optimistic update in `switchProject()`. |
| ProjectDrawer | `WsConnectionState` via `stateStream` | `ConnectionManager._stateController` | FLOWING | ConnectionManager drives state machine from actual WebSocket connection events. Data is real-time. |
| ProjectListTile | `project.isRunning` | `Project.fromJson()` | FLOWING (conditional) | Value comes from `json['status'] == 'running'` in desktop response. Depends on desktop sending status field. |

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable entry points -- Flutter app requires emulator/device to run, and desktop wzxClaw must be connected for meaningful testing)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PROJ-01 | 04-01, 04-02 | 用户能查看桌面端当前活跃的项目列表 | SATISFIED | ProjectStore.fetchProjects() sends /projects command, parses response into Project list. ProjectDrawer renders via StreamBuilder on projectsStream. Drawer header shows "项目" with current project name. Auto-fetch on first open. |
| PROJ-02 | 04-01, 04-02 | 用户能切换活跃项目（发送切换指令到桌面端） | SATISFIED | ProjectStore.switchProject(name) sends /switch <name> via ConnectionManager. ProjectDrawer onTap calls switchProject() and Navigator.pop(). Optimistic update with timeout revert. Result persisted to SharedPreferences. |
| PROJ-03 | 04-01, 04-02 | 显示每个项目的基本状态（是否有任务在运行） | SATISFIED | Project model has `isRunning` field from `json['status'] == 'running'`. ProjectListTile renders 8px green dot when running, grey dot when idle. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `project_drawer.dart` | 23 | `bool _isLoading = false;` declared but never updated | Info | Dead code -- `_isLoading` is declared but never set to `true`. The empty state check on line 133 (`projects.isEmpty && !_isLoading`) always evaluates as if not loading. However, this has no functional impact because the loading state is handled reactively through StreamBuilder on `projectsStream` -- when `fetchProjects()` succeeds, `_notifyListeners()` pushes new data and the UI updates. The dead code is harmless but could be cleaned up. |

No blockers or warnings found. All artifacts are substantive (well above stub thresholds), properly wired, and data flows from real sources.

### Human Verification Required

### 1. Drawer Visual Rendering and Interaction

**Test:** Open the app, tap hamburger icon in AppBar, verify drawer opens with full project management UI.
**Expected:** Drawer slides in from left, 304px wide, dark theme (#1A1A2E), 120px header shows "项目" with accent bottom border and current project name, project list area below, footer shows connection status dot and label.
**Why human:** Visual rendering, animation, and layout dimensions can only be confirmed on a real device or emulator.

### 2. Project List Population (End-to-End)

**Test:** Connect to desktop wzxClaw, open drawer, verify project list populates from /projects command response.
**Expected:** After connection, /projects is auto-sent, drawer shows list of project names with status dots (green for running, grey for idle), active project has accent tint and check icon.
**Why human:** Requires actual desktop wzxClaw running and connected via WebSocket relay to verify real data flows end-to-end.

### 3. Project Switch (End-to-End)

**Test:** Tap a different project in the drawer, verify /switch command is sent and drawer closes.
**Expected:** Drawer closes immediately (Navigator.pop), current project name updates in drawer header, /switch <name> sent to desktop via WebSocket without appearing in chat history.
**Why human:** End-to-end command flow requires desktop connection to verify the switch actually takes effect.

### 4. Pull-to-Refresh

**Test:** While connected, pull down on the project list in the drawer.
**Expected:** RefreshIndicator appears, /projects command re-sent, list updates with latest data from desktop.
**Why human:** Gestural interaction requires device/emulator to test.

### 5. Disconnected State

**Test:** Open drawer while disconnected (no desktop connection).
**Expected:** Shows centered "未连接 -- 无法获取项目" text instead of project list.
**Why human:** State-dependent UI rendering needs runtime verification with connection state changes.

### 6. Persistence Across Restart

**Test:** Connect, switch to a project, kill the app, relaunch, open drawer.
**Expected:** Current project name from previous session still shown in drawer header.
**Why human:** SharedPreferences persistence requires device runtime to verify.

### Gaps Summary

All 13 observable truths verified against actual code. All 5 artifacts exist, are substantive, and are properly wired. All 6 key links verified. Data flows from real sources (WebSocket via ConnectionManager -> ProjectStore -> StreamBuilder -> UI). No stubs, no missing implementations, no blockers.

The phase achieves its goal in code: project list display, project switching, and status indication are all implemented and wired end-to-end. The implementation is complete from data layer (Project model + ProjectStore singleton) through UI layer (ProjectListTile + ProjectDrawer + HomePage integration).

Human verification is required to confirm visual rendering, gestural interactions, and end-to-end behavior with an actual desktop connection -- these cannot be verified by code inspection alone.

---

_Verified: 2026-04-09T12:00:00Z_
_Verifier: Claude (gsd-verifier)_

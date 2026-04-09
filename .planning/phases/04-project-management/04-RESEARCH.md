# Phase 4: Project Management - Research

**Researched:** 2026-04-09
**Domain:** Flutter UI (Drawer widget, command-based project list, state management for project data)
**Confidence:** HIGH

## Summary

This phase adds a project management drawer to the existing wzxClaw Android chat interface. The mobile app sends `/projects` and `/switch <name>` commands through the existing WebSocket protocol (via `ChatStore.sendMessage()`), receives structured responses as `message:assistant` events, and displays project lists with running/idle status in a Material Drawer.

The implementation is straightforward because it reuses the existing singleton pattern (ChatStore + ConnectionManager) and the command-based protocol already established in Phases 1-3. No new WebSocket events or protocol changes are needed. The key technical decisions are: (1) use `Scaffold.drawer` with a custom `Drawer` widget rather than `NavigationDrawer`, since this drawer contains non-navigation content (dynamic project list with status dots) and needs full layout control; (2) create a `ProjectStore` singleton following the existing ChatStore pattern; (3) parse desktop responses from assistant messages to extract project data.

**Primary recommendation:** Use `Scaffold.drawer` with a custom `Drawer` widget, a `ProjectStore` singleton for state, and parse project data from `message:assistant` responses. Keep the scope minimal -- no new dependencies needed.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Project list query: send `command:send` with content `/projects` -- reuse existing protocol
- Project switch: send `command:send` with content `/switch <project-name>` -- command-style
- Desktop responds with structured data via `message:assistant` event
- Project list in a Drawer (side panel) opened from app bar or swipe
- Green dot = AI task running, grey dot = idle
- Switching sends command, result shown as assistant message in chat

### Claude's Discretion
- Drawer widget structure, project list parsing, exact response format handling
- How to detect project status from desktop responses

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROJ-01 | User can view the list of active projects on the desktop | Drawer with project list, fetched via `/projects` command, parsed from `message:assistant` response |
| PROJ-02 | User can switch the active project (send switch command to desktop) | Tap project in drawer sends `/switch <name>` via ChatStore.sendMessage(), drawer closes, response appears in chat |
| PROJ-03 | Display basic status for each project (whether a task is running) | Green/grey status dot per project, extracted from desktop response data |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter framework | >=3.0.0 | UI framework (Drawer, ListTile, StreamBuilder) | Already in use, `useMaterial3: true` already set |
| web_socket_channel | ^3.0.0 | WebSocket communication | Already in use for all desktop communication |
| shared_preferences | ^2.2.0 | Persist selected project name locally | Already in use for settings |

### Supporting

No new packages are needed for this phase. The project uses the standard Flutter `Drawer` widget from `package:flutter/material.dart`, which is already imported via the Material library.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `Drawer` via `Scaffold.drawer` | `NavigationDrawer` (M3 widget) | NavigationDrawer is designed for fixed destination navigation (tabs/pages), not dynamic lists with custom status indicators. Our drawer has a dynamic project list, custom header with accent line, status dots, and pull-to-refresh -- all of which require the free-form layout of the classic `Drawer`. NavigationDrawer's `NavigationDrawerDestination` constrains each item to icon+label only. [VERIFIED: Flutter API docs] |
| New singleton `ProjectStore` | Extend `ChatStore` to hold project data | Mixing project state into ChatStore violates single responsibility. ChatStore handles message streaming lifecycle; ProjectStore handles project list lifecycle. They are independent concerns. Following the existing singleton pattern keeps code consistent. |

**Installation:** No new packages required.

**Version verification:** All packages already in `pubspec.yaml` from previous phases. No version checks needed.

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── config/
│   └── app_config.dart          # (existing)
├── models/
│   ├── chat_message.dart        # (existing)
│   ├── connection_state.dart    # (existing)
│   ├── ws_message.dart          # (existing)
│   └── project.dart             # NEW -- Project model
├── services/
│   ├── chat_database.dart       # (existing)
│   ├── chat_store.dart          # (existing)
│   ├── connection_manager.dart  # (existing)
│   └── project_store.dart       # NEW -- Project list state management
├── pages/
│   ├── home_page.dart           # MODIFY -- add drawer property + leading icon
│   └── settings_page.dart       # (existing)
├── widgets/
│   ├── connection_status_bar.dart  # (existing)
│   ├── project_drawer.dart          # NEW -- Drawer widget
│   └── project_list_tile.dart       # NEW -- Single project row widget
├── main.dart                    # (existing)
```

### Pattern 1: Singleton Store (following existing ChatStore pattern)

**What:** A singleton class with broadcast `StreamController`s for reactive state, matching the exact pattern used by `ChatStore` and `ConnectionManager`.

**When to use:** For all service-level state management in this project. The codebase consistently uses this pattern.

**Example:**
```dart
// Following the existing ChatStore singleton pattern
class ProjectStore {
  static final ProjectStore _instance = ProjectStore._();
  static ProjectStore get instance => _instance;
  ProjectStore._();

  final _projectsController = StreamController<List<Project>>.broadcast();
  Stream<List<Project>> get projectsStream => _projectsController.stream;

  final _currentProjectController = StreamController<String?>.broadcast();
  Stream<String?> get currentProjectStream => _currentProjectController.stream;

  List<Project> _projects = [];
  String? _currentProjectName;

  // ... methods for fetching, switching, parsing
}
```

[VERIFIED: Existing codebase -- `lib/services/chat_store.dart` lines 10-33]

### Pattern 2: Scaffold Drawer Integration

**What:** Assign a `Drawer` widget to the `Scaffold.drawer` property. The `Scaffold` automatically handles the hamburger icon in the `AppBar` (when `drawer` is set), the swipe gesture, and the scrim/backdrop.

**When to use:** Standard way to add a side panel in Material apps.

**Example:**
```dart
// In home_page.dart, modify existing Scaffold:
Scaffold(
  appBar: AppBar(
    // leading icon is auto-generated by Scaffold when drawer is set
    title: const Text('wzxClaw'),
    // ... existing actions
  ),
  drawer: const ProjectDrawer(),  // ADD THIS
  body: Column(
    // ... existing body
  ),
);
```

[VERIFIED: Flutter API docs -- Drawer class, "The AppBar automatically displays an appropriate IconButton to show the Drawer when a Drawer is available in the Scaffold"]

### Pattern 3: Command-Based Protocol (reusing existing)

**What:** Send `/projects` and `/switch <name>` as text commands through the existing `ChatStore.sendMessage()` method. Desktop processes them and responds via `message:assistant`.

**When to use:** For all desktop interaction in this app. The existing protocol already sends commands as `command:send` events with `data: { content: text }`.

**Example:**
```dart
// Fetch projects:
ChatStore.instance.sendMessage('/projects');

// Switch project:
ChatStore.instance.sendMessage('/switch MyProject');
```

[VERIFIED: Existing codebase -- `lib/services/chat_store.dart` line 185-197, `sendMessage()` creates a `WsMessage` with `event: WsEvents.commandSend` and `data: { 'content': text }`]

### Pattern 4: Response Parsing from Assistant Messages

**What:** The desktop responds to `/projects` with a structured message via the `message:assistant` event. The `ProjectStore` listens to `ConnectionManager.instance.messageStream` and intercepts responses to project-related commands.

**When to use:** When the desktop sends structured data as part of the existing message protocol.

**Example:**
```dart
// ProjectStore subscribes to messageStream like ChatStore does
void _init() {
  _wsSubscription =
      ConnectionManager.instance.messageStream.listen(_handleWsMessage);
}

void _handleWsMessage(WsMessage wsMsg) {
  if (wsMsg.event == WsEvents.messageAssistant) {
    // Check if the response is a project list
    _tryParseProjectResponse(wsMsg.data);
  }
}
```

[VERIFIED: Existing codebase -- `lib/services/chat_store.dart` line 42-44]

### Anti-Patterns to Avoid

- **Putting project logic in HomePage:** HomePage is already 400+ lines. Keep UI thin; project state belongs in ProjectStore.
- **Creating new WebSocket events:** The CONTEXT.md locks the decision to reuse `command:send` + `message:assistant`. Do not invent `event: project:list` or similar.
- **Using NavigationDrawer:** It constrains items to icon+label destinations. Our drawer needs status dots, custom header with accent line, pull-to-refresh, and dynamic content. Use classic `Drawer` instead.
- **Persisting project list in SQLite:** Project data is ephemeral (comes from desktop). Persist only the current project name in SharedPreferences for UX continuity. The full list refreshes from desktop each time.
- **Polling for project status:** Do not set up timers to periodically request `/projects`. Fetch on demand (drawer open, pull-to-refresh).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drawer animation/gesture | Custom slide-in panel | `Scaffold.drawer` | Flutter's built-in Drawer handles open/close animation, swipe gesture, scrim, and back button dismissal automatically |
| Pull-to-refresh | Custom gesture detector + animation | `RefreshIndicator` | Standard Material widget handles pull gesture, loading indicator, and callback |
| Reactive state updates | Manual setState chains | `StreamController.broadcast()` + `StreamBuilder` | Already the project's established pattern; avoids prop drilling |
| Project name persistence | Custom file I/O | `SharedPreferences` | Already in use for settings; simple key-value storage |

**Key insight:** The existing codebase has already established strong patterns (singleton stores, broadcast streams, StreamBuilder consumption). Follow them exactly rather than introducing new patterns.

## Common Pitfalls

### Pitfall 1: Race Condition on Project Switch Feedback

**What goes wrong:** User taps project in drawer, drawer closes immediately, but the desktop hasn't responded yet. If the switch fails, the drawer is already closed and the user sees no error.

**Why it happens:** Optimistic UI update (closing drawer + highlighting new project) happens before server confirmation.

**How to avoid:** Implement a two-phase update: (1) close drawer and update optimistic highlight immediately, (2) listen for the desktop response. If the response indicates failure, show a SnackBar on the HomePage with the error message. The `ProjectStore` should have a `pendingSwitch` state that reverts on failure.

**Warning signs:** Project highlight changes but desktop never actually switched.

### Pitfall 2: Command Echo Appears in Chat

**What goes wrong:** When user sends `/projects`, the command text appears as a user bubble in chat, cluttering the conversation.

**Why it happens:** `ChatStore.sendMessage()` adds the message to the local message list AND sends it to the desktop. The `/projects` command is a control command, not a conversation message.

**How to avoid:** `ProjectStore` should call `ConnectionManager.instance.send()` directly (bypassing ChatStore) to avoid adding control commands to the chat history. Alternatively, add a `sendCommand(String text)` method to ChatStore that sends via WebSocket but does not add to local message list.

**Warning signs:** Chat history filled with `/projects` and `/switch` commands.

### Pitfall 3: Parsing Unstructured Desktop Responses

**What goes wrong:** Desktop wzxClaw may not support `/projects` yet, or may return plain text instead of structured JSON. The parser crashes or shows garbage.

**Why it happens:** The mobile-side contract is being defined in this phase; the desktop may not have implemented it yet.

**How to avoid:** Design the parser defensively: (1) If `data` is a JSON array of objects with `name` and `status` fields, parse it. (2) If `data` is a plain string that looks like a list (newline-separated names), parse it as names with unknown status. (3) If parsing fails entirely, show the raw response in the drawer as a fallback. The 04-CONTEXT.md notes: "Desktop wzxClaw may not support /projects and /switch commands yet -- this phase defines the mobile side contract."

**Warning signs:** Drawer shows "暂无项目" when desktop is clearly running projects.

### Pitfall 4: Drawer Not Closing on Project Tap

**What goes wrong:** User taps a project, the command is sent, but the drawer stays open.

**Why it happens:** The drawer needs to be explicitly closed with `Navigator.pop(context)` when a project is tapped.

**How to avoid:** In `ProjectListTile.onTap`, after calling `ProjectStore.instance.switchProject(name)`, call `Navigator.pop(context)` to close the drawer. The drawer's `BuildContext` is accessible from within the Drawer widget tree.

**Warning signs:** Drawer stays open after tapping a project.

### Pitfall 5: Stale Project List After Desktop Session Change

**What goes wrong:** User switches projects from the desktop, but the mobile drawer still shows the old project as active.

**Why it happens:** Project list is only refreshed when the user opens the drawer and triggers a fetch.

**How to avoid:** Auto-refresh project list when: (1) drawer opens for the first time with empty list, (2) user explicitly pulls to refresh, (3) connection state changes from disconnected to connected. The UI-SPEC confirms this: "On first open: auto-send `/projects` command if project list is empty."

**Warning signs:** Active project highlight in drawer doesn't match what desktop is actually running.

## Code Examples

### Drawer Widget Structure

```dart
// lib/widgets/project_drawer.dart
// Source: [Flutter API docs -- Drawer class]
class ProjectDrawer extends StatelessWidget {
  const ProjectDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      width: 304,
      child: Column(
        children: [
          _buildHeader(),       // "项目" title + accent line + current project
          Expanded(
            child: StreamBuilder<List<Project>>(
              stream: ProjectStore.instance.projectsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () => ProjectStore.instance.fetchProjects(),
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return ProjectListTile(
                        project: snapshot.data![index],
                        isActive: snapshot.data![index].name ==
                            ProjectStore.instance.currentProjectName,
                        onTap: () {
                          ProjectStore.instance
                              .switchProject(snapshot.data![index].name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildFooter(context),  // Connection status
        ],
      ),
    );
  }
}
```

[VERIFIED: Flutter API docs -- Drawer constructor accepts `width`, `backgroundColor`, `child`]

### Project Model

```dart
// lib/models/project.dart
class Project {
  final String name;
  final bool isRunning;  // true = AI task active, false = idle

  const Project({required this.name, this.isRunning = false});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String? ?? '',
      isRunning: json['status'] == 'running',
    );
  }
}
```

### Sending Commands Without Chat Pollution

```dart
// Option A: ProjectStore sends directly via ConnectionManager (recommended)
class ProjectStore {
  // ...

  void fetchProjects() {
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.commandSend, data: {'content': '/projects'}),
    );
  }

  void switchProject(String name) {
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.commandSend, data: {'content': '/switch $name'}),
    );
  }
}

// Option B: Add sendCommand() to ChatStore
// (only if ChatStore modification is preferred over direct ConnectionManager use)
```

[VERIFIED: Existing codebase -- `ConnectionManager.send()` at `lib/services/connection_manager.dart` line 138-150]

### HomePage Modification (minimal)

```dart
// In home_page.dart -- ONLY add the drawer property:
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      // leading icon is auto-generated by Scaffold when drawer is set
      title: const Text('wzxClaw'),
      actions: [
        // ... existing actions unchanged
      ],
    ),
    drawer: const ProjectDrawer(),  // <-- ADD THIS LINE
    body: Column(
      children: [
        // ... existing body unchanged
      ],
    ),
  );
}
```

[VERIFIED: Flutter API docs -- "The AppBar automatically displays an appropriate IconButton to show the Drawer when a Drawer is available in the Scaffold."]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NavigationDrawer` for all drawers | `Drawer` for custom content, `NavigationDrawer` for fixed destinations | Flutter 3.x / Material 3 | Use `Drawer` since our content is dynamic, not fixed destinations |
| `GetX` / `Provider` for state | Singleton + `StreamController.broadcast()` | This project's established pattern from Phase 1 | Follow existing pattern; no new state management library |

**Deprecated/outdated:**
- Manual drawer open/close with `GlobalKey<ScaffoldState>`: Flutter now auto-handles the hamburger icon when `Scaffold.drawer` is set. No need for `GlobalKey`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Desktop wzxClaw will eventually support `/projects` and `/switch` commands, but may not support them yet at the time of this phase | Pattern 3, Pitfall 3 | Mobile code would work but show "暂无项目" until desktop implements the commands. Need graceful handling of unrecognized commands. |
| A2 | Desktop response to `/projects` will be a JSON array of `{name, status}` objects sent via `message:assistant` event | Pattern 4, Pitfall 3 | If desktop returns plain text or a different JSON structure, the parser needs adjustment. Defensive parsing mitigates this. |
| A3 | Project status (`isRunning`) can be determined from the desktop's response to `/projects` | PROJ-03 | If desktop doesn't include task status in project list, PROJ-03 cannot be fully implemented. Would need to show all projects as "unknown status". |
| A4 | The current project name can be persisted in `SharedPreferences` for UX continuity | Architecture Patterns | Low risk -- SharedPreferences is already in use and suitable for simple string storage. |

## Open Questions

1. **Desktop response format for `/projects`**
   - What we know: Mobile sends `/projects` command via `command:send`. Desktop responds via `message:assistant`.
   - What's unclear: The exact JSON structure of the response. Will it be `{ "projects": [{ "name": "...", "status": "running|idle" }] }` or a bare array `[{ "name": "...", "status": "running|idle" }]` or plain text?
   - Recommendation: Design `ProjectStore` parser to handle both a `data.projects` array (if `data` is a Map) and a bare array (if `data` is a List). Add a fallback that shows raw text if parsing fails. This can be refined once desktop implementation is confirmed.

2. **How to detect current project on initial load**
   - What we know: The drawer should highlight the currently active project.
   - What's unclear: How does the mobile app know which project is active? Does `/projects` response include an `active` flag, or does the mobile track it from the last `/switch` command?
   - Recommendation: Track current project from the last successful `/switch` command (persist to SharedPreferences). On `/projects` response, check if any project matches the persisted name. Also, if the desktop response includes an `active` field, use that as the source of truth.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified -- this phase is purely code changes using existing Flutter framework and packages already in pubspec.yaml).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) -- already in dev_dependencies |
| Config file | none |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROJ-01 | Drawer opens and shows project list after `/projects` fetch | widget | `flutter test test/widgets/project_drawer_test.dart` | No -- Wave 0 |
| PROJ-02 | Tapping project sends `/switch` command and closes drawer | widget | `flutter test test/widgets/project_drawer_test.dart` | No -- Wave 0 |
| PROJ-03 | Project list items show green dot for running, grey for idle | unit | `flutter test test/models/project_test.dart` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/models/project_test.dart` -- covers Project model creation and JSON parsing (PROJ-03)
- [ ] `test/services/project_store_test.dart` -- covers ProjectStore singleton, fetchProjects, switchProject, response parsing (PROJ-01, PROJ-02)
- [ ] `test/widgets/project_drawer_test.dart` -- covers drawer rendering, project list display, tap handling
- [ ] `test/widgets/project_list_tile_test.dart` -- covers single tile rendering with status dot and active highlight
- [ ] Framework install: Flutter SDK -- NOT detected in PATH (may be installed elsewhere or needs installation)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A -- reuses existing WebSocket connection |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | yes | Project names from desktop are displayed as-is (trusted source). `/switch` command sends user-selected project name back to desktop -- no sanitization needed since the name came from the desktop originally. |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for Flutter/Dart

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection via project name | Tampering | Project names are displayed, not executed. `/switch <name>` is sent as a string to desktop which decides what to do. No shell execution on mobile side. |
| Malformed desktop response | Tampering | Defensive JSON parsing with try/catch. ProjectStore never crashes on bad data. |

## Project Constraints (from CLAUDE.md)

- **Tech Stack**: Flutter (Dart) -- no deviation
- **Target Platform**: Android only -- no iOS-specific code
- **Network**: Through NAS 5945.top WebSocket Relay -- reuse existing ConnectionManager
- **Desktop Integration**: Reuse wzxClaw desktop WebSocket protocol and message format -- no new events
- **Scope**: Personal tool -- no multi-user, no auth beyond existing token
- **Code conventions**: `prefer_single_quotes: true`, `require_trailing_commas: true`, `avoid_print: false` (from analysis_options.yaml)

## Sources

### Primary (HIGH confidence)
- [Flutter Drawer class API docs](https://api.flutter.dev/flutter/material/Drawer-class.html) -- Drawer constructor, Scaffold.drawer integration, auto hamburger icon
- [Flutter NavigationDrawer class API docs](https://api.flutter.dev/flutter/material/NavigationDrawer-class.html) -- M3 NavigationDrawer API, children/onDestinationSelected pattern (ruled out for this use case)
- [Flutter official -- Add a drawer to a screen](https://docs.flutter.dev/cookbook/design/drawer) -- Drawer usage pattern
- Existing codebase verification -- all files in `lib/` read and analyzed

### Secondary (MEDIUM confidence)
- [Flutter Architecture Recommendations](https://docs.flutter.dev/app-architecture/recommendations) -- Singleton service pattern confirmation
- [Flutter Navigation Drawer with Material 3 (2025)](https://www.youtube.com/watch?v=a5lPt6XlE04) -- M3 drawer patterns

### Tertiary (LOW confidence)
- None -- all research was verified against existing codebase or official Flutter docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new packages needed, all existing
- Architecture: HIGH -- follows established singleton + StreamBuilder patterns already in codebase
- Pitfalls: HIGH -- derived from codebase analysis and Flutter API behavior

**Research date:** 2026-04-09
**Valid until:** 90 days (Flutter API is stable; project patterns are established)

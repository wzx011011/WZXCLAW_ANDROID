---
phase: 06-push-notifications-offline-queue
plan: 03
subsystem: UI - Settings & Home
tags: [push-notifications, settings-toggle, offline-sync, snackbar, ui]
dependency_graph:
  requires: [06-02]
  provides: [NOTI-03]
  affects: [settings_page.dart, home_page.dart]
tech_stack:
  added: []
  patterns: [SharedPreferences persistence, imperative StreamSubscription in initState]
key_files:
  created: []
  modified:
    - lib/pages/settings_page.dart
    - lib/pages/home_page.dart
decisions:
  - "Show offline sync SnackBar on every reconnection (not just when queued messages exist) since the Flutter client has no way to know if the relay has queued messages until they arrive"
metrics:
  duration_seconds: 185
  completed_date: 2026-04-09T14:53:36Z
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 06 Plan 03: Settings Push Toggle + Offline Sync SnackBar Summary

Push notification toggle (SwitchListTile) added to Settings page with SharedPreferences persistence and real FCM token registration/unregistration via ConnectionManager. Offline sync SnackBar added to Home page on WebSocket reconnection.

## What Changed

### Task 1: Push notification toggle in SettingsPage

- Added `firebase_messaging` and `ws_message` imports
- Added `_pushEnabled` state field (defaults to `true`) and `_pushEnabledKey` constant
- Loaded push enabled state from SharedPreferences in `_loadSavedValues()`
- Added `_togglePushNotifications()` method that:
  - Persists toggle state to SharedPreferences
  - When enabled: retrieves real FCM token via `FirebaseMessaging.instance.getToken()` and sends `fcm:register` with token to relay
  - When disabled: sends `fcm:register` with `{'token': null}` to unregister from relay
- Added `SwitchListTile` widget after connection state display with:
  - Title: "推送通知", Subtitle: "AI 任务完成时发送通知"
  - Accent color `0xFF6366F1` when active, white thumb with white24 track when inactive

### Task 2: Offline sync SnackBar in HomePage

- Added `_prevState` field initialized to `WsConnectionState.disconnected`
- Added `_connectionStateSub` typed `StreamSubscription<WsConnectionState>?`
- Added state stream listener in `initState()` that detects transition from non-connected to connected state
- Shows `SnackBar` with text "正在同步离线消息...", background `0xFF16213E`, floating behavior, 3-second duration
- Cancels subscription in `dispose()`

## Decisions Made

1. **SnackBar on every reconnection** -- The Flutter client cannot know whether the relay has queued offline messages. Showing the SnackBar on every reconnect serves as a brief indicator; if no queued messages arrive, it harmlessly disappears after 3 seconds.

## Deviations from Plan

None - plan executed exactly as written.

## Auth Gates

None encountered.

## Threat Flags

None - no new security-relevant surface introduced. The SharedPreferences key stores only a boolean preference (T-06-08 disposition: accept).

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: lib/pages/settings_page.dart
- FOUND: lib/pages/home_page.dart
- FOUND: .planning/phases/06-push-notifications-offline-queue/06-03-SUMMARY.md
- FOUND: 46972d3 (Task 1 commit)
- FOUND: d660acf (Task 2 commit)

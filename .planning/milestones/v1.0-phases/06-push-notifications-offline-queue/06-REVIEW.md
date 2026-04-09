---
phase: 06
status: findings
severity_counts: {critical: 0, high: 0, medium: 3, low: 4, info: 3}
created: 2026-04-09
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 8
**Status:** findings

## Files Reviewed

- `relay/lib/fcm.js`
- `relay/lib/room.js`
- `relay/server.js`
- `lib/services/notification_service.dart`
- `lib/main.dart`
- `lib/models/ws_message.dart`
- `lib/pages/settings_page.dart`
- `lib/pages/home_page.dart`

## Summary

Phase 06 adds FCM push notifications (relay-side and Flutter-side) plus an offline message queue to the relay server. The implementation is generally solid: graceful FCM degradation when credentials are missing, proper Dart isolate handling for background messages, correct `WidgetsBindingObserver` usage, and well-structured offline queue with TTL cleanup. The .gitignore correctly excludes credential files. No critical or high-severity issues were found.

The findings below are medium-severity race conditions and missing error handling, plus lower-severity code quality items.

## Medium Issues

### MD-01: FCM token logged in full on the relay server

**File:** `relay/lib/room.js:148`
**Issue:** The FCM token is stored and logged with only the first 8 characters masked. While FCM tokens are not secrets in the same vein as private keys (they rotate and are device-bound), logging even partial tokens in production logs is unnecessary exposure. More importantly, the token is stored in-memory with no validation or sanitization. If a malicious mobile client sends an extremely long string as a token, it stays in memory indefinitely.

**Fix:** Add a length cap on the stored FCM token:
```javascript
if (role === 'mobile' && event === 'fcm:register') {
  const token = parsed.data?.token || null;
  room.fcmToken = (typeof token === 'string' && token.length <= 512) ? token : null;
  log(`Room [${token}]: FCM token ${room.fcmToken ? 'registered' : 'unregistered'}`);
  return;
}
```

### MD-02: StreamSubscription leak in NotificationService._registerTokenOnConnect

**File:** `lib/services/notification_service.dart:204-210`
**Issue:** `_registerTokenOnConnect()` creates a `StreamSubscription` via `ConnectionManager.instance.stateStream.listen(...)` but never stores or cancels it. Since `NotificationService` is a singleton with no `dispose()` call in the app lifecycle, this subscription persists forever. If the app were ever restructured to recreate the service, this would leak. More practically, the subscription is never cancelled even though `NotificationService.dispose()` exists and removes the `WidgetsBindingObserver`.

**Fix:** Store the subscription and cancel it in `dispose()`:
```dart
StreamSubscription<WsConnectionState>? _connectSub;

void _registerTokenOnConnect() {
  _connectSub = ConnectionManager.instance.stateStream.listen((state) {
    if (state == WsConnectionState.connected && _fcmToken != null) {
      _sendTokenToRelay(_fcmToken!);
    }
  });
}

void dispose() {
  _connectSub?.cancel();
  WidgetsBinding.instance.removeObserver(this);
}
```

### MD-03: Race condition -- FCM token registration sent before auth completes

**File:** `lib/pages/settings_page.dart:82-100`
**Issue:** `_togglePushNotifications` calls `ConnectionManager.instance.send(...)` without checking whether the WebSocket is currently connected. The `send()` method queues the message if disconnected, which means the FCM registration will be sent on the next reconnect. However, the room on the relay side may have already been cleaned up (no mobile, no desktop, empty queue) by the time the queued message arrives, causing the `fcm:register` message to be processed in `_onMessage` where `const room = this._rooms.get(token)` returns `undefined` on line 143, silently dropping the registration.

This is an edge case (user toggles push while disconnected, then reconnects after the desktop also disconnected), but it means push notifications could silently stop working.

**Fix:** Either (a) always re-register the FCM token on every connect (which `_registerTokenOnConnect` in `NotificationService` already does), or (b) have the settings toggle check connection state first and show user feedback if disconnected:
```dart
Future<void> _togglePushNotifications(bool value) async {
  setState(() => _pushEnabled = value);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_pushEnabledKey, value);

  if (ConnectionManager.instance.state != WsConnectionState.connected) {
    // NotificationService._registerTokenOnConnect will handle registration on reconnect.
    return;
  }
  // ... existing send logic
}
```

## Low Issues

### LO-01: Duplicate notification channel creation on hot restart

**File:** `lib/services/notification_service.dart:104-132`
**Issue:** `_setupLocalNotifications()` calls `androidPlugin.createNotificationChannel()` every time `init()` is invoked. During Flutter hot restart, `init()` runs again but the channels already exist from the previous session. While Android handles duplicate channel creation gracefully (it's a no-op), calling `plugin.initialize()` again can re-register the tap handler, potentially causing duplicate navigation on tap.

**Fix:** Guard with `_initialized` or use a try-catch around the initialize call. The existing `_initialized` flag is set after `init()` completes, so checking it at the top of `init()` would suffice:
```dart
Future<void> init() async {
  if (_initialized) return;
  // ... rest of init
}
```
Note: This is already partially mitigated since the `_initialized` check exists, but the channels and plugin are re-initialized before that flag is set. Moving the guard to the very top of `init()` prevents redundant setup.

### LO-02: Unused `iosDetails` variable

**File:** `lib/services/notification_service.dart:37, 180`
**Issue:** `const iosDetails = null;` is assigned in both `firebaseBackgroundHandler` and `_showLocalNotification`, then passed to `NotificationDetails(android: androidDetails, iOS: iosDetails)`. The `null` value is the default for the named parameter, making the variable unnecessary. This is a minor readability issue.

**Fix:** Remove the variable and omit the `iOS` parameter (it defaults to null):
```dart
final details = NotificationDetails(android: androidDetails);
```

### LO-03: `_onDisconnect` can delete room during `_flushOfflineQueue`

**File:** `relay/lib/room.js:194-218, 225-241`
**Issue:** In the `join()` method, when a mobile reconnects, `_flushOfflineQueue(room)` is called synchronously on line 74. If flushing fails and triggers a `close` event on the mobile WebSocket (e.g., the socket dies during send), `_onDisconnect` fires, sets `room.mobile = null`, and may delete the room from `this._rooms` if the queue is now empty (line 215). After `_flushOfflineQueue` returns, the `join()` method continues logging on line 78 and wires up new event handlers on lines 81-92 for a WebSocket that is already closing. This is a theoretical race since the close event would be asynchronous in practice, but worth noting.

**Fix:** Capture the room reference before flushing and check it still exists after:
```javascript
// Flush any queued offline messages when mobile reconnects.
if (room.offlineQueue.length > 0) {
  this._flushOfflineQueue(room);
  // Room may have been deleted by _onDisconnect during flush.
  if (!this._rooms.has(token)) {
    this._rooms.set(token, room);
  }
}
```

### LO-04: SnackBar fires on every reconnection, even initial connect

**File:** `lib/pages/home_page.dart:30, 67-79`
**Issue:** `_prevState` is initialized to `WsConnectionState.disconnected`, so the SnackBar "正在同步离线消息..." also fires on the very first successful connection (app launch auto-connect). The summary acknowledges this design decision, noting the client cannot distinguish initial connect from reconnect. However, the first-connect SnackBar is misleading because there are no offline messages to sync on a fresh launch.

**Fix:** Track whether at least one connection has been established:
```dart
bool _hasConnectedOnce = false;

// In the listener:
if (state == WsConnectionState.connected) {
  if (_hasConnectedOnce) {
    // Show SnackBar only on reconnection, not first connect.
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
  _hasConnectedOnce = true;
}
_prevState = state;
```

## Info

### IN-01: Hardcoded magic strings for FCM-related event names

**File:** `relay/lib/room.js:147, 165`
**Issue:** Event names like `'fcm:register'`, `'stream:done'`, `'message:assistant'`, `'stream:error'` are hardcoded as string literals in `room.js` rather than imported from a shared constants module. The Dart side correctly uses `WsEvents.fcmRegister` from `ws_message.dart`. If protocol event names change, the relay server constants must be updated separately.

**Fix:** Consider creating a small `relay/lib/events.js` constants module mirroring `WsEvents`.

### IN-02: `_summarizeMessage` produces English fallback for Chinese users

**File:** `relay/lib/room.js:13`
**Issue:** The fallback `'Task completed'` is in English while the app UI is entirely in Chinese. This text appears in the push notification body when a message has no `content`, `text`, or `message` field. Since the target audience is Chinese-speaking, the fallback should match.

**Fix:** Change to `'任务完成'` or consider accepting a locale parameter.

### IN-03: `sendPushNotification` priority logic is always 'high'

**File:** `relay/lib/fcm.js:49`
**Issue:** The ternary `channelId === 'error' ? 'high' : 'high'` always evaluates to `'high'` regardless of input. This is clearly intentional (both branches are identical) but the ternary is misleading -- it suggests the author intended different priorities for different channels.

**Fix:** Simplify to a single value:
```javascript
priority: 'high',
```

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

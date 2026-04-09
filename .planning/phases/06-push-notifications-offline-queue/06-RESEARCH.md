# Phase 6: Push Notifications + Offline Queue - Research

**Researched:** 2026-04-09
**Domain:** Flutter FCM push notifications + WebSocket relay offline message queuing
**Confidence:** MEDIUM

## Summary

Phase 6 adds two capabilities to the wzxClaw Android app: (1) Firebase Cloud Messaging push notifications when AI tasks complete while the app is backgrounded, and (2) offline message queuing on the NAS Relay server so messages sent while the phone was offline are delivered on reconnect. The locked decision is to use FCM for push notifications -- this is a mature, free, well-supported solution for Android. The relay server (Node.js, already built in Phase 2) needs modification to cache messages when the mobile client disconnects and to call the FCM HTTP v1 API to push notifications. The Flutter app needs `firebase_core`, `firebase_messaging`, and `flutter_local_notifications` packages, plus a new `NotificationService` singleton following the established pattern.

The main complexity lies in three areas: (a) FCM setup requires a Firebase project, `google-services.json`, and a service account key file for server-side sending -- all manual console operations; (b) background message handling in Flutter runs in a separate Dart isolate on Android, requiring careful top-level function design; (c) the relay server currently has no persistence, so adding an in-memory message queue with 24-hour TTL and FCM integration is a non-trivial change to `room.js`.

**Primary recommendation:** Use `firebase_messaging` ^16.1.1 + `flutter_local_notifications` ^18.0.1 + `firebase_core` ^3.12.0 for push. For the relay, add in-memory message queue to `room.js` and use the FCM HTTP v1 API via `firebase-admin` SDK for server-side push sending.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Use FCM (Firebase Cloud Messaging) -- free, standard Android, mature Flutter plugin (`firebase_messaging`)
- Relay server calls FCM API when phone is offline, sends notification with message summary
- Firebase project scope: minimal FCM-only, no Firestore/Auth/Analytics bloat
- Notification shows: agent name + "completed" + first 50 chars of last message
- Multiple notifications grouped by session (single summary notification, latest content)
- 2 notification channels: "task_complete" (default) and "error" (high priority)
- Relay caches offline messages for 24 hours, then discards
- Timestamp-based merge on reconnect: append queued messages to existing chat history in order

### Claude's Discretion
- FCM setup details (google-services.json configuration, topic/subscription model)
- Notification tap navigation implementation (deep links vs named routes)
- Relay server FCM integration details (which FCM API to use, error handling)
- Offline cache storage format on relay (in-memory vs persistent)
- Push notification toggle implementation in settings (shared_preferences vs state management)

### Deferred Ideas (OUT OF SCOPE)
- NOTI-04: Notification categories (error/complete/waiting) -- v2 requirement
- NOTI-05: Custom notification sounds -- v2 requirement
- Message retry/resend on failed offline delivery
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOTI-01 | AI task complete -> push notification when app backgrounded | FCM data messages + flutter_local_notifications for custom display |
| NOTI-02 | Tap notification -> navigate to conversation | Named route `/` with scroll-to-bottom; GlobalKey for navigator in background handler |
| NOTI-03 | User toggle push notifications on/off in settings | SharedPreferences `push_notifications_enabled` key, existing pattern |
| RELAY-04 | Relay caches messages when mobile offline, triggers push notification | In-memory queue in room.js, FCM HTTP v1 API via firebase-admin |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Tech Stack**: Flutter (Dart) -- all code must be Flutter/Dart for the client, Node.js for the relay
- **Target Platform**: Android only -- no iOS FCM/APNs configuration needed
- **Scope**: Personal tool, single user -- no multi-user FCM topic management needed
- **Server**: NAS Docker relay, existing Node.js codebase under `relay/`
- **GSD Workflow**: All changes must go through `/gsd-execute-phase`

## Standard Stack

### Core (Flutter Client)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| firebase_core | ^3.12.0 | Firebase initialization (required before any Firebase plugin) | Mandatory peer dependency for all Firebase Flutter plugins [VERIFIED: pub.dev] |
| firebase_messaging | ^16.1.1 | Receive FCM push notifications, get device token | Official FlutterFire plugin, 3.9k likes, maintained by Google [VERIFIED: pub.dev] |
| flutter_local_notifications | ^18.0.1 | Display custom notifications from background data messages | Standard companion to firebase_messaging for custom notification display [ASSUMED: pub.dev, could not verify exact version due to rate limit] |

### Core (Relay Server - Node.js)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| firebase-admin | ^12.x | FCM HTTP v1 API server-side SDK for sending push notifications | Official Firebase Admin SDK, handles OAuth2 token minting automatically [VERIFIED: Firebase docs] |

### Supporting (Already in Project)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| shared_preferences | ^2.2.0 | Persist push notification toggle | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| sqflite | ^2.3.0 | Chat message persistence (offline messages merge target) | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |
| web_socket_channel | ^3.0.0 | WebSocket connection (reconnect triggers offline sync) | Already in pubspec.yaml [VERIFIED: pubspec.yaml] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FCM | UnifiedPush / ntfy | Self-hosted but requires running a push server; FCM is zero-ops for personal use |
| firebase-admin SDK | Raw HTTP v1 API calls | firebase-admin handles token refresh automatically; raw HTTP requires manual OAuth2 token minting |
| In-memory queue on relay | Redis / SQLite on relay | Personal tool, single user, messages expire in 24h -- in-memory is sufficient and zero-dependency |
| flutter_local_notifications | FCM notification payload only | FCM notification messages have limited customization on Android; flutter_local_notifications gives full control over channels, icons, grouping |

**Installation (Flutter):**
```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
flutterfire configure  # Generates google-services.json + FirebaseOptions
```

**Installation (Relay):**
```bash
cd relay && npm install firebase-admin
```

**Version verification:** `firebase_messaging` 16.1.1 and `firebase_core` 3.12.0 verified on pub.dev as of 2026-04-09. `flutter_local_notifications` ~18.0.1 based on search results but could not confirm exact latest version due to API rate limiting -- recommend verifying at [pub.dev/packages/flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) before install.

## Architecture Patterns

### Recommended Project Structure (New Files)

```
lib/
  services/
    notification_service.dart    # NEW - FCM initialization, token management, notification display
    ... (existing services unchanged)

relay/
  lib/
    fcm.js                       # NEW - FCM client for sending push notifications
    room.js                      # MODIFY - add message queue for offline mobile clients
  server.js                      # MODIFY - initialize FCM module, register token from mobile
  test/
    fcm.test.js                  # NEW - FCM unit tests
    room.test.js                 # MODIFY - add offline queue tests
```

### Pattern 1: NotificationService Singleton

**What:** New singleton service following the established `ConnectionManager` / `ChatStore` pattern. Manages FCM initialization, token lifecycle, and notification display.

**When to use:** This is the sole owner of all notification-related logic. All pages and services interact with notifications through this singleton.

**Example:**
```dart
// lib/services/notification_service.dart
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  bool _enabled = true; // loaded from SharedPreferences
  bool _isForeground = true;

  /// Initialize FCM and local notifications. Call from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    await Firebase.initializeApp();
    await _setupLocalNotifications();
    await _requestPermission();
    _setupFCMListeners();
    _fcmToken = await FirebaseMessaging.instance.getToken();
    // Send token to relay server
    _registerTokenWithRelay(_fcmToken);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenWithRelay);
  }

  /// Register the FCM token with the relay server so it can send pushes.
  void _registerTokenWithRelay(String? token) {
    if (token == null || !_enabled) return;
    ConnectionManager.instance.send(
      WsMessage(event: 'fcm:register', data: {'token': token}),
    );
  }

  /// Handle foreground FCM messages -- display via flutter_local_notifications.
  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    // Background message handler is a top-level function
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }
}
```

**Source:** Pattern derived from established `ConnectionManager` singleton in `lib/services/connection_manager.dart` and [Firebase official docs](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

### Pattern 2: Relay Offline Message Queue

**What:** In-memory message queue per room in `room.js`. When mobile disconnects, messages from desktop are queued. When mobile reconnects, queued messages are flushed in order, then a push notification is sent for the latest message.

**When to use:** This is the core mechanism for RELAY-04. The queue lives inside the existing `RoomManager` class.

**Example:**
```javascript
// Inside RoomManager class in relay/lib/room.js
// Per-room offline message queue
this._rooms = new Map();
// Each room becomes: { desktop, mobile, offlineQueue: [], lastQueuedAt: null }

_onMessage(token, role, ws, data) {
  // ... existing parse logic ...

  const room = this._rooms.get(token);
  if (!room) return;

  if (role === 'desktop') {
    if (room.mobile && room.mobile.readyState === 1) {
      // Mobile is connected -- forward normally
      this._forward(ws, room.mobile, raw);
    } else {
      // Mobile is offline -- queue the message
      room.offlineQueue.push({ raw, timestamp: Date.now() });
      room.lastQueuedAt = Date.now();

      // Send push notification for task completion events
      if (this._shouldPushNotify(event)) {
        fcm.sendPushNotification(room.fcmToken, {
          title: 'wzxClaw',
          body: _summarizeMessage(parsed.data),
          event: event,
        });
      }
    }
  }
}

// Called when mobile reconnects
_flushOfflineQueue(room) {
  if (room.offlineQueue.length === 0) return;
  log(`Flushing ${room.offlineQueue.length} offline messages`);
  for (const msg of room.offlineQueue) {
    if (room.mobile && room.mobile.readyState === 1) {
      room.mobile.send(msg.raw);
    }
  }
  room.offlineQueue = [];
  room.lastQueuedAt = null;
}
```

### Pattern 3: Top-Level Background Message Handler

**What:** FCM background messages on Android run in a **separate Dart isolate**. The handler MUST be a top-level function (not a class method). This is a critical Android-specific constraint.

**When to use:** Required for `firebase_messaging` to handle messages when the app is terminated or in background.

**Example:**
```dart
// MUST be a top-level function -- NOT inside a class
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Initialize flutter_local_notifications in this isolate
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  // ... initialize plugin ...
  // Display notification using flutter_local_notifications
}
```

**Source:** [Firebase official docs -- Receive messages in Flutter apps](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) [CITED: firebase.google.com]

### Pattern 4: FCM Token Registration via WebSocket

**What:** The Flutter app sends its FCM device token to the relay server over the existing WebSocket connection using a new `fcm:register` event. The relay stores this token per room and uses it to send push notifications when the mobile is offline.

**When to use:** This avoids needing a separate REST API for token registration -- reuses the existing WebSocket channel.

**Message format:**
```json
{"event": "fcm:register", "data": {"token": "fcm_device_token_here"}}
```

**Source:** Design decision based on established event/data protocol pattern from `lib/models/ws_message.dart`.

### Anti-Patterns to Avoid

- **DO NOT use notification messages (only `data` messages):** FCM "notification" messages have predefined behavior that cannot be customized. Always use "data" messages and display with `flutter_local_notifications` for full control over channels, icons, grouping, and suppression when app is in foreground.

- **DO NOT navigate from background isolate:** The `onBackgroundMessage` handler runs in a separate Dart isolate with no Flutter context. It cannot use `Navigator`. Instead, store the notification payload and handle navigation when the app resumes via `FirebaseMessaging.onMessageOpenedApp`.

- **DO NOT put FCM initialization inside `main()` without `WidgetsFlutterBinding.ensureInitialized()`:** Firebase plugins require Flutter bindings to be initialized first. The call order must be: `WidgetsFlutterBinding.ensureInitialized()` -> `Firebase.initializeApp()` -> `NotificationService.instance.init()`.

- **DO NOT use `firebase_messaging_auto_init_enabled = false` in AndroidManifest:** This project needs auto-initialization since we want push to work immediately on install. Auto-init is enabled by default -- leave it that way.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Push notification delivery | Custom TCP/long-polling to relay | FCM | Battery-optimized, OS-integrated, works when app is killed |
| Notification display (Android) | Raw Android intent + NotificationCompat | flutter_local_notifications | Cross-platform, handles channel creation, grouping, icons |
| OAuth2 token for FCM HTTP v1 | Manual JWT signing + token refresh | firebase-admin SDK | Handles credential lifecycle, token caching, automatic refresh |
| Message queue persistence | Custom file-based queue | In-memory array with TTL | Single user, 24h max retention, relay restart = clean slate is acceptable |

**Key insight:** The relay server currently does zero persistence. Adding a file-based or database-backed queue for a single-user personal tool with 24-hour message retention is over-engineering. In-memory queue + TTL cleanup is simpler and sufficient.

## Common Pitfalls

### Pitfall 1: FCM Data Messages Not Waking the App on Android
**What goes wrong:** App is force-killed, push arrives, but the background handler never fires. User sees nothing until they manually open the app.
**Why it happens:** On Android 12+, high-priority FCM data messages require the app to have been launched at least once after install. Also, battery optimization on some OEMs (Xiaomi, Huawei, Samsung) can kill background processing.
**How to avoid:** (1) Test on a real device, not emulator. (2) Disable battery optimization for the app during development. (3) Use high-priority FCM messages (set `android.priority: "high"` in the message). (4) Set `android.notification.priority` and `android.notification.channel_id` in the data payload so `flutter_local_notifications` can display a heads-up notification.
**Warning signs:** Notifications work when app is in background but NOT when force-killed.

### Pitfall 2: Background Isolate Cannot Access App State
**What goes wrong:** `_firebaseBackgroundHandler` tries to access `NotificationService.instance` or `SharedPreferences` and crashes silently or shows errors.
**Why it happens:** Background messages run in a **separate Dart isolate** on Android. No Dart objects from the main isolate are accessible. Each isolate has its own memory space.
**How to avoid:** (1) The handler MUST be a top-level function (annotated with `@pragma('vm:entry-point')`). (2) Reinitialize any needed plugins inside the handler (e.g., `await Firebase.initializeApp()`). (3) Keep the handler minimal -- just display the notification via `flutter_local_notifications`. (4) Store any data needed for navigation in `SharedPreferences` from the handler, and read it when the app resumes.
**Warning signs:** Background notifications never display, or app crashes on receiving background push.

### Pitfall 3: Notification Shows When User Is Actively Viewing the Chat
**What goes wrong:** User is actively chatting in the app, an AI task completes, and a push notification appears anyway.
**Why it happens:** FCM delivers to both foreground and background. If the foreground handler (`onMessage`) always shows a local notification, the user gets spammed while actively using the app.
**How to avoid:** In the `onMessage` listener, check whether the app is in the foreground using `WidgetsBindingObserver`. If `_isForeground` is true, do NOT display a notification -- the chat UI will show the message via WebSocket directly. Only display notifications when the app is in background or terminated.
**Warning signs:** Duplicate notifications (one from WebSocket rendering + one from FCM).

### Pitfall 4: Relay Loses Queued Messages on Restart
**What goes wrong:** Relay Docker container restarts (NAS update, power cycle), all queued offline messages are lost.
**Why it happens:** In-memory queue is volatile -- it lives in the Node.js process memory.
**How to avoid:** This is an acceptable trade-off for a personal tool with 24-hour retention. Document the behavior. If the user's phone was offline for 24+ hours, the messages would be discarded anyway per the locked decision. The only gap is if the relay restarts within that 24-hour window. For v1, accept this limitation.
**Warning signs:** User reports missing messages after NAS reboot (expected behavior in v1).

### Pitfall 5: FCM Token Registration Race Condition
**What goes wrong:** Flutter app gets FCM token before WebSocket is connected. Token is lost because it cannot be sent to relay.
**Why it happens:** `NotificationService.init()` runs at app startup, but `ConnectionManager` may still be connecting (or has no saved URL yet).
**How to avoid:** (1) Store the FCM token locally in SharedPreferences. (2) On each successful WebSocket connection (`stateStream` emits `connected`), check if there is a stored token and send `fcm:register` to relay. (3) Also listen to `onTokenRefresh` for token updates during the session.
**Warning signs:** Relay never has a valid FCM token, so push notifications never arrive.

## Code Examples

### FCM HTTP v1 API Call from Relay Server
```javascript
// relay/lib/fcm.js
// Using firebase-admin SDK
const admin = require('firebase-admin');

let fcmApp = null;

function init() {
  if (fcmApp) return;
  const serviceAccount = require(process.env.FCM_SERVICE_ACCOUNT_PATH || './fcm-service-account.json');
  fcmApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

async function sendPushNotification(fcmToken, { title, body, channelId = 'task_complete' }) {
  if (!fcmToken || !fcmApp) return;
  try {
    const message = {
      notification: { title, body },
      data: { channel: channelId },
      android: {
        priority: channelId === 'error' ? 'high' : 'normal',
        notification: { channelId },
      },
      token: fcmToken,
    };
    await admin.messaging().send(message);
    log(`FCM push sent to ${fcmToken.substring(0, 8)}...`);
  } catch (err) {
    warn(`FCM push failed: ${err.message}`);
  }
}
```

**Source:** [Firebase official docs -- Send a message using FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/send/v1-api) [CITED: firebase.google.com]

### Android Notification Channel Setup
```dart
// Inside NotificationService.init()
const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
  'task_complete',      // id
  'Task Complete',      // name
  description: 'Notifications when AI tasks complete',
  importance: Importance.default,
  playSound: true,
);

const AndroidNotificationChannel errorChannel = AndroidNotificationChannel(
  'error',
  'Errors',
  description: 'High priority error notifications',
  importance: Importance.high,
  playSound: true,
);

await _localPlugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(taskChannel);
await _localPlugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(errorChannel);
```

**Source:** [flutter_local_notifications README](https://pub.dev/packages/flutter_local_notifications) [CITED: pub.dev]

### Foreground Suppression Logic
```dart
// In NotificationService -- only show notification when NOT in foreground
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (_isForeground) {
    // App is visible -- do NOT show notification.
    // The chat UI will render the message via WebSocket.
    return;
  }
  // App is backgrounded but process is still alive -- show local notification.
  _showLocalNotification(message);
});
```

### Notification Tap -> Navigation
```dart
// Handle notification tap when app is in background
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // App resumes to foreground. Navigate to home and scroll to bottom.
  // The app's navigatorKey can be used if stored globally.
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| FCM Legacy API | FCM HTTP v1 API | July 2024 (legacy sunset) | Must use HTTP v1 or firebase-admin SDK for server-side sends |
| `google-services` plugin | `google-services` plugin (still current) | -- | Still the standard for Android Firebase setup |
| `@pragma('vm:entry-point')` optional | Required for background handler | Flutter 3.x | Without this annotation, the background handler may be tree-shaken |
| Notification messages only | Data messages + flutter_local_notifications | Best practice for years | Data messages give full control; notification messages are limited |

**Deprecated/outdated:**
- FCM Legacy API (`https://fcm.googleapis.com/fcm/send`): Sunset July 2024. Must use HTTP v1 API (`https://fcm.googleapis.com/v1/projects/{project}/messages:send`) [VERIFIED: Firebase docs, multiple sources]
- `notification` payload type for background handling: Works but cannot be customized. Use `data` messages exclusively.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `flutter_local_notifications` version is ~18.0.1 | Standard Stack | Low -- version may differ slightly but API is stable |
| A2 | Firebase project creation and google-services.json setup is a manual console operation | Architecture Patterns | Medium -- if there is a CLI tool (e.g., `flutterfire configure`) that automates this, the plan should use it instead of manual steps |
| A3 | In-memory queue is sufficient for relay offline caching (no persistence needed) | Don't Hand-Roll | Low -- single user, 24h TTL, acceptable data loss on restart |
| A4 | The relay server does not currently have any persistence mechanism | Architecture Patterns | Verified by reading relay/lib/room.js -- confirmed no persistence |
| A5 | No existing Firebase configuration in the Android project | Standard Stack | Verified by reading android/app/build.gradle -- no google-services plugin |
| A6 | `firebase-admin` Node.js SDK ^12.x is current | Standard Stack | Medium -- should verify exact latest version before installing |
| A7 | The `ws` message in `_onMessage` receives Buffer or string depending on ws config | Relay Offline Queue | Verified by reading relay/lib/room.js line 98 -- already handles both types |

## Open Questions

1. **Firebase Project Setup: CLI vs Manual**
   - What we know: `flutterfire configure` (the Firebase CLI for Flutter) can automate Firebase project creation and `google-services.json` download.
   - What's unclear: Whether the user already has a Firebase project or needs to create one. Whether `flutterfire configure` is installed on their machine.
   - Recommendation: Include a manual setup step in Wave 0 of the plan. The user needs to: (a) create a Firebase project in the console, (b) add an Android app, (c) download `google-services.json`, (d) create a service account key for the relay server. Document these steps.

2. **FCM Token Registration: New WebSocket Event vs HTTP Endpoint**
   - What we know: The relay currently only speaks WebSocket. Adding a `fcm:register` event is architecturally consistent.
   - What's unclear: Whether the FCM token should be sent every time the mobile connects (simple, redundant) or only when it changes (efficient, needs versioning).
   - Recommendation: Send the FCM token on every WebSocket connection as part of a `fcm:register` event. The relay stores the latest token per room. This is simpler and handles token rotation automatically.

3. **Offline Sync: New Event vs Session Messages**
   - What we know: The relay already forwards `session:messages` for full history sync. The offline queue is for incremental messages missed while offline.
   - What's unclear: Whether offline queued messages should be sent as individual WebSocket messages (streaming in) or bundled into a single `session:messages` event.
   - Recommendation: Send as individual messages in order. This matches the existing streaming behavior and integrates naturally with `ChatStore._handleWsMessage()`. A brief SnackBar ("正在同步离线消息...") indicates sync is happening.

4. **google-services.json: Where to Place It**
   - What we know: Standard Flutter + Firebase setup requires `google-services.json` in `android/app/`.
   - What's unclear: Whether this file should be committed to git or excluded (it contains project-specific credentials).
   - Recommendation: Add `android/app/google-services.json` to `.gitignore` for safety. Document in the plan that the user must manually place this file.

## Environment Availability

### Flutter Client Dependencies

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All development | Need to check | Need to check | -- |
| firebase_core | FCM initialization | Need `flutter pub add` | -- | -- |
| firebase_messaging | Push notifications | Need `flutter pub add` | -- | -- |
| flutter_local_notifications | Notification display | Need `flutter pub add` | -- | -- |
| Firebase CLI | `flutterfire configure` | Need to check | -- | Manual console setup |
| Android Studio | Emulator testing | Need to check | -- | Physical device |

### Relay Server Dependencies

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Relay server | Verified | Running relay tests | -- |
| firebase-admin | FCM sending | Need `npm install` | -- | Raw HTTP v1 API |

### External Services (Manual Setup Required)

| Dependency | Required By | Available | Setup |
|------------|------------|-----------|-------|
| Firebase project | FCM infrastructure | No -- must create | Firebase Console |
| google-services.json | Android FCM client | No -- must download | Firebase Console |
| FCM service account key | Relay server FCM sending | No -- must generate | Firebase Console -> Service Accounts |

**Missing dependencies with no fallback:**
- Firebase project, google-services.json, and FCM service account key must all be manually created in the Firebase Console before any code can be tested. These are blocking prerequisites.

**Missing dependencies with fallback:**
- None -- all other dependencies can be installed via pub/npm.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Flutter Framework | `flutter_test` (bundled with SDK) |
| Config file | None -- uses default `flutter test` discovery |
| Quick run command | `flutter test test/services/notification_service_test.dart` |
| Full suite command | `flutter test` |
| Relay Framework | `node:test` (built-in Node.js test runner) |
| Relay quick run | `cd relay && node --test test/fcm.test.js` |
| Relay full suite | `cd relay && npm test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOTI-01 | FCM token retrieved on init | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| NOTI-01 | Push notification displayed when data message received in background | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| NOTI-01 | No notification displayed when app is in foreground | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| NOTI-02 | Notification tap navigates to home page | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| NOTI-03 | Toggle persists to SharedPreferences | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| NOTI-03 | Toggle OFF prevents token registration | unit | `flutter test test/services/notification_service_test.dart` | No -- Wave 0 |
| RELAY-04 | Messages queued when mobile offline | unit | `cd relay && node --test test/room.test.js` | Partially -- modify existing |
| RELAY-04 | Queued messages flushed on mobile reconnect | unit | `cd relay && node --test test/room.test.js` | Partially -- modify existing |
| RELAY-04 | Push notification sent when message queued | unit | `cd relay && node --test test/fcm.test.js` | No -- Wave 0 |
| RELAY-04 | Queue expires after 24 hours | unit | `cd relay && node --test test/room.test.js` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/notification_service_test.dart` (Flutter) or `cd relay && node --test test/room.test.js` (Relay)
- **Per wave merge:** `flutter test` + `cd relay && npm test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/notification_service_test.dart` -- covers NOTI-01, NOTI-02, NOTI-03
- [ ] `relay/test/fcm.test.js` -- covers RELAY-04 FCM sending (mock FCM API calls)
- [ ] `relay/test/room.test.js` modifications -- add offline queue tests (extend existing file)
- [ ] Framework install: `flutter pub add firebase_core firebase_messaging flutter_local_notifications` + `cd relay && npm install firebase-admin`

Note: FCM tests for the Flutter client will require mocking since real FCM requires a device + Firebase project. Use `mockito` or manual mocks for unit testing `NotificationService`.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | -- |
| V3 Session Management | No | -- |
| V4 Access Control | No | -- |
| V5 Input Validation | Yes (relay) | JSON parse validation already in room.js -- extend to validate FCM token format |
| V6 Cryptography | No | FCM uses Google-managed TLS; no custom crypto |

### Known Threat Patterns for Flutter + FCM + Node.js Relay

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| FCM token interception | Information Disclosure | Tokens sent over WSS (TLS-encrypted). Tokens are device-specific and rotate. |
| Unauthorized push sending | Tampering | Relay validates FCM token source (must come from authenticated WebSocket connection). FCM service account key stored as env var, not in code. |
| FCM service account key exposure | Information Disclosure | Key file referenced via env var `FCM_SERVICE_ACCOUNT_PATH`, NOT committed to git. Document in `.gitignore`. |
| Spam push notifications | Denial of Service | Personal tool, single user. No rate limiting needed. Relay only sends when a real message is queued. |
| Malicious notification payload | Tampering | Relay controls the notification content (server-side rendering). FCM data message only contains summary text from the actual WebSocket message. No user-supplied content in notification body. |

### Security Checklist for Phase 6
- [ ] `google-services.json` added to `.gitignore`
- [ ] FCM service account key path referenced via environment variable, not hardcoded
- [ ] `fcm-service-account.json` added to `.gitignore`
- [ ] Relay only sends push for authenticated, registered mobile clients
- [ ] No sensitive data in FCM notification payloads (only summary text)

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/firebase_messaging](https://pub.dev/packages/firebase_messaging) -- version 16.1.1 verified
- [pub.dev/packages/firebase_core](https://pub.dev/packages/firebase_core) -- version 3.12.0 verified
- [Firebase Docs: Set up FCM client on Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client) -- setup, token management, permissions
- [Firebase Docs: Receive messages in Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) -- background handler, isolate behavior
- [Firebase Docs: Send message using FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/send/v1-api) -- server-side sending, auth, message format
- Codebase: `relay/lib/room.js` -- verified relay architecture, no persistence
- Codebase: `lib/services/connection_manager.dart` -- verified singleton pattern, stateStream
- Codebase: `lib/services/chat_store.dart` -- verified message handling, stream patterns
- Codebase: `android/app/build.gradle` -- verified no existing Firebase setup
- Codebase: `android/app/src/main/AndroidManifest.xml` -- verified current permissions

### Secondary (MEDIUM confidence)
- [Firebase Push Notifications in Flutter: Complete 2025 Guide (Medium)](https://medium.com/@ali.mohamed.hgr/firebase-push-notifications-in-flutter-the-complete-2024-guide-c1cb0684bf8a) -- end-to-end FCM setup walkthrough
- [Why Your Push Notifications Don't Work: 2026 Edition (Medium)](https://medium.com/@tiger.chirag/why-your-push-notifications-dont-work-2026-edition-1fb1785c1216) -- Android OEM battery optimization, priority settings
- [FlutterFire Docs: Cloud Messaging Usage](https://firebase.flutter.dev/docs/messaging/usage/) -- detailed usage patterns
- [Deep Linking in Flutter Notifications (Medium)](https://medium.com/fludev/deep-linking-in-flutter-notifications-opening-specific-screens-7811056c3bf4) -- notification tap navigation

### Tertiary (LOW confidence)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) -- version ~18.0.1 unverified due to API rate limit
- [firebase-admin SDK](https://www.npmjs.com/package/firebase-admin) -- version ^12.x assumed, not verified
- [FCM HTTP v1 migration](https://support.iterable.com/hc/en-us/articles/26920391539604-Web-Push-Notifications-Migrating-to-the-FCM-HTTP-v1-API) -- confirms legacy API sunset

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - `firebase_messaging` and `firebase_core` verified; `flutter_local_notifications` version unverified
- Architecture: MEDIUM - patterns well-documented but FCM background isolate behavior has edge cases per OEM
- Pitfalls: HIGH - all pitfalls documented from official docs and common community issues
- Relay changes: HIGH - existing relay code fully read and understood; modification points clear

**Research date:** 2026-04-09
**Valid until:** 30 days (FCM API stable; FlutterFire releases monthly but non-breaking)

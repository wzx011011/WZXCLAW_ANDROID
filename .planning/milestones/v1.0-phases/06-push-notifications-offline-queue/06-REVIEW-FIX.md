---
phase: 06
fixed_at: 2026-04-09
review_path: .planning/phases/06-push-notifications-offline-queue/06-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-04-09
**Source review:** .planning/phases/06-push-notifications-offline-queue/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### MD-01: FCM token stored without length validation

**Files modified:** `relay/lib/room.js`
**Commit:** ee2d86d
**Applied fix:** Added type and length check (max 512 chars) on the FCM token before storing it in the room object. Tokens exceeding the limit or non-string values are rejected and set to null.

### MD-02: StreamSubscription leak in NotificationService._registerTokenOnConnect

**Files modified:** `lib/services/notification_service.dart`
**Commit:** bdcbe74
**Applied fix:** Stored the `StreamSubscription` returned by `stateStream.listen()` in a new `_connectSub` field. Added `_connectSub?.cancel()` call in `dispose()` to properly clean up the subscription.

### MD-03: Race condition -- FCM token registration sent before auth completes

**Files modified:** `lib/pages/settings_page.dart`
**Commit:** c4482a2
**Applied fix:** Added an early return with connection state check at the top of `_togglePushNotifications()`. When disconnected, the method saves the preference but skips sending the FCM registration message, since `NotificationService._registerTokenOnConnect()` already handles re-registration on reconnect.

### LO-02: Unused iosDetails variable

**Files modified:** `lib/services/notification_service.dart`
**Commit:** ebce82e
**Applied fix:** Removed `const iosDetails = null;` variable in both `firebaseBackgroundHandler` and `_showLocalNotification`. Changed `NotificationDetails(android: androidDetails, iOS: iosDetails)` to `NotificationDetails(android: androidDetails)` since the `iOS` parameter defaults to null.

### LO-04: SnackBar fires on every connection including initial connect

**Files modified:** `lib/pages/home_page.dart`
**Commit:** 4827a57
**Applied fix:** Added a `_hasConnectedOnce` boolean flag initialized to false. The "syncing offline messages" SnackBar now only displays on reconnection (when `_hasConnectedOnce` is already true). The flag is set to true on the first connection event.

### IN-03: Ternary with identical branches in sendPushNotification

**Files modified:** `relay/lib/fcm.js`
**Commit:** e17848f
**Applied fix:** Simplified `channelId === 'error' ? 'high' : 'high'` to just `'high'` since both branches evaluate to the same value.

---

_Fixed: 2026-04-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

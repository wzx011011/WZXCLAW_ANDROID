---
phase: 6
slug: push-notifications-offline-queue
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Flutter Framework** | `flutter_test` (bundled with SDK) |
| **Config file** | None -- uses default `flutter test` discovery |
| **Flutter quick run** | `flutter test test/services/notification_service_test.dart` |
| **Flutter full suite** | `flutter test` |
| **Relay Framework** | `node:test` (built-in Node.js test runner) |
| **Relay quick run** | `cd relay && node --test test/fcm.test.js` |
| **Relay full suite** | `cd relay && npm test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter test test/services/notification_service_test.dart` (Flutter) or `cd relay && node --test test/room.test.js` (Relay)
- **After every plan wave:** `flutter test` + `cd relay && npm test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | RELAY-04 | — | N/A | unit | `cd relay && node --test test/fcm.test.js` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | RELAY-04 | T-01 | FCM service account key via env var | unit | `cd relay && node --test test/room.test.js` | ⚠️ modify | ⬜ pending |
| 06-02-01 | 02 | 1 | NOTI-01, NOTI-02 | T-01, T-02 | No sensitive data in FCM payload | unit | `flutter test test/services/notification_service_test.dart` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | NOTI-03 | — | N/A | unit | `flutter test test/services/notification_service_test.dart` | ❌ W0 | ⬜ pending |
| 06-03-02 | 03 | 2 | RELAY-04 | — | N/A | unit | `flutter test` | ⚠️ modify | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/notification_service_test.dart` — stubs for NOTI-01, NOTI-02, NOTI-03
- [ ] `relay/test/fcm.test.js` — stubs for RELAY-04 FCM sending (mock FCM API calls)
- [ ] `relay/test/room.test.js` — add offline queue tests (extend existing file)
- [ ] `flutter pub add firebase_core firebase_messaging flutter_local_notifications` + `cd relay && npm install firebase-admin`

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Push notification received when app backgrounded | NOTI-01 | Requires real device + Firebase project | 1. Open app, connect to relay. 2. Switch to another app. 3. Send a message from desktop. 4. Verify notification appears on phone. |
| Notification tap navigates to home page | NOTI-02 | Requires Android notification system | 1. With notification visible, tap it. 2. Verify app opens to home page. |
| Toggle persists across app restart | NOTI-03 | SharedPreferences on real device | 1. Toggle push OFF in settings. 2. Kill app. 3. Reopen. 4. Verify toggle still OFF. |
| Offline messages sync on reconnect | RELAY-04 | Requires network disconnect | 1. Connect app to relay. 2. Turn off network. 3. Send messages from desktop. 4. Turn network back on. 5. Verify messages appear in chat. |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

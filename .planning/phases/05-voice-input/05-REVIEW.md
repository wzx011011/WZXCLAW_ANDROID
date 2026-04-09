---
phase: 05-voice-input
reviewed: 2026-04-09T12:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - android/app/src/main/AndroidManifest.xml
  - lib/pages/home_page.dart
  - lib/services/voice_input_service.dart
  - lib/widgets/mic_button.dart
  - pubspec.yaml
  - test/services/voice_input_service_test.dart
  - test/widgets/mic_button_test.dart
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-09T12:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the voice input feature spanning Android manifest permissions, a singleton `VoiceInputService` wrapping `speech_to_text`, a `MicButton` widget with long-press recording, integration in `HomePage`, pubspec dependencies, and unit tests. The implementation is clean overall -- singleton pattern is consistent with the project convention, permission handling includes permanent-denial guidance, and the UI correctly disables the mic button when disconnected or streaming. However, one critical race condition exists in `startListening` where the `_speech.listen()` await can throw an unhandled exception. Three warnings cover a missing try-catch on `stopListening`, duplicate `HapticFeedback.mediumImpact()` calls, and a potential null access on `msg.id`.

## Critical Issues

### CR-01: Unhandled exception in `startListening` when `_speech.listen()` fails

**File:** `lib/services/voice_input_service.dart:105-116`
**Issue:** The `_speech.listen()` call on line 105 is awaited but not wrapped in a try-catch. If the underlying platform speech service throws (e.g., due to a transient system error, missing engine, or concurrent access), the exception propagates unhandled to the caller. At that point, `_listening` has already been set to `true` and `_statusController.add(true)` has already fired on lines 114-115, so the service is now in an inconsistent state: it reports it is listening when it is not.

This is particularly dangerous because the caller (`MicButton._onLongPressStart`) does not catch exceptions either, and the UI will show a pulsing red mic that never stops.

**Fix:**
```dart
// startListening, after permission check:
try {
  await _speech.listen(
    onResult: (result) {
      if (result.finalResult) {
        onResult(result.recognizedWords);
      }
    },
  );

  _listening = true;
  _statusController.add(true);
  HapticFeedback.mediumImpact();
} catch (e) {
  _errorController.add(VoiceError.recognitionFailed);
}
```

## Warnings

### WR-01: `stopListening()` lacks error handling for `_speech.stop()`

**File:** `lib/services/voice_input_service.dart:120-125`
**Issue:** The `_speech.stop()` call on line 122 is awaited but not wrapped in a try-catch. If the speech engine throws during stop (e.g., already stopped by the system, or the service was released), the exception propagates up to `MicButton._onLongPressEnd`, which does not handle it. The `_listening` flag and `_statusController` state would remain inconsistent.

**Fix:**
```dart
Future<void> stopListening() async {
  if (!_listening) return;
  try {
    await _speech.stop();
  } catch (_) {
    // Speech engine may already be stopped by the system
  }
  _listening = false;
  _statusController.add(false);
}
```

### WR-02: Double `HapticFeedback.mediumImpact()` on recording start

**File:** `lib/services/voice_input_service.dart:116` and `lib/widgets/mic_button.dart:63`
**Issue:** When the user long-presses the mic button, `HapticFeedback.mediumImpact()` is called in two places: first in `MicButton._onLongPressStart` (line 63), then again in `VoiceInputService.startListening` (line 116). This causes a double vibration on every recording start, which feels like a glitch to the user.

**Fix:** Remove the haptic feedback from one of the two locations. Since the mic button is the UI initiator and haptics are a UI concern, remove it from the service:

In `lib/services/voice_input_service.dart`, delete line 116:
```dart
// Remove: HapticFeedback.mediumImpact();
```

### WR-03: `msg.id` can be null, causing timestamp toggle to use ad-hoc fallback key

**File:** `lib/pages/home_page.dart:231` and `lib/pages/home_page.dart:245`
**Issue:** The expression `msg.id ?? msg.createdAt.millisecondsSinceEpoch` is used as the key for `_revealedMessageIds` in multiple places (lines 231, 245, 262, 285). If `msg.id` is null, the timestamp is used as a fallback, but `msg.id` could also change (e.g., become assigned after being null) which would make the toggle state inconsistent. This is a latent logic error -- if messages are persisted and reloaded with IDs assigned later, previously toggled timestamps would not be found.

This is a warning rather than critical because it is a UX inconsistency (timestamp state lost on reload) rather than a crash or data loss.

**Fix:** Ensure `msg.id` is always assigned before messages enter the display list, or document that messages without IDs are ephemeral. Alternatively, use only `msg.id` and filter out messages without IDs:

```dart
void _toggleTimestamp(int msgId) {
  setState(() {
    if (_revealedMessageIds.contains(msgId)) {
      _revealedMessageIds.remove(msgId);
    } else {
      _revealedMessageIds.add(msgId);
    }
  });
}
// And in the widget tree, guard with:
if (msg.id != null && _revealedMessageIds.contains(msg.id!))
```

## Info

### IN-01: Singleton `VoiceInputService` is never disposed

**File:** `lib/services/voice_input_service.dart:155-158`
**Issue:** The `dispose()` method exists but is never called anywhere in the codebase. The two `StreamController` instances are created but never closed. In Flutter, stream controllers that are never closed may leak if the isolates they are bound to outlive the service. Since this is a singleton that lives for the app's entire lifetime, this is typically benign, but it is worth noting that the `dispose()` method is dead code until it is wired into the app lifecycle.

**Fix:** Call `VoiceInputService.instance.dispose()` in `main.dart` after `runApp()` completes, or remove the `dispose()` method to avoid implying it should be called. For a singleton that lives the app's lifetime, this is acceptable as-is.

### IN-02: `MicButton` test does not cover long-press interaction

**File:** `test/widgets/mic_button_test.dart`
**Issue:** The test file covers rendering, color states, and constructor parameter acceptance, but does not test the core interaction: that a long-press triggers `startListening` and a release triggers `stopListening`. The tests verify the widget builds correctly but do not verify its behavior. This means regressions in the long-press-to-record flow would go undetected.

**Fix:** Add integration tests using `tester.startGesture()` and `tester.moveTo()` / `tester.up()` to simulate long-press and release, verifying that `VoiceInputService.instance.startListening` and `stopListening` are called. Note: this requires mocking the singleton or using dependency injection, which may be a larger effort.

---

_Reviewed: 2026-04-09T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

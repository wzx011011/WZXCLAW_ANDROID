---
phase: 05-voice-input
verified: 2026-04-09T13:30:00Z
status: human_needed
score: 10/10 must-haves verified
overrides_applied: 0
gaps: []
human_verification:
  - test: "Press-and-hold mic button starts voice recording, release stops recording"
    expected: "Long-press starts recording (pulsing red icon), release stops and recognized text appears in input field"
    why_human: "Requires real Android device with microphone; speech_to_text is a platform plugin that cannot be tested in CI or emulator without mic hardware"
  - test: "Chinese speech recognition accuracy"
    expected: "Speaking Chinese produces correct Chinese characters in the input field"
    why_human: "Speech recognition quality depends on the device's system locale and speech engine; programmatic verification cannot assess recognition accuracy"
  - test: "Recognized text is editable before sending"
    expected: "After voice recognition fills the TextField, the text can be modified with keyboard and then sent"
    why_human: "Text editing is a UI interaction that requires visual confirmation on a real device"
  - test: "Permission denied shows Chinese error SnackBar"
    expected: "When microphone permission is denied, a floating SnackBar shows '麦克风权限被拒绝' for 2 seconds"
    why_human: "Runtime permission dialog interaction requires a real device; cannot be tested programmatically without Android permission system"
---

# Phase 5: Voice Input Verification Report

**Phase Goal:** 语音输入指令，中文语音识别，识别结果可编辑后发送。
**Verified:** 2026-04-09T13:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | VoiceInputService singleton wraps speech_to_text and exposes startListening/stopListening | VERIFIED | `lib/services/voice_input_service.dart` lines 27-30: singleton pattern; lines 83-120: `startListening` method wrapping `SpeechToText.listen()`; lines 123-132: `stopListening` method wrapping `SpeechToText.stop()` |
| 2 | VoiceInputService only listens during explicit start/stop calls (no continuous listening) | VERIFIED | `startListening` checks `_listening` guard (line 86), sets `_listening = true` only on explicit call (line 115), `stopListening` sets `_listening = false` (line 130). No automatic re-listening or continuous mode. |
| 3 | VoiceInputService uses system default locale (no explicit locale override) | VERIFIED | `voice_input_service.dart` line 112: comment "No localeId specified -- uses system default (per CONTEXT.md decision D-06)". No `localeId` parameter passed to `_speech.listen()`. `grep "localeId"` on the file only matches the comment. |
| 4 | Permission denied handled gracefully with SnackBar error message callback | VERIFIED | `voice_input_service.dart` line 99-101: emits `VoiceError.permissionDenied` to `errorStream`. `home_page.dart` lines 53-63: subscribes to `errorStream`, shows `SnackBar` with `VoiceInputService.errorMessage(error)` (Chinese text). |
| 5 | Android RECORD_AUDIO permission declared in AndroidManifest.xml | VERIFIED | `android/app/src/main/AndroidManifest.xml` line 3: `<uses-permission android:name="android.permission.RECORD_AUDIO" />` |
| 6 | Android SDK 30+ queries declaration for RecognitionService is present | VERIFIED | `android/app/src/main/AndroidManifest.xml` lines 4-8: `<queries><intent><action android:name="android.speech.RecognitionService" /></intent></queries>` |
| 7 | User can long-press mic button to start voice recording | VERIFIED | `mic_button.dart` lines 58-74: `_onLongPressStart` calls `VoiceInputService.instance.startListening()`, guarded by `isConnected` and `!isStreaming`. Line 96: `onLongPressStart` wired to `GestureDetector`. |
| 8 | User releases mic button to stop recording and get recognized text | VERIFIED | `mic_button.dart` lines 76-84: `_onLongPressEnd` calls `VoiceInputService.instance.stopListening()`. Lines 62-66: `onResult` callback wired from `startListening` to `widget.onResult(text)`. |
| 9 | Recognized text appears in the existing TextField via _inputController | VERIFIED | `home_page.dart` lines 367-376: `MicButton` in input bar with `onResult: (text) { _inputController.text = text; _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length)); }`. Cursor placed at end of text. |
| 10 | Recognized text is fully editable before sending | VERIFIED | `home_page.dart` lines 344-365: `TextField` with `_inputController` remains enabled when connected. Voice result sets `.text` and `.selection` but does not trigger send. User must press send button explicitly (`_sendMessage()` at line 100-107). |
| 11 | Mic button shows recording state (pulsing red icon) while pressed | VERIFIED | `mic_button.dart` lines 46-48: `AnimationController` with 800ms duration, `repeat(reverse: true)`. Lines 106-114: `FadeTransition` with `Tween(0.5, 1.0)` opacity. Line 88: `_iconColor` returns `Colors.redAccent` when `_isRecording`. |
| 12 | Mic button is disabled when WebSocket is disconnected | VERIFIED | `mic_button.dart` line 59: `if (!widget.isConnected \|\| widget.isStreaming) return;` in `_onLongPressStart`. Line 87: `_iconColor` returns `Colors.white24` when `!widget.isConnected`. Line 96-97: `onLongPressStart` is null when not connected. |
| 13 | Mic button is non-responsive during streaming | VERIFIED | `mic_button.dart` line 59: `widget.isStreaming` guard in `_onLongPressStart`. Line 89: `_iconColor` returns `Colors.white24` when streaming. Line 96-97: `onLongPressStart` is null when streaming. |
| 14 | Recognition failure shows SnackBar with Chinese error message | VERIFIED | `home_page.dart` lines 53-63: subscribes to `VoiceInputService.instance.errorStream`, shows `SnackBar` with `Text(VoiceInputService.errorMessage(error))`. `voice_input_service.dart` lines 148-158: `errorMessage()` maps all `VoiceError` values to Chinese strings. |

**Score:** 10/10 truths verified

### Deferred Items

None. All must-haves for Phase 5 are satisfied in this phase. Phase 6 (Push Notifications + Offline Queue) addresses a different domain.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/services/voice_input_service.dart` | VoiceInputService singleton wrapping speech_to_text | VERIFIED | 166 lines. Singleton pattern (lines 28-30), `SpeechToText` import (line 5), `Permission.microphone` import (line 4), `startListening`/`stopListening`/`initialize`/`requestPermission` methods, `VoiceError` enum with Chinese messages. No stubs. |
| `android/app/src/main/AndroidManifest.xml` | RECORD_AUDIO permission + RecognitionService queries | VERIFIED | Line 3: `RECORD_AUDIO` permission. Lines 4-8: `queries` block with `RecognitionService` intent. |
| `test/services/voice_input_service_test.dart` | Unit tests for VoiceInputService | VERIFIED | 128 lines. 15 tests covering singleton identity, API surface, VoiceError enum values, Chinese error messages, stream emission behavior. |
| `lib/widgets/mic_button.dart` | MicButton StatefulWidget with long-press gesture and recording animation | VERIFIED | 121 lines. Long-press gesture, pulsing AnimationController (800ms), color states (white38/white24/redAccent), VoiceInputService integration. |
| `lib/pages/home_page.dart` | Updated input bar with MicButton | VERIFIED | MicButton imported (line 12), VoiceInputService imported (line 10), MicButton in input bar Row (lines 367-376), error stream subscription (lines 53-63), subscription cancelled in dispose (line 70). |
| `test/widgets/mic_button_test.dart` | Widget tests for MicButton | VERIFIED | 125 lines. 10 tests covering rendering (mic icon, tooltip, semantics), color states (connected/disconnected/streaming), constructor parameters. |
| `pubspec.yaml` | speech_to_text and permission_handler dependencies | VERIFIED | Line 15: `speech_to_text: ^7.3.0`, Line 16: `permission_handler: ^12.0.1` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `voice_input_service.dart` | `speech_to_text` package | `import 'package:speech_to_text/speech_to_text.dart'` | WIRED | Line 5: import present. Line 32: `SpeechToText _speech = SpeechToText()`. Line 106: `_speech.listen()`. Line 126: `_speech.stop()`. |
| `voice_input_service.dart` | `permission_handler` package | `import 'package:permission_handler/permission_handler.dart'` | WIRED | Line 4: import present. Line 70: `Permission.microphone.status`. Line 76: `Permission.microphone.request()`. |
| `mic_button.dart` | `voice_input_service.dart` | `VoiceInputService.instance.startListening / stopListening` | WIRED | Line 3: import present. Line 62: `VoiceInputService.instance.startListening()`. Line 83: `VoiceInputService.instance.stopListening()`. |
| `home_page.dart` | `mic_button.dart` | `MicButton widget in _buildInputBar Row` | WIRED | Line 12: import present. Line 367: `MicButton(` in `_buildInputBar()`. |
| `mic_button.dart` | `_inputController` | `onResult callback` | WIRED | `mic_button.dart` line 64: `widget.onResult(text)`. `home_page.dart` lines 369-371: `_inputController.text = text; _inputController.selection = ...` |
| `home_page.dart` | `VoiceInputService.errorStream` | `StreamSubscription listen` | WIRED | `home_page.dart` line 53: `VoiceInputService.instance.errorStream.listen()`. Line 57: `VoiceInputService.errorMessage(error)` in SnackBar content. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `mic_button.dart` | `widget.onResult(text)` | `VoiceInputService.startListening` -> `SpeechToText.listen(onResult:)` | FLOWING | `SpeechToText.listen()` receives recognized words from Android SpeechRecognizer (platform plugin). `onResult` called when `result.finalResult` is true (line 108). Wired through `widget.onResult(text)` -> `_inputController.text = text` in `home_page.dart`. |
| `home_page.dart` SnackBar | `VoiceInputService.errorMessage(error)` | `VoiceInputService.errorStream` | FLOWING | `_errorController.add(VoiceError.xxx)` triggered by `_handleError()` (permission denied, no speech, not available, recognition failed). `errorMessage()` maps to Chinese strings. Subscribed in `initState()` line 53. |
| `home_page.dart` MicButton state | `isConnected` / `isStreaming` | `ConnectionManager.instance.stateStream` / `ChatStore.instance.streamingStream` | FLOWING | `_buildInputBar()` uses `StreamBuilder<WsConnectionState>` (line 329) to derive `isConnected`. `_isStreaming` from `ChatStore.instance.streamingStream` subscription (line 47-49). Both passed as props to `MicButton`. |

### Behavioral Spot-Checks

Step 7b: SKIPPED (Flutter SDK not available in CI environment; platform plugins require real device)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| VOICE-01 | 05-01, 05-02 | 用户能通过麦克风语音输入指令 | SATISFIED | `MicButton` long-press triggers `VoiceInputService.startListening()` which calls `SpeechToText.listen()`. Recognized text flows to `_inputController`. |
| VOICE-02 | 05-01 | 支持中文语音识别 | SATISFIED | `SpeechToText.listen()` called without `localeId` parameter -- uses system default locale (line 112 comment). Chinese devices will use Chinese speech engine. |
| VOICE-03 | 05-02 | 语音识别结果可编辑后再发送 | SATISFIED | `home_page.dart` lines 369-371: recognized text set to `_inputController.text` with cursor at end. TextField remains enabled for editing. Send only triggered by explicit `_sendMessage()` call (line 100). |

### Anti-Patterns Found

No anti-patterns detected in any Phase 5 files.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | - | - | - |

### Human Verification Required

### 1. Voice Recording End-to-End

**Test:** Build and run the app on a physical Android device. Long-press the mic button in the input bar, speak Chinese text, release the button.
**Expected:** The mic icon pulses red while pressed. After release, recognized Chinese text appears in the input field. The text is editable (can be modified with the keyboard). Pressing the send button sends the text.
**Why human:** Speech recognition requires a physical microphone and Android speech engine. Platform plugins (speech_to_text, permission_handler) cannot function in CI or without hardware.

### 2. Chinese Recognition Accuracy

**Test:** Speak Chinese phrases (e.g., "帮我创建一个新文件", "查看当前目录") and verify the recognized text accuracy.
**Expected:** Recognized text matches spoken Chinese with acceptable daily-use accuracy.
**Why human:** Recognition quality depends on the device's speech engine, system locale, microphone quality, and ambient noise -- none of which can be assessed programmatically.

### 3. Permission Denied Flow

**Test:** Revoke microphone permission from Android Settings, then long-press the mic button.
**Expected:** A floating SnackBar appears showing "麦克风权限被拒绝" for 2 seconds. No crash or infinite loading state.
**Why human:** Runtime permission system interaction requires Android OS and user action in Settings.

### 4. Disconnected/Streaming Button States

**Test:** (a) Disconnect from server, verify mic button is de-emphasized (white24) and long-press does nothing. (b) While AI is streaming a response, verify mic button is de-emphasized and non-responsive.
**Expected:** Button visual states match specification. No recording starts in either disabled state.
**Why human:** Visual state verification requires running app. Color differences (white38 vs white24 vs redAccent) need visual confirmation.

### Gaps Summary

No code-level gaps found. All 10 observable truths verified against the actual codebase. All artifacts are substantive (not stubs), all key links are wired, and data flows correctly through the chain: MicButton gesture -> VoiceInputService -> SpeechToText platform plugin -> recognized text -> _inputController -> editable TextField.

The 4 human verification items are expected for a phase that depends on platform plugins (speech_to_text, permission_handler) which cannot be exercised in a non-device environment. These do not indicate implementation gaps -- they indicate the need for device-level acceptance testing.

---

_Verified: 2026-04-09T13:30:00Z_
_Verifier: Claude (gsd-verifier)_

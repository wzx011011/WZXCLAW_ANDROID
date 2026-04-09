# Phase 5: Voice Input - Research

**Researched:** 2026-04-09
**Domain:** Flutter Android speech recognition integration
**Confidence:** HIGH

## Summary

This phase adds voice input to the wzxClaw Android chat interface. The user decided to use native Android SpeechRecognizer via platform channel, which means using the `speech_to_text` Flutter package (the standard wrapper around Android's `android.speech.SpeechRecognizer`). The implementation requires: (1) adding `speech_to_text` and `permission_handler` as dependencies, (2) adding microphone permission to AndroidManifest.xml, (3) creating a VoiceInputService that wraps the speech_to_text plugin with the project's singleton pattern, (4) adding a long-press microphone button to the existing input bar, and (5) routing recognized text into the existing `TextEditingController`.

The key technical decisions are already locked: long-press mic button (hold to record, release to send recognized text), recognized text goes into the existing `_inputController` for editing before sending, and system default locale for Chinese recognition. The main research finding is that `speech_to_text` v7.3.0 is the current stable release, requires `compileSdk 31+` (the project uses `flutter.compileSdkVersion` which should be fine), and needs `RECORD_AUDIO` as a dangerous permission with runtime request via `permission_handler`.

**Primary recommendation:** Use `speech_to_text` package rather than raw platform channels -- it wraps the same native SpeechRecognizer API, handles all the EventChannel/MethodChannel boilerplate, and is battle-tested across thousands of Flutter apps. Raw platform channels would be reinventing a solved problem.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Use native Android SpeechRecognizer via platform channel -- free, no API key, offline-capable, good Chinese support
- Long-press mic button -- hold to record, release to send recognized text
- Mic button placed on right side of TextField, before send button -- standard chat app pattern
- Minimal audio feedback -- button state change (icon animation) + platform vibrate only
- Recognized text goes into existing TextField via TextEditingController -- fully editable before sending
- System default locale for language -- Chinese users get Chinese recognition automatically
- SnackBar with brief error message on recognition failure -- no retry dialog

### Claude's Discretion
- Platform channel implementation details (MethodChannel name, call format)
- Whether to use speech_recognizer package or raw platform channel
- Mic button icon design (record/stop states)
- Exact vibration pattern

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VOICE-01 | User can input commands via microphone | `speech_to_text` package wraps Android SpeechRecognizer; long-press gesture with GestureDetector; VoiceInputService singleton; integration with `_inputController` |
| VOICE-02 | Support Chinese speech recognition | Android SpeechRecognizer uses system locale by default; Chinese devices ship with Chinese recognition; `speech_to_text` localeId for explicit Chinese if needed |
| VOICE-03 | Recognition result editable before sending | Write recognized text to `_inputController.text`; TextField already supports editing; send flow unchanged |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Tech Stack**: Flutter (Dart) -- Android only
- **Personal tool**: No commercial requirements, no multi-user
- **GSD Workflow**: All changes through GSD commands
- **Existing patterns**: Singleton + StreamController.broadcast() for state management
- **Dark theme**: Colors #1A1A2E dominant, #16213E secondary, #6366F1 accent
- **Material 3**: `useMaterial3: true`

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| speech_to_text | 7.3.0 | Wraps Android native SpeechRecognizer API | Most popular Flutter speech package, 1M+ pub points, maintained by csdcorp, supports Android/iOS/Web/Mac/Windows [CITED: pub.dev/packages/speech_to_text] |
| permission_handler | 12.0.1 | Runtime permission request for RECORD_AUDIO | Standard Flutter permission plugin, maintained by Baseflow, handles dangerous permission flow [CITED: pub.dev/packages/permission_handler] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| HapticFeedback (flutter SDK) | -- | Vibration on press/release | Built-in Flutter API, no extra dependency |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| speech_to_text | Raw platform channel to SpeechRecognizer | More code, more maintenance, same underlying API. No benefit for this use case |
| speech_to_text | speech_recognizer (pub.dev) | Less mature, fewer downloads, wraps the same Android API. `speech_to_text` is the de facto standard |
| speech_to_text | Cloud API (Baidu/Google Cloud STT) | Requires API key, network dependency, costs money. Native SpeechRecognizer is free and offline-capable |

**Decision: speech_recognizer package vs raw platform channel:** Use `speech_to_text`. The CONTEXT.md gives discretion on "whether to use speech_recognizer package or raw platform channel." The `speech_to_text` package IS the standard wrapper that uses platform channels internally to talk to Android's SpeechRecognizer. Writing raw platform channels would be hand-rolling an existing solution -- see Don't Hand-Roll section below.

**Installation:**
```bash
cd E:/ai/wzxClaw_android
flutter pub add speech_to_text
flutter pub add permission_handler
```

**Version verification:** `speech_to_text` v7.3.0 is the latest stable [CITED: pub.dev/packages/speech_to_text]; `permission_handler` v12.0.1 is latest stable [CITED: pub.dev/packages/permission_handler].

## Architecture Patterns

### Recommended File Changes

```
lib/
  services/
    voice_input_service.dart    # NEW - Singleton wrapping speech_to_text
  widgets/
    mic_button.dart             # NEW - Long-press mic button widget
  pages/
    home_page.dart              # MODIFY - Add mic button to input bar
android/
  app/src/main/AndroidManifest.xml  # MODIFY - Add RECORD_AUDIO permission
```

### Pattern 1: VoiceInputService Singleton
**What:** Singleton service wrapping `SpeechToText`, matching the project's existing singleton pattern (ConnectionManager, ChatStore).
**When to use:** Central place for speech initialization, permission checking, listen/stop lifecycle.
**Example:**
```dart
// Pattern follows existing singleton style from ConnectionManager
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get listeningStream => _statusController.stream;
  bool get isListening => _listening;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) { /* handle */ },
      onStatus: (status) { /* handle 'listening', 'done', etc. */ },
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String) onResult,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
    );
    _listening = true;
    _statusController.add(true);
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _listening = false;
    _statusController.add(false);
  }
}
```

### Pattern 2: Long-Press GestureDetector for Mic Button
**What:** Use `GestureDetector` with `onLongPressStart` and `onLongPressEnd` for hold-to-record behavior.
**When to use:** The locked decision specifies "hold to record, release to send recognized text."
**Example:**
```dart
GestureDetector(
  onLongPressStart: (_) async {
    final hasPermission = await Permission.microphone.request().isGranted;
    if (hasPermission) {
      await VoiceInputService.instance.startListening(
        onResult: (text) {
          _inputController.text = text;
        },
      );
    }
  },
  onLongPressEnd: (_) async {
    await VoiceInputService.instance.stopListening();
  },
  child: Icon(Icons.mic),
)
```

### Pattern 3: Integration with Existing Input Bar
**What:** Insert mic button between the TextField and the send button in `_buildInputBar()`.
**Where:** `home_page.dart` line 348-349 (the `SizedBox(width: 8)` before the send button).
**How:** Add mic button widget before the `SizedBox`, only visible when connected and not streaming.

### Anti-Patterns to Avoid
- **Multiple SpeechToText instances:** The plugin docs explicitly state "there should be only one instance of the plugin per application" [CITED: pub.dev/packages/speech_to_text]. Singleton pattern is mandatory.
- **Calling initialize() multiple times:** "Subsequent calls to initialize are ignored" [CITED: pub.dev/packages/speech_to_text]. Guard with a flag.
- **Requesting microphone permission without checking first:** Always check `Permission.microphone.status` before requesting -- avoids showing the dialog when already granted.
- **Not handling permanent denial:** If user permanently denies mic permission, show a SnackBar guiding them to app settings. The `permission_handler` package provides `openAppSettings()` for this.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Android SpeechRecognizer platform channel | Custom MethodChannel + EventChannel to `android.speech.SpeechRecognizer` | `speech_to_text` package | Handles RecognitionListener callbacks, locale management, error states, resource cleanup, and cross-platform abstraction. This is exactly the problem it solves. |
| Permission request flow | Custom ActivityCompat.requestPermissions() | `permission_handler` package | Handles permission status checking, rationale display, permanent denial handling, and opening app settings. |
| Vibration control | Custom VibrationEffect via platform channel | `HapticFeedback` from flutter/services.dart | Built-in Flutter API, no extra dependency, one-line call. |

**Key insight:** The `speech_to_text` package internally does exactly what a custom platform channel would do: it creates an EventChannel for streaming partial/final results and MethodChannels for start/stop/cancel. Building this manually would be ~200 lines of Kotlin + ~100 lines of Dart for zero benefit.

## Common Pitfalls

### Pitfall 1: Missing RECORD_AUDIO Permission in AndroidManifest.xml
**What goes wrong:** `speech_to_text.initialize()` returns false, or `Error 9 INSUFFICIENT_PERMISSIONS` on listen.
**Why it happens:** The AndroidManifest.xml currently only has `INTERNET` permission. `RECORD_AUDIO` is required.
**How to avoid:** Add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to AndroidManifest.xml. Also add the `<queries>` block for SDK 30+.
**Warning signs:** `initialize()` returns `false`; error listener fires with error code 9.

### Pitfall 2: Missing Android SDK 30+ Queries Declaration
**What goes wrong:** On devices running Android 11+ (API 30+), speech recognition silently fails.
**Why it happens:** Android 30 requires apps to declare which intent actions they query. Without `<queries>` for `android.speech.RecognitionService`, the system hides the recognition service from the app.
**How to avoid:** Add to AndroidManifest.xml after permissions:
```xml
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```
**Warning signs:** `initialize()` succeeds but `listen()` fails on Android 11+ devices only. [CITED: pub.dev/packages/speech_to_text]

### Pitfall 3: compileSdkVersion Too Low
**What goes wrong:** Build failure with "Manifest merger failed" or Kotlin compilation errors.
**Why it happens:** `speech_to_text` 5.2.0+ requires `compileSdkVersion 31+`. The project currently uses `flutter.compileSdkVersion` which should be 34+ on recent Flutter SDKs.
**How to avoid:** Verify the resolved compileSdk in build output. If needed, explicitly set `compileSdk = 34` in `android/app/build.gradle`.
**Warning signs:** Gradle build errors during `flutter pub get` or `flutter build`. [CITED: pub.dev/packages/speech_to_text]

### Pitfall 4: Speech Recognition Timeout
**What goes wrong:** Recognition stops after ~5 seconds of silence (Android default).
**Why it happens:** Android's SpeechRecognizer has a built-in silence timeout that cannot be configured. This is OS behavior, not a bug.
**How to avoid:** This is acceptable for the use case (short command input). If the user pauses too long, they can press and hold again. No workaround needed.
**Warning signs:** `onStatus` callback fires with `'done'` or `'inactive'` while user is still thinking.

### Pitfall 5: Last Word Dropped on Android
**What goes wrong:** The final word of a phrase is sometimes missing from the recognized text.
**Why it happens:** Known Android SpeechRecognizer issue (Google's problem, not the plugin's) [CITED: github.com/csdcorp/speech_to_text/issues/434].
**How to avoid:** No workaround available. This is a platform limitation. For command input, slightly imperfect recognition is acceptable.

### Pitfall 6: Emulator Speech Recognition Not Working
**What goes wrong:** `initialize()` succeeds but `listen()` fails on Android emulator.
**Why it happens:** The emulator's Google app may not have microphone permissions or speech recognition enabled.
**How to avoid:** Test on a real device. If emulator testing is needed, install Google app and grant mic permissions per the plugin's troubleshooting guide. [CITED: pub.dev/packages/speech_to_text]
**Warning signs:** `Error 9 after start` in logcat; works on real device but not emulator.

## Code Examples

### AndroidManifest.xml Changes
```xml
<!-- ADD after existing INTERNET permission -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- ADD after permissions section, before <application> tag -->
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```
Source: [CITED: pub.dev/packages/speech_to_text Android section]

### Permission Check Before Listening
```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> _ensureMicPermission() async {
  final status = await Permission.microphone.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) {
    // Show SnackBar directing user to app settings
    openAppSettings();
    return false;
  }
  final result = await Permission.microphone.request();
  return result.isGranted;
}
```

### HapticFeedback Usage
```dart
import 'package:flutter/services.dart';

// On long press start
HapticFeedback.lightImpact();

// On long press end / recognition complete
HapticFeedback.mediumImpact();
```

### Mic Button in Input Bar (Integration Point)
```dart
// In _buildInputBar(), insert before the SizedBox at line 348:
if (!isConnected) const SizedBox.shrink();
else if (!_isStreaming)
  _MicButton(
    onResult: (text) {
      _inputController.text = text;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    },
  ),
const SizedBox(width: 8),  // existing spacing
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw platform channels | `speech_to_text` package | Package has been standard since 2019 | Use the package, don't hand-roll |
| Android-only SpeechRecognizer | `speech_to_text` (multi-platform) | v5.0+ added Web support, v7.0+ added Mac/Windows | Future-proof if app expands to other platforms |
| Manual permission handling | `permission_handler` package | Standard since 2018 | Declarative permission API with callback support |

**Deprecated/outdated:**
- `speech_recognition` package (deprecated, unmaintained): Replaced by `speech_to_text`
- Direct `SpeechRecognizer` instantiation on Kotlin side: Not needed when using `speech_to_text`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `flutter.compileSdkVersion` resolves to 34+ (required by speech_to_text 7.x) | Standard Stack / Pitfall 3 | Build failure -- need to explicitly set compileSdk |
| A2 | Flutter SDK version installed is compatible with speech_to_text 7.3.0 | Standard Stack | May need to use older speech_to_text version |
| A3 | Android device has Google app installed with speech recognition capability (needed for SpeechRecognizer) | Common Pitfalls | initialize() fails on device without Google services |

## Open Questions

1. **compileSdkVersion resolution**
   - What we know: Project uses `compileSdk = flutter.compileSdkVersion` in build.gradle
   - What's unclear: What Flutter SDK version is installed (Flutter CLI not available on this machine), and thus what compileSdk resolves to
   - Recommendation: Run `flutter doctor` to verify Flutter SDK version. If compileSdk resolves to < 31, explicitly set `compileSdk = 34` in app/build.gradle

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build + pub add | Unknown | -- | Check with `flutter doctor` |
| Android SDK (compileSdk 31+) | speech_to_text compilation | Unknown | -- | Set explicitly in build.gradle |
| Android device with mic | Testing speech recognition | -- | -- | Must test on real device, emulator unreliable |

**Missing dependencies with no fallback:**
- Flutter SDK must be available for `flutter pub add` and `flutter run`
- Real Android device needed for meaningful speech recognition testing

**Missing dependencies with fallback:**
- None -- all dependencies are Flutter packages installable via pub

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | none -- default flutter_test |
| Quick run command | `flutter test test/` |
| Full suite command | `flutter test test/` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VOICE-01 | Mic button starts speech recognition on long press | widget | `flutter test test/widgets/mic_button_test.dart` | No -- Wave 0 |
| VOICE-01 | Recognized text appears in input controller | unit | `flutter test test/services/voice_input_service_test.dart` | No -- Wave 0 |
| VOICE-02 | Uses system locale (Chinese on Chinese device) | unit | `flutter test test/services/voice_input_service_test.dart` | No -- Wave 0 |
| VOICE-03 | Recognized text is editable in TextField | unit | `flutter test test/widgets/mic_button_test.dart` | No -- Wave 0 |
| VOICE-01 | Permission denied shows error SnackBar | unit | `flutter test test/services/voice_input_service_test.dart` | No -- Wave 0 |

Note: Speech recognition integration tests (actual mic input -> text output) require a real device and cannot be unit tested. The automated tests verify the service logic, permission handling, and widget integration. Manual testing on a real Android device is required for end-to-end verification.

### Sampling Rate
- **Per task commit:** `flutter test test/`
- **Per wave merge:** `flutter test test/`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/voice_input_service_test.dart` -- covers VOICE-01, VOICE-02 service logic
- [ ] `test/widgets/mic_button_test.dart` -- covers VOICE-03 widget integration
- [ ] Framework install: `flutter pub add speech_to_text permission_handler` -- required before tests compile
- [ ] Mock setup: `speech_to_text` needs mocking for unit tests (the plugin doesn't provide a mock interface, use a wrapper class)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A -- no auth in this phase |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | yes | Recognized text is treated as plain text input; TextField already handles this. No special validation needed for voice input. |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for Flutter Speech Recognition

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Microphone eavesdropping (continuous listening) | Information Disclosure | VoiceInputService only listens while button is held down. `stop()` is called immediately on release. No continuous listening. |
| Permission abuse (app records without consent) | Information Disclosure | `permission_handler` follows Android's runtime permission model. User must explicitly grant. Permanent denial is handled gracefully. |
| Injected text via voice (prompt injection) | Tampering | Recognized text goes through the same TextField as typed text. No elevation of privilege -- voice is just another input method. |

**Security assessment:** Low risk. Voice recognition only listens during explicit long-press. No audio is stored or transmitted. No API keys needed (uses on-device recognition).

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/speech_to_text](https://pub.dev/packages/speech_to_text) -- latest version 7.3.0, API docs, Android permissions, SDK requirements, known issues, code examples
- [pub.dev/packages/permission_handler](https://pub.dev/packages/permission_handler) -- latest version 12.0.1, Permission.microphone API, runtime request flow
- `lib/pages/home_page.dart` -- existing codebase structure, input bar layout, integration points (verified by reading file)
- `android/app/build.gradle` -- current compileSdk and minSdk configuration (verified by reading file)
- `android/app/src/main/AndroidManifest.xml` -- current permissions (verified by reading file)

### Secondary (MEDIUM confidence)
- [pub.dev/packages/speech_to_text/versions](https://pub.dev/packages/speech_to_text/versions) -- version history for verification
- [Flutter Platform Channels docs](https://blog.flutter.dev/flutter-platform-channels-ce7f540a104e) -- understanding the underlying mechanism

### Tertiary (LOW confidence)
- None -- all critical claims verified against primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- verified on pub.dev, versions confirmed
- Architecture: HIGH -- based on verified existing codebase patterns and official package docs
- Pitfalls: HIGH -- all documented in official speech_to_text README and GitHub issues

**Research date:** 2026-04-09
**Valid until:** 30 days (stable domain -- speech_to_text package is mature, Android SpeechRecognizer API is stable)

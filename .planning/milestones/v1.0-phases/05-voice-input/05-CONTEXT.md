# Phase 5: Voice Input - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

语音输入指令功能：按住麦克风按钮说话，松开后语音识别为文字，结果显示在输入框可编辑后发送。支持中文语音识别。

</domain>

<decisions>
## Implementation Decisions

### Voice Recognition Strategy
- Use native Android SpeechRecognizer via platform channel — free, no API key, offline-capable, good Chinese support
- Long-press mic button — hold to record, release to send recognized text
- Mic button placed on right side of TextField, before send button — standard chat app pattern
- Minimal audio feedback — button state change (icon animation) + platform vibrate only

### Result Handling & Integration
- Recognized text goes into existing TextField via TextEditingController — fully editable before sending
- System default locale for language — Chinese users get Chinese recognition automatically
- SnackBar with brief error message on recognition failure — no retry dialog

### Claude's Discretion
- Platform channel implementation details (MethodChannel name, call format)
- Whether to use speech_recognizer package or raw platform channel
- Mic button icon design (record/stop states)
- Exact vibration pattern

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/pages/home_page.dart` — existing TextField with `_inputController`, send button at line 357-360
- `lib/services/chat_store.dart` — `sendMessage()` method for sending text

### Established Patterns
- Singleton + StreamController.broadcast() for state management
- Dark theme with colors: #1A1A2E dominant, #16213E secondary, #6366F1 accent
- Material 3 with `useMaterial3: true`

### Integration Points
- `home_page.dart` line 357-360: send IconButton — mic button goes before this
- `_inputController` TextEditingController — voice result writes here
- `_sendMessage()` — existing send flow, no changes needed

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for Android speech recognition integration.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

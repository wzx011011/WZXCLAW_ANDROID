---
phase: 5
slug: voice-input
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK bundled) |
| **Config file** | none — default flutter_test |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test test/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test test/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | VOICE-01 | — | N/A | unit | `flutter test test/services/voice_input_service_test.dart` | ❌ W0 | ⬜ pending |
| 5-01-02 | 01 | 1 | VOICE-01 | — | Mic only listens while button held | widget | `flutter test test/widgets/mic_button_test.dart` | ❌ W0 | ⬜ pending |
| 5-01-03 | 01 | 1 | VOICE-02 | — | System locale used (no explicit override) | unit | `flutter test test/services/voice_input_service_test.dart` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 2 | VOICE-03 | — | Recognized text editable via TextEditingController | unit | `flutter test test/widgets/mic_button_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/voice_input_service_test.dart` — stubs for VOICE-01, VOICE-02 service logic
- [ ] `test/widgets/mic_button_test.dart` — stubs for VOICE-03 widget integration
- [ ] `flutter pub add speech_to_text permission_handler` — required before tests compile

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Speech recognition end-to-end on real device | VOICE-01 | Requires real mic hardware + Android SpeechRecognizer | Long-press mic button, speak Chinese, verify text appears in input |
| Chinese recognition accuracy | VOICE-02 | On-device recognition quality is device-dependent | Speak common commands in Chinese, check accuracy |
| Permission denied flow | VOICE-01 | Android system permission dialog cannot be automated | Deny mic permission, verify SnackBar error appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

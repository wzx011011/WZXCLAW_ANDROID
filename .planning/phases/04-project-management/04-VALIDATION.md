---
phase: 4
slug: project-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) — already in dev_dependencies |
| **Config file** | none |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | PROJ-03 | T-4-01 | Project model parses JSON safely | unit | `flutter test test/models/project_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | PROJ-01, PROJ-02 | T-4-02 | ProjectStore sends commands via existing WebSocket | unit | `flutter test test/services/project_store_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | PROJ-01, PROJ-02, PROJ-03 | — | Drawer renders project list with status dots | widget | `flutter test test/widgets/project_drawer_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | PROJ-01 | — | HomePage wired with Drawer | widget | `flutter test test/widgets/project_list_tile_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/project_test.dart` — stubs for PROJ-03 (Project model creation and JSON parsing)
- [ ] `test/services/project_store_test.dart` — stubs for PROJ-01, PROJ-02 (ProjectStore singleton, fetchProjects, switchProject)
- [ ] `test/widgets/project_drawer_test.dart` — stubs for PROJ-01, PROJ-02 (drawer rendering, project list, tap handling)
- [ ] `test/widgets/project_list_tile_test.dart` — stubs for PROJ-03 (tile rendering with status dot)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drawer opens on hamburger tap | PROJ-01 | Requires emulator with live desktop connection | Open app, tap hamburger, verify drawer slides in |
| Project switch updates desktop | PROJ-02 | Requires both desktop and mobile connected | Tap project in drawer, verify desktop switches |
| RefreshIndicator triggers re-fetch | PROJ-01 | Pull-to-refresh gesture in widget test is unreliable | Pull down in drawer, verify loading then refreshed list |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

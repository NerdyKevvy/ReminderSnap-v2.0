# Verification — ReminderSnap 2.0, build 20002

Checked locally on October 19, 2026 with Xcode 27.1 (27A9275), macOS 27.0.1, Apple Silicon. The existing v2.0 Preview folder was not edited.

## Passed

- Static Xcode source-membership/scheme validation for both application targets.
- macOS Debug build, local ad-hoc signature verification, and sandbox entitlement inspection. The packaged test app has App Sandbox, user-selected-file read access and Calendar access entitlements.
- Optimized macOS Release compilation for **arm64 and x86_64**. Intel is cross-compiled, not hardware-tested.
- iOS Simulator Debug compilation and launch on **iPhone 18 Pro / iOS 27.0**.
- Optimized iOS device Release compilation. This does not install or test a physical phone.
- Final builds have no app-source compiler warnings. Xcode's informational App Intents extraction warning is expected because the app has no App Intents dependency.
- Parser/date: 10 regression scenarios, zero failures.
- Existing localization and permission-refresh tests.
- Existing same-deadline, migration, no-op persistence tests; no live saves.
- Actual cropped PNG OCR, embedded PDF extraction, Photos-style data extraction and five repeated warm image reads.
- CLI self-tests.

## Interface checks

- Mac first launch: all three walkthrough steps; optional connection setup; continue without permissions; reaches Add Reminder. On subsequent launch, completed onboarding does not reappear.
- Mac: Settings and User Guide navigation, then return to Add Reminder with review items preserved.
- Mac: a coordinate click on the blank right-hand area of an unselected sidebar row selects it, confirming the full-row hit area.
- Mac: Clear All is visible outside a menu, asks for confirmation, removes synthetic review tasks and disables when empty.
- Mac: native sandboxed file picker imports the included PDF fixture; Homework 5 appears on the same Add Reminder screen, with missing course correctly flagged for review. No reminders/events were saved.
- iPhone simulator: first-launch steps, optional permissions, safe sample, Settings navigation, live English→Chinese switch, return to preserved review items, Clear All confirmation/empty state, and task editor layout.
- iPhone simulator: updated compact review layout visibly includes the first task card while keeping import controls and navigation accessible. Long lists remain scrollable.
- iPhone simulator: imported only the synthetic Cropped-homework.png through the native Photos picker. Local OCR produced Homework 5 with the expected September 24, 23:59 deadline and a missing-course review warning. No real reminders/events were saved.

## Not yet verified / release blockers

- Distribution certificates/profiles, developer team assignment, Apple archive/server validation or upload. Last local signing-identity check found no valid identities; owner is signing into Xcode.
- Public policy/support URL availability. A policy draft and in-app policy are provided; public hosting/configuration remains required.
- Real Mac/iPhone/iPad permission grants, list/calendar creation, saves and notification delivery with the new production identity. No access to personal Reminders/Calendar was granted during these checks.
- Physical iPhone/iPad operation, iPad layout/orientations, minimum supported OS behavior, VoiceOver and full Dynamic Type coverage.
- Calendar's earlier reported ghost display is not claimed repaired.

The local runnable Mac app is `dist/ReminderSnap.app`, an arm64 debug/test build. Universal Mac and physical-iOS Release build products under Build are **unsigned compile checks**, not uploadable distribution archives.

Build/test logs are retained in `Artifacts/Verification/`. Store-preparation documents and remaining gates are in `AppStore/`.

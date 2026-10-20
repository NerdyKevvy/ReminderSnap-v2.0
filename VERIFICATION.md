# Verification — ReminderSnap 2.0

Initial local checks used build 20002 on October 19, 2026 with Xcode 27.1 (27A9275), macOS 27.0.1, Apple Silicon. The existing v2.0 Preview folder was not edited. The distribution work below uses build 20003.

## Distribution checks — build 20003

- Signing team configured, Apple certificates created with owner approval, and the permanent bundle ID registered.
- Both platform archives compiled successfully with signing and dSYMs. The Mac archive is universal arm64/x86_64. The iOS archive uses an App Store distribution profile, avoiding a development-device registration requirement.
- Public privacy/support pages published and release links verified in the source and built Mac Info.plist. No OCR, parsing or persistence behavior changed for this build.
- Mac distribution export succeeded. Mac and iOS upload logs both report "Upload succeeded" and "EXPORT SUCCEEDED".
- Both builds completed Apple processing and were attached to their version 2.0 release pages. In the Owner testing internal TestFlight group, both are "Ready to Test". The approved owner invitation was sent and verified as "Invited" (one tester, two builds).
- The signed Mac archive launches and its safe sample review works. No personal Reminders/Calendar access was granted, and no real tasks were saved during these distribution checks.
- English/Simplified Chinese metadata, private review contacts, free pricing for 175 storefronts, manual release and owner-approved privacy/compliance responses are saved. Data Not Collected is published; DSA is Active; the calculated global age rating is 4+ with regional exceptions.
- Upload and TestFlight readiness are not successful real-device tests, App Review approval or a public release.

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

- Genuine store screenshots, final listing review and App Review submission. Saved metadata, approved declarations, public privacy/support links and signing/upload setup are complete; no public release has occurred.
- Real Mac/iPhone/iPad permission grants, list/calendar creation, saves and notification delivery with the new production identity. No access to personal Reminders/Calendar was granted during these checks.
- Physical iPhone/iPad operation, iPad layout/orientations, minimum supported OS behavior, VoiceOver and full Dynamic Type coverage.
- Calendar's earlier reported ghost display is not claimed repaired.

The earlier local runnable Mac app is `dist/ReminderSnap.app`, an arm64 debug/test build. Signed distribution archives for build 20003 are under Artifacts/ReminderSnap-macOS-2.0-20003.xcarchive and Artifacts/ReminderSnap-iOS-2.0-20003.xcarchive. Earlier compile-only build products are not the uploaded packages.

Build/test logs are retained in `Artifacts/Verification/`. Store-preparation documents and remaining gates are in `AppStore/`.

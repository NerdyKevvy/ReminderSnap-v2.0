# ReminderSnap 2.0 — upload status

Updated October 19, 2026. This records upload work, not App Review approval or public release.

## App record

- App: ReminderSnap
- Version: 2.0; latest build: 20004 (setup follow-up to 20003)
- Bundle ID: com.nerdykevvy.ReminderSnap
- Developer team: Z977ASQ4T3
- App Store Connect Apple ID: 6824731033
- [App Store Connect](https://appstoreconnect.apple.com/apps/6824731033/distribution)
- Source: [ReminderSnap-v2.0](https://github.com/NerdyKevvy/ReminderSnap-v2.0). Initial build 20003 used release source commit a857b69; build 20004 adds the setup follow-up described below.

## Setup follow-up — build 20004

- Owner tested build 20003: app functionality was reported working, with Calendar permission display needing one restart and the initial TestFlight guide not appearing.
- Revised guide is presented after an active window attaches and uses a new completion revision, so older retained preferences do not suppress it. Visible English/Chinese quit-and-reopen instructions are included before real imports; no automatic quit or data deletion occurs.
- Permission callbacks acknowledge approval immediately, with a separate pending-confirmation state when needed. EventKit cache reset and longer bounded refresh remain in place; actual system-confirmed full access still gates saves.
- New migration/approval/refresh tests, full regression/OCR/PDF/CLI checks, Mac build and iOS simulator build passed. The guide appeared automatically in an isolated Mac app and iPhone simulator; finishing and relaunching the Mac app did not repeat the guide. No personal Calendar/Reminders permissions or entries were changed.
- Both signed archives and uploads succeeded. Apple processed both build 20004 uploads, and both are Ready to Test in Owner testing. The group has one tester and four builds, retaining the two older builds for comparison. No new tester invitation was sent.
- Real-device recheck of the revised Calendar connection flow remains pending. Build 20004 is not an App Review approval or a public release.

## Completed

- Verified Xcode account and GitHub connection. Preserved the owner's untracked Xcode Cloud configuration.
- Registered the approved permanent bundle ID and created one Mac/iOS App Store Connect record. Existing-team Full Access was explicitly approved.
- Created signing certificates and an iOS App Store provisioning profile with owner approval. Private signing keys remain in the Mac Keychain; none were committed to GitHub.
- Published English/Chinese [privacy](PRIVACY-POLICY.md) and [support](SUPPORT.md) information and configured the app's public links.
- Built signed Mac and iOS release archives with dSYMs. Mac includes arm64 and x86_64.
- Uploaded both initial builds and verified successful Apple processing. Build 20003 was initially attached to each platform's version 2.0 release page; the setup follow-up replaces it with build 20004.
- Saved English and Simplified Chinese store descriptions, keywords and support links for both platforms, plus review notes, private review contacts and copyright. Category is Productivity. App login is not required; manual public release is selected.
- Configured a free release with no in-app purchases and all 175 available storefronts. Free Apps Agreement is Active; no paid agreement was accepted.
- Published the owner-approved Data Not Collected response, including the separately approved final privacy confirmation.
- Saved the owner's non-trader declaration; App Store Connect shows Digital Services Act status Active. Saved the approved content-rights answer and age-rating questionnaire; Apple's calculated global rating is 4+, with regional exceptions.
- Created the internal TestFlight group Owner testing with automatic distribution off and the two initial platform builds. Added only the owner and verified the initial invitation was sent. The owner subsequently installed and tested build 20003; build 20004 is now available in the same group.

## Remaining

- Owner updates TestFlight to build 20004 and checks the revised guide and Calendar connection flow. No repeat invitation acceptance is needed. See [device test checklist](DEVICE-TEST.md).
- Real-device persistence, permissions and notification testing, including iPad layout, minimum-OS checks and accessibility. No personal Apple reminders/events were written during the upload work.
- Capture and upload genuine store screenshots for each supported device family; review the saved listing text before submission.
- Address any App Store Connect validation or applicable regional requirements shown during final submission. The selected storefronts are not a legal certification for every country.
- Final App Review submission, Apple's review, and manual public release. None has occurred yet.

## Local evidence

- Artifacts/ReminderSnap-macOS-2.0-20003.xcarchive
- Artifacts/ReminderSnap-iOS-2.0-20003.xcarchive
- Artifacts/Verification/mac-appstore-archive.log
- Artifacts/Verification/mac-appstore-export.log
- Artifacts/Verification/mac-appstore-upload.log
- Artifacts/Verification/ios-appstore-archive.log
- Artifacts/Verification/ios-appstore-upload.log
- Artifacts/Submission/mac-build-ready.png
- Artifacts/Submission/ios-build-ready.png
- Artifacts/Submission/testflight-builds-ready.png
- Artifacts/Submission/testflight-invited.png
- Artifacts/ReminderSnap-macOS-2.0-20004.xcarchive
- Artifacts/ReminderSnap-iOS-2.0-20004.xcarchive
- Artifacts/Verification/setup-20004-regression.log
- Artifacts/Verification/setup-20004-mac-upload.log
- Artifacts/Verification/setup-20004-ios-upload.log
- Artifacts/Submission/setup-restart-20004.png
- Artifacts/Submission/setup-20004-ios-chinese.png
- Artifacts/Submission/testflight-ready-20004.png

Artifacts and build logs are ignored by Git. Review contact details are entered only into Apple's private review fields, not these public documents.

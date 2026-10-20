# ReminderSnap 2.0 — upload status

Updated October 19, 2026. This records upload work, not App Review approval or public release.

## App record

- App: ReminderSnap
- Version: 2.0; build: 20003
- Bundle ID: com.nerdykevvy.ReminderSnap
- Developer team: Z977ASQ4T3
- App Store Connect Apple ID: 6824731033
- [App Store Connect](https://appstoreconnect.apple.com/apps/6824731033/distribution)
- Source: [ReminderSnap-v2.0](https://github.com/NerdyKevvy/ReminderSnap-v2.0), release source commit a857b69

## Completed

- Verified Xcode account and GitHub connection. Preserved the owner's untracked Xcode Cloud configuration.
- Registered the approved permanent bundle ID and created one Mac/iOS App Store Connect record. Existing-team Full Access was explicitly approved.
- Created signing certificates and an iOS App Store provisioning profile with owner approval. Private signing keys remain in the Mac Keychain; none were committed to GitHub.
- Published English/Chinese [privacy](PRIVACY-POLICY.md) and [support](SUPPORT.md) information and configured the app's public links.
- Built signed Mac and iOS release archives with dSYMs. Mac includes arm64 and x86_64.
- Uploaded both builds and verified successful Apple processing. Build 20003 is attached to each platform's version 2.0 release page.
- Saved English and Simplified Chinese store descriptions, keywords and support links for both platforms, plus review notes, private review contacts and copyright. Category is Productivity. App login is not required; manual public release is selected.
- Configured a free release with no in-app purchases and all 175 available storefronts. Free Apps Agreement is Active; no paid agreement was accepted.
- Published the owner-approved Data Not Collected response, including the separately approved final privacy confirmation.
- Saved the owner's non-trader declaration; App Store Connect shows Digital Services Act status Active. Saved the approved content-rights answer and age-rating questionnaire; Apple's calculated global rating is 4+, with regional exceptions.
- Created the internal TestFlight group Owner testing with automatic distribution off. Both Mac and iOS builds are Ready to Test. Added only the owner as a tester and verified the invitation status is Invited: one tester, two builds.

## Remaining

- Owner accepts the emailed TestFlight invitation and installs the builds on their devices. See [device test checklist](DEVICE-TEST.md).
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

Artifacts and build logs are ignored by Git. Review contact details are entered only into Apple's private review fields, not these public documents.

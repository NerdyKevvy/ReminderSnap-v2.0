# ReminderSnap — upload status

Updated October 25, 2026. Version 2.1 (20106) is available in internal TestFlight
for macOS and iOS. Version 2.0 remains iOS Ready for Distribution; macOS In Review.

## October 25 — final live-test follow-up, 2.1 (20106)

- Corrected source published in 116cb45. Both signed build 20106 uploads succeeded,
  Apple processing completed, and both platforms show Testing in Owner testing
  (one tester, eight builds). Bilingual What to Test notes saved on both builds.
  This is the recommended follow-up to 20100; intermediate development uploads
  were not added to owner testing. No new tester invitation was sent.
- [Mac 20106](https://appstoreconnect.apple.com/teams/6ece4185-8e0e-4f29-b306-ad88d6178e84/apps/6824731033/testflight/macos/f7f72a7f-55ff-4479-a12a-a8704e2246a6)
  and [iOS 20106](https://appstoreconnect.apple.com/teams/6ece4185-8e0e-4f29-b306-ad88d6178e84/apps/6824731033/testflight/ios/aa243ddf-e278-4867-aa02-6f359710a15f).
- Fixed hidden external-demo and linked-task notices, multi-account Google event
  links, and real-task bulk block controls. Google deletion now bypasses cached
  event data and handles version conflicts with fresh ownership/version checks.
- Owner completed native Google consent. On Mac, the connection restored after
  relaunch; a labelled test exported and opened in the correct personal account.
  Editing updated the same Google event without duplication. Block-only removal
  then deleted that event, kept its in-app assignment, and reached zero pending
  updates. No test notifications were scheduled.
- Public Google OAuth enabled with the owner's explicit approval. Its scopes
  remain account ID/email and app-created calendars only; Google says no
  sensitive/restricted data-access verification is required. Project-site
  ownership verified through Search Console. App-name branding remains pending:
  Google's feedback says to wait 24 hours after ownership verification before
  retrying, to allow propagation. Retry no earlier than October 26.
- Website/support text now reflects public Google sign-in and the 2.1 beta status.
  [Device acceptance](DEVICE-TEST-2.1.md) and proposed [release text](RELEASE-NOTES-2.1.md)
  are prepared. Physical-device camera, notifications, iCloud round-trip/conflicts,
  accessibility and final store/privacy acceptance remain open. No public 2.1
  review submission or release occurred.
- Evidence: Artifacts/Submission/google-site-verified-2026-10-25.png,
  google-production-enabled-2026-10-25.png, google-linked-edit-verified-2026-10-25.png,
  and google-cleanup-zero-pending-2026-10-25.png. Test data remains labelled in-app;
  no personal Apple reminders/events were changed.
- Final availability proof: Artifacts/Submission/testflight-20106-ready-2026-10-25.png.
  Live website reflects the current Google/beta status and is visually captured in
  Artifacts/Submission/website-live-updated-2026-10-25.png.

## October 25 — update 2.1 beta

- Source and website published to main in commit 31ec2d1 with the owner's explicit
  approval. Both signed 2.1 (20100) archives uploaded and processed successfully.
  App Store Connect shows both platforms Testing in Owner testing (one tester,
  six builds including retained 2.0 builds). Bilingual beta test notes are saved.
- [Mac beta build](https://appstoreconnect.apple.com/teams/6ece4185-8e0e-4f29-b306-ad88d6178e84/apps/6824731033/testflight/macos/31a203ee-4c8b-4f91-a01a-f54c49fac155)
  and [iOS beta build](https://appstoreconnect.apple.com/teams/6ece4185-8e0e-4f29-b306-ad88d6178e84/apps/6824731033/testflight/ios/485ae7c7-2700-4f2d-bb17-79a27b4dcbba).
- Verified the free HTTPS [website](https://nerdykevvy.github.io/ReminderSnap-v2.0/),
  [privacy policy](https://nerdykevvy.github.io/ReminderSnap-v2.0/privacy.html), and
  [support page](https://nerdykevvy.github.io/ReminderSnap-v2.0/support.html) render.
  GitHub Pages deploys main/docs. The site labels 2.1 and Google access as beta.
- Google consent branding saved with the live homepage/privacy URLs and authorized
  domain nerdykevvy.github.io. Audience remains External / Testing, with only the
  configured owner account. Native sign-in opened the system browser successfully;
  completion and calendar export still need a real connection test. Website
  ownership verification and public Google launch are not yet certified complete.
- Real-device acceptance is recorded separately in [2.1 device checks](DEVICE-TEST-2.1.md).
  Compilation/regression checks passed, but do not substitute for camera, actual
  notification delivery, cross-device iCloud or linked edit/delete acceptance.
- No public 2.1 App Review submission or release has been made. Current store
  privacy answers were not changed. The older macOS 2.0 submission now shows
  In Review; it was not withdrawn or replaced.
- Evidence: Artifacts/Submission/testflight-20100-ready-2026-10-25.png and
  Artifacts/Submission/website-live-2026-10-25.png. Artifacts remain ignored.

The following sections preserve the 2.0 submission history.

## App record

- App: ReminderSnap
- Version: 2.0; latest build: 20004 (setup follow-up to 20003)
- Bundle ID: com.nerdykevvy.ReminderSnap
- Developer team: Z977ASQ4T3
- App Store Connect Apple ID: 6824731033
- [App Store Connect](https://appstoreconnect.apple.com/apps/6824731033/distribution)
- Source: [ReminderSnap-v2.0](https://github.com/NerdyKevvy/ReminderSnap-v2.0). Initial build 20003 used release source commit a857b69; build 20004 adds the setup follow-up described below.

## October 22 review outcome and metadata correction

- Verified the iOS version 2.0 sidebar status is Ready for Distribution. The owner reports the iOS app is released and reachable by its App Store link. This turn did not change, withdraw, replace or resubmit the released iOS binary; country-by-country availability and search indexing were not audited.
- Mac review rejected version 2.0 (20004) under guideline 5.2.5, specifically for Apple terms in the subtitle. No code defect or binary change was requested in that report.
- Saved neutral English and Simplified Chinese subtitles: "Screenshots to tasks" and "截图识别，轻松创建待办与日程". These fields are shared App Information; Apple's page says changes release with the next app version, rather than being Mac-only fields.
- As a precaution, replaced only the third Mac screenshot in both languages with neutral headlines. The listing still has three panels per locale, and the former panels remain in Apple's Asset Library and a local ignored archive. No released iPhone/iPad screenshots were changed.
- Sent a factual reply to App Review at 4:11 PM Eastern describing the metadata corrections; no new legal agreement or compliance declaration was accepted.
- Resubmitted the same Mac build 20004 at 4:12 PM Eastern on October 22. Verified both the submission and its app-version item show Waiting for Review. Submission ID remains 1e9ef1ae-175f-4905-acf0-2ebf5e05e9bd. Mac manual release remains selected; Mac approval/public release has not occurred.
- The two revised PNGs passed exact 2880×1800, PNG/no-alpha checks and visual inspection. Renderer syntax and git diff whitespace checks passed. No application code or binary was changed, rebuilt or uploaded.

## Setup follow-up — build 20004

- Owner tested build 20003: app functionality was reported working, with Calendar permission display needing one restart and the initial TestFlight guide not appearing.
- Revised guide is presented after an active window attaches and uses a new completion revision, so older retained preferences do not suppress it. Visible English/Chinese quit-and-reopen instructions are included before real imports; no automatic quit or data deletion occurs.
- Permission callbacks acknowledge approval immediately, with a separate pending-confirmation state when needed. EventKit cache reset and longer bounded refresh remain in place; actual system-confirmed full access still gates saves.
- New migration/approval/refresh tests, full regression/OCR/PDF/CLI checks, Mac build and iOS simulator build passed. The guide appeared automatically in an isolated Mac app and iPhone simulator; finishing and relaunching the Mac app did not repeat the guide. No personal Calendar/Reminders permissions or entries were changed.
- Both signed archives and uploads succeeded. Apple processed both build 20004 uploads, and both are Ready to Test in Owner testing. The group has one tester and four builds, retaining the two older builds for comparison. No new tester invitation was sent.
- A separate explicit real-device recheck of the revised Calendar connection flow has not been recorded. Build availability by itself does not prove device behavior; the later iOS review outcome is recorded above.

## Completed

- Created black/silver product-page panels around genuine fictional-sample captures. Uploaded three each for Mac, iPhone Dynamic Island medium and iPad 13-inch in English and Simplified Chinese (18 images). No owner calendar, reminder list or personal course screenshot was published. Optional larger iPhone exports are retained locally.
- Corrected the required Chinese privacy-policy URL to the already published bilingual policy. The published Data Not Collected response was not changed.
- Mac version 2.0 (20004) passed App Store Connect validation and was initially submitted on October 20 at 11:11 AM Eastern. Its October 22 correction/resubmission is recorded above.
- After screenshot processing completed, iOS version 2.0 (20004), including iPhone/iPad, passed validation and was submitted on October 20 at 11:14 AM Eastern. Submission ID: 67142bc3-9749-4061-b295-cbfcd3cb1cd7. Both initial submissions were then Waiting for Review; the current iOS outcome is recorded above.
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
- Address any App Store Connect validation or applicable regional requirements shown during final submission. The selected storefronts are not a legal certification for every country.
- Apple's review of the corrected Mac submission, any additional feedback, and the selected Mac manual public release after approval. iOS is already Ready for Distribution. Investigate the owner's reported iOS search visibility separately if it persists.

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
- Artifacts/Submission/store-mac-media-zh.png
- Artifacts/Submission/store-ios-media-zh.png
- Artifacts/Submission/mac-submitted-20004.png
- Artifacts/Submission/both-submitted-20004.png
- Artifacts/Submission/mac-resubmitted-20004-2026-10-22.png
- Artifacts/StoreMedia/preview-en-US.png
- Artifacts/StoreMedia/preview-zh-Hans.png

Artifacts and build logs are ignored by Git. Review contact details are entered only into Apple's private review fields, not these public documents.

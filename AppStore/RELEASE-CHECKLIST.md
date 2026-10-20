# App Store release gates — 2.0 (20004)

## Prepared in this folder

- [x] Approved permanent bundle ID: com.nerdykevvy.ReminderSnap; same for Mac/iOS.
- [x] Native Mac and iOS Xcode schemes; macOS 13+, iOS/iPadOS 17+.
- [x] Mac sandbox, selected-file read access, Calendar/Reminders entitlement.
- [x] Reminders/Calendar purpose strings and local-only privacy manifest.
- [x] App icons; English/Chinese app UI; first-use guide.
- [x] In-app privacy policy and public privacy/support pages.
- [x] Production product/display name and parameterized bundle/version values.

## Signing, upload and store setup

- [x] Developer signed into Xcode; approved team Z977ASQ4T3 configured.
- [x] Apple Development, Apple Distribution and Mac Installer Distribution certificates created with the owner's approval. iOS App Store distribution profile generated and installed.
- [x] Bundle ID registered; App Store Connect record 6824731033 created with both macOS and iOS. Existing-team Full Access approved by the owner.
- [x] Privacy policy published in the approved public GitHub repository and configured in both app targets and App Store Connect.
- [x] Public support page published; in-app links point to the v2.0 repository.
- [x] App name ReminderSnap, category Productivity and copyright 2026 Junhan Li saved. Price is free across all 175 available storefronts, as requested by the owner.
- [x] Owner selected Free with no in-app purchases. Free Apps Agreement is Active; no Paid Apps Agreement was accepted.
- [x] Owner-approved content-rights and age-rating answers saved; Apple's calculated rating is 4+ with regional exceptions. Owner's non-trader DSA declaration saved and Active. Encryption flag is false because no custom/non-exempt encryption is implemented; reassess if dependencies change.
- [x] Final implementation reviewed for App Privacy; owner approved Data Not Collected and the final confirmation, and the response is published. Apple's account sync is independent; voluntary public support posts are described separately in the policy.
- [x] English and Simplified Chinese listing metadata, public support links, private review contacts and testing notes saved for both platforms.
- [x] Signed distribution archives with dSYMs exported and uploaded for version 2.0 (20003) on both platforms. Both upload logs report success; Apple processing succeeded and the builds are attached to their release pages.
- [x] Owner testing internal TestFlight group contains both builds as Ready to Test. Only the owner was added, with explicit approval; the owner subsequently installed and tested build 20003. Automatic build distribution is off.
- [x] Manual public release selected for both platforms. Mac and iOS App Review submissions completed October 20; no public release has occurred.
- [x] Setup follow-up build 20004 compiled, archived, uploaded and processed for Mac/iOS; added to the same owner TestFlight group. Local tests cover old guide preferences, first presentation, restart instructions, approval/pending/revoked state and late refresh. Owner reported the rest of build 20003 working; the new connection flow still requires their device recheck.

## Remaining before public release

- [x] Owner accepted TestFlight and tested build 20003. Follow-up build 20004 is available; a separate explicit device recheck of the revised connection flow has not been recorded. See [DEVICE-TEST.md](DEVICE-TEST.md).
- [ ] Complete real-device testing on iPhone/iPad and sandboxed Mac with dedicated test list/calendar: grant/deny/re-grant, destination creation, two identical imports, same-day deadlines, notifications, timezone/DST, Photos, Files, multitasking and accessibility.
- [ ] Confirm minimum supported OS behavior and iPad layouts. Test large text, VoiceOver, keyboard navigation and localization. Simulator success is not physical-device notification validation.
- [ ] Confirm permissions and saved entries behave after a signed update/reinstall. The production ID is different from the preview ID, so permissions/preferences do not automatically carry over.
- [x] Capture and upload three genuine sample-based feature panels for Mac, iPhone and iPad in English and Simplified Chinese. All PNG exports passed dimension/format/no-alpha checks. No owner personal task or calendar data was published.
- [x] Resolve current App Store Connect validation: Chinese privacy-policy link added, screenshots processed and both submissions accepted into Waiting for Review. Selecting all storefronts does not establish country-specific legal clearance; address any later applicable requirement if raised.
- [x] Submit macOS 2.0 (20004) for App Review; status Waiting for Review, October 20, 2026.
- [x] Submit iOS 2.0 (20004) for App Review; status Waiting for Review, October 20, 2026.
- [ ] Address review feedback for either platform if any and perform the selected manual release after approval.

Suggested archive command after signing and public policy are ready:

```sh
RELEASE_TEAM_ID=YOUR_TEAM RELEASE_PRIVACY_URL=https://YOUR_PUBLIC_POLICY zsh Scripts/archive-release.sh macOS
RELEASE_TEAM_ID=YOUR_TEAM RELEASE_PRIVACY_URL=https://YOUR_PUBLIC_POLICY zsh Scripts/archive-release.sh iOS
```

The archive script does not upload or accept contracts. Set RELEASE_ALLOW_PROVISIONING=1 only for an already approved account when provisioning updates are desired. An iOS archive can use a manual App Store distribution profile when the team has no registered development devices. The initial iOS distribution archive used the profile named "ReminderSnap App Store" and the Apple Distribution certificate.

Scripts/ExportOptions-AppStore.plist exports locally. Scripts/ExportOptions-Upload.plist uploads to the configured team when explicitly used with xcodebuild -exportArchive. Reusing a build number already accepted by Apple will require a new build number for a changed binary.

Official references:
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy

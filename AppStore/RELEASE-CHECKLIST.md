# App Store release gates — 2.0 (20002)

## Prepared in this folder

- [x] Approved permanent bundle ID: com.nerdykevvy.ReminderSnap; same for Mac/iOS.
- [x] Native Mac and iOS Xcode schemes; macOS 13+, iOS/iPadOS 17+.
- [x] Mac sandbox, selected-file read access, Calendar/Reminders entitlement.
- [x] Reminders/Calendar purpose strings and local-only privacy manifest.
- [x] App icons; English/Chinese app UI; first-use guide.
- [x] In-app privacy policy, support entry point and local privacy-policy draft.
- [x] Production product/display name and parameterized bundle/version values.

## Must finish before upload/review

- [ ] Developer signs into Xcode; select the correct approved team.
- [ ] Configure valid signing certificates/profiles. Creating credentials or accepting terms requires the account owner's involvement.
- [ ] Register the bundle ID and create the App Store Connect app record, adding both macOS and iOS if both will launch together.
- [ ] Publish the reviewed policy in PRIVACY-POLICY.md at a public HTTPS URL; set REMINDERSNAP_PRIVACY_POLICY_URL in both targets/configurations or supply it during archive.
- [ ] Verify the support URL is public and usable. GitHub issues are the current in-app support destination; a separate public support page can be used.
- [ ] Confirm app name, copyright holder, category, price and release countries/regions with the owner.
- [ ] If paid upfront: Paid Apps Agreement, tax and banking. No IAP does not eliminate this requirement.
- [ ] Owner answers age rating, export compliance, content rights, EU trader status and applicable agreements. Encryption flag is false because no custom/non-exempt encryption is implemented; reassess if dependencies change.
- [ ] App Privacy declarations: verify final binary/SDKs. Expected developer collection is None for this implementation; Apple's account sync is independent. Review support-channel handling separately.
- [ ] Complete real-device testing on iPhone/iPad and sandboxed Mac with dedicated test list/calendar: grant/deny/re-grant, destination creation, two identical imports, same-day deadlines, notifications, timezone/DST, Photos, Files, multitasking and accessibility.
- [ ] Confirm minimum supported OS behavior and iPad layouts. Test large text, VoiceOver, keyboard navigation and localization. Simulator success is not physical-device notification validation.
- [ ] Confirm permissions and saved entries behave after a signed update/reinstall. The production ID is different from the preview ID, so permissions/preferences do not automatically carry over.
- [ ] Capture genuine Mac/iPhone/iPad release screenshots, add localized listing metadata, review contact details and testing notes.
- [ ] Create distribution archives with dSYMs; inspect final sandbox/privacy/icon resources. Validate in Organizer, upload, wait for processing, address server-side validation errors.
- [ ] Select processed builds, complete TestFlight testing as desired, and obtain owner's final pricing/metadata/release-method decision before submission.

Suggested archive command after signing and public policy are ready:

```sh
RELEASE_TEAM_ID=YOUR_TEAM RELEASE_PRIVACY_URL=https://YOUR_PUBLIC_POLICY zsh Scripts/archive-release.sh macOS
RELEASE_TEAM_ID=YOUR_TEAM RELEASE_PRIVACY_URL=https://YOUR_PUBLIC_POLICY zsh Scripts/archive-release.sh iOS
```

The script deliberately does not upload, accept contracts, or generate new signing identities automatically.

Official references:
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy

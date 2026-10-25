# ReminderSnap 2.1 release work

Existing app: `com.nerdykevvy.ReminderSnap`, App Store ID 6824731033.
Keep 2.0 production/review submissions intact. Prepare 2.1 as an update.

## Acceptance checklist

- [ ] Calendar-first assignment center; persistent tasks and course colours/legend.
- [ ] Private iCloud sync, explicit offline/account/error status; no screenshot sync.
- [ ] Own local notifications, editable 24h/2h defaults, date-only morning option,
      completion/deletion cancellation and task-specific notification navigation.
- [ ] Layout-aware Gradescope/Canvas extraction, wrapped titles, broader course
      recognition, section profiles, actionable missing-information panel.
- [ ] iPhone camera capture with overlay, crop/retake and bounded OCR retries.
- [ ] Short bilingual visual onboarding, sample, workflow selection, clear output.
- [ ] On-demand Google Calendar sign-in and app-owned event export/linked edits.
- [ ] Optional Apple Reminders/Calendar linked edits with duplicate protection.
- [ ] Safe separation of Clear Import, saved-task deletion, and linked-item deletion.
- [ ] Regression tests, Mac/iPhone/iPad build and UI checks.
- [ ] CloudKit production schema/capabilities/profiles configured and tested.
- [ ] Accurate privacy/support/store metadata and fresh screenshots.
- [ ] Signed archives uploaded to existing App Store Connect app; TestFlight
      testing before public review/release. No incomplete integration advertised.

### Delivery checkpoint — October 25

Both 2.1 (20100) platform builds are uploaded, processed and Testing in the
existing Owner testing group. Source and static site are public at commit
31ec2d1. The free GitHub Pages homepage, privacy and support pages render over
HTTPS. Google branding contains those public links and the authorized domain;
its audience remains Testing. Actual Google consent/export and cross-device
acceptance are still pending. See [device checks](DEVICE-TEST-2.1.md) and
[upload status](UPLOAD-STATUS.md). Checkboxes above intentionally represent
completed acceptance, rather than implementation or compilation alone.

### Live-test follow-up — build 20106

- Fixed the external workflow confirmation being hidden behind the welcome sheet.
  Linked-task notices also present on the visible assignment detail sheet.
- Google event links now normalize Google's documented API htmlLink and target
  the connected account, avoiding the browser's unrelated default school account.
  Regression cases cover account routing, event identity and host restrictions.
- Moved bulk linked-block removal out of the sample-only banner into real task
  selection controls, with a compact layout fallback.
- Google requests bypass response caching. Block deletion checks the latest
  ownership marker and ETag, retries version conflicts at most three times, and
  retains pending work when it cannot complete safely.
- Real Mac tests passed Google consent, connection restoration, export, same-event
  editing, account-aware opening and block removal while keeping the assignment.
  No notifications were scheduled for the labelled test task.
- Public Google OAuth was enabled with explicit owner approval. Google reports
  no sensitive/restricted scopes requiring data-access verification. Search Console
  verified the project website; Google branding asks for a 24-hour propagation
  wait before retrying app-name verification. This is not a completed brand review.
- Signed macOS and iOS 2.1 (20106) archives/uploads succeeded. Both processed
  builds are Testing in Owner testing, with bilingual test instructions saved.
  Intermediate uploaded builds were not added to the group. Use build 20106.
- Physical-device camera, notifications, cross-device iCloud/conflicts, accessibility
  and public store metadata/privacy acceptance remain open.

## External prerequisites

Google project creation authorized by owner. Console initially selected NYU
organization; owner asked to choose personal account and accept Google terms.
Never enable billing or accept legal declarations without explicit approval.

## October 23 implementation / verification checkpoint

Implemented for internal beta (not a public-release certification): calendar-first
persistent planner and course legend; private CloudKit storage; local alerts;
layout-aware Gradescope/Canvas parsing and section profiles; missing-details
panel; iOS camera overlay/crop/retake; bilingual visual setup; optional Apple
and Google exports, linked edits and bulk block removal.

- Regression suite, scheduling/DST/deletion tests, actual OCR/PDF and repeated
  reads pass. Both platform release archives 2.1 (20100) succeeded. Mac archive
  contains arm64 and x86_64 and passed signature validation outside sandbox.
- Google Calendar API/native public client and minimal scopes configured. Owner
  Gmail is the sole OAuth test user. Production authorization/branding is NOT
  complete; real Google sign-in, refresh and export remain to be tested.
- CloudKit private database model initialized and deployed to Production.
  Development Mac reported completed sync activity. Real Mac/iPhone round-trip,
  offline/conflicting edits and account-switch behavior remain acceptance tests.
- Updated bilingual privacy/support pages published in commit 2d6c5be. App Store
  privacy declaration has NOT been changed for 2.1; assess before public release.
- Final phone/tablet UI smoke testing was interrupted by Device Hub automation
  errors (noWindowsAvailable). Simulator compilation is successful, but is NOT
  proof of working camera, alerts, permissions or device layouts.
- First-launch sample now completes setup; explicit refresh reapplies alert
  settings to existing eligible links; external Apple alarm updates preserve
  user-created alarms not identified as app-managed.
- Underlined digits in the compressed mobile Gradescope sample remain imperfect
  (8 missing / 7 read as Z). Rows remain separate and are flagged for review;
  do not advertise perfect OCR or silently manufacture missing numbers.

### Required before public review

1. Owner TestFlight testing on physical iPhone/iPad/Mac: onboarding/relaunch,
   imports including the supplied failures, camera, missing details and sections.
2. Notification delivery/cancellation and linked edit/delete tests using disposable
   assignments; confirm no duplicate exports/alerts. Apple updates are performed
   by the original exporting device, not by every synced device.
3. Real private iCloud round-trip/offline/account tests and direct Google login,
   export/retry/disconnect tests. Finish Google public branding/domain setup.
4. Refresh store screenshots/description and confirm accurate privacy answers.
   Keep the released iOS app and existing macOS 2.0 review untouched meanwhile.

## Design decisions

- Local database is authoritative; private CloudKit mirrors reviewed structured
  records across the same Apple account. No school login or developer server.
- External exports are optional; edits from this app update linked items. Do not
  imply unrestricted two-way sync or automatically recreate exports on every device.
- Google credentials and OS permissions are device-local, not synced task data.
- No user screenshots are sent to third-party AI or committed to public fixtures.
- Preserve existing owner-created Xcode Cloud configuration.

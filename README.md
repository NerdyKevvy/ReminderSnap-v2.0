# ReminderSnap 2.0 — release preparation

Native Mac, iPhone and iPad app. Local Apple Vision reading, Apple Reminders, optional Calendar blocks, English and 简体中文. This folder preserves the previous Studio Preview separately.

## What changed

- Three destinations only: **Add Reminder**, **Settings**, **User Guide**.
- Import and review share one screen. Choose files, Photos, or drop images/PDFs; extracted tasks appear below.
- **Clear All** stays visible in the header. Confirmation explains that it only clears the current review and temporary recognition text, never saved Apple entries or source files.
- A three-step first-launch walkthrough explains the workflow, offers permissions and custom list/calendar creation, and explains syncing and notifications. Permissions are optional until saving. Replay it from User Guide or Help.
- Apple app connections are inside User Guide, not a fourth navigation destination.
- Sidebar buttons have explicit full-row hit areas; decorative borders ignore pointer input. Only the Add Reminder content accepts drops. A single Mac workspace prevents shared sheets across multiple windows.
- Production app name and approved bundle ID: **ReminderSnap**, **com.nerdykevvy.ReminderSnap**. Version 2.0, build 20004. Both Xcode schemes use the same ID.
- Build 20004 presents the revised setup guide after the first active window appears, including upgrades with old setup preferences. After granting Apple app access, it recommends quitting and reopening once; the guide explains that unsaved review items are session-only. Permission callback feedback is distinct from system-confirmed full access, which is still required to save.
- Privacy Policy is accessible inside Settings. The [published privacy policy](AppStore/PRIVACY-POLICY.md) and [support page](AppStore/SUPPORT.md) are configured for the release.

## Local testing

Open `dist/ReminderSnap.app` after running the local build script. This is a sandboxed, locally signed test app, not the distribution-signed App Store build. No global Gatekeeper settings need to change.

Full Xcode is required. If Xcode is not globally selected, set `DEVELOPER_DIR` to its `Contents/Developer` directory when invoking commands.

```sh
zsh Scripts/build-local.sh
zsh Scripts/test.sh
```

For iOS, open `ReminderSnap.xcodeproj`, select **ReminderSnap-iOS**, and choose an installed simulator. For a physical device, sign in to Xcode and choose your development team first. Requirements: macOS 13+, iOS/iPadOS 17+.

The safe sample never writes to Apple’s apps. Real saves and creation of named lists/calendars require explicit user actions. Use dedicated test destinations for live integration checks.

New imports replace the current review list. Select all screenshots for a batch together. Overlapping screenshots are deduplicated by the parser. Importing a new file, Clear All, and quitting do not delete source files or previously saved tasks.

## Release gates

Both platform builds of version 2.0 were signed and uploaded to App Store Connect on October 19, 2026. The initial build 20003 was followed by setup-fix build 20004, available in the same owner TestFlight group. Upload is separate from App Review and public release. See [upload status](AppStore/UPLOAD-STATUS.md), `AppStore/RELEASE-CHECKLIST.md` and `VERIFICATION.md` for the completed work and remaining release gates.

Xcode project regeneration: `ruby Scripts/make-project.rb`. Static validation: `ruby Scripts/validate-project.rb`. Do not regenerate after adding signing settings manually without preserving those settings.

## Deadline behavior

Real reminder deadlines are unchanged. 23:59 deadlines get optional 22:00–23:00 companion blocks on the same day. Other timed blocks follow the existing schedule; date-only tasks remain date-only reminders. Extra alerts are on Calendar events, deadline notifications are on Reminders. Delivery depends on Apple settings and Focus.

Scheduled-reminder display in Calendar requires macOS 15 / iOS 18 or later. Companion events work independently. Apple account settings control cross-device sync. No cloud OCR, analytics SDK, ads, or account system is included.

The prior Apple Calendar ghost-rendering issue is not claimed fixed by this UI change. Existing tasks are not bulk-deleted or repaired automatically.

# Owner TestFlight check — 2.0 (20004)

Build 20004 revises onboarding and permission feedback after the owner's tests of build 20003. Use the update when it appears in the existing Owner testing group. This checklist does not imply the new device checks have already passed.

1. Open Apple's [TestFlight](https://developer.apple.com/testflight/) on your Mac and iPhone/iPad and update to ReminderSnap 2.0 (20004). No new invitation is needed for the same group.
2. Check that the revised pop-up guide appears automatically once, even if you previously completed the old guide. Check English/简体中文, finish setup, quit and reopen: the completed guide should not automatically repeat. User Guide must still allow replay.
3. In User Guide, connect Reminders and Calendar. The app should acknowledge a successful permission request immediately and refresh automatically. If the system confirmation lags, it should show Approved · reopen app rather than claim full access. Follow the explicit quit/reopen instructions once after granting/changing access, before importing real tasks; then verify permission and destination status. Also check denied access followed by enabling it in system settings and returning to the app. Do not revoke personal permissions unless you want to perform that test.
4. Check sidebar/tab navigation and the visible Clear All button. Create or select a dedicated test reminder list and calendar. Use a non-personal screenshot/PDF, including a cropped screenshot, and review the extracted course, title, date and time. Clear All must remove review items only, never saved Apple entries.
5. Set one task's deadline a few minutes in the future, select a notification, and save it. Confirm the actual due date/time in Apple Reminders. Confirm an optional companion block is a separate event in the chosen calendar, not a changed deadline.
6. Test several tasks due on the same day, overlapping inputs and a repeated import. Check for unintended duplicates, shifted dates or ghost displays. Record any issue rather than deleting unrelated calendar data.
7. With system notifications enabled and Focus configured to allow delivery, check a future notification. Past-due examples cannot validate notification delivery. Test extra Calendar alerts separately where enabled.
8. Check layout on each supported device, including iPad orientations if available, larger text, VoiceOver and keyboard navigation. Report any device/OS combination you could not test.

Report the device, OS version, selected language and exact steps for any failure. Avoid posting personal screenshots, calendar entries or account details in public GitHub issues. The safe Try Sample flow deliberately does not write real reminders/events; use a real import into dedicated test destinations for persistence testing.

App Review submission and manual public release are still pending. Store screenshots also remain to be prepared and uploaded.

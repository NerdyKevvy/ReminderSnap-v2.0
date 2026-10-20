# Owner TestFlight check — 2.0 (20003)

Both Mac and iOS builds are Ready to Test in the Owner testing group. The invitation has been sent to the owner's confirmed email. This checklist does not imply these device tests have already passed.

1. Install Apple's [TestFlight](https://developer.apple.com/testflight/) on your Mac and iPhone/iPad, accept the emailed invitation and install ReminderSnap 2.0 (20003).
2. Check the first-launch guide, English/简体中文 switching, sidebar/tab navigation and visible Clear All button. Clear All should remove only review items, not previously saved Apple tasks/events.
3. In User Guide, connect Reminders and Calendar. Granting access should update the displayed status without restarting. Also check denied access followed by enabling it in system settings and returning to the app.
4. Create or select a dedicated test reminder list and calendar. Use a non-personal screenshot/PDF, including a cropped screenshot, and review the extracted course, title, date and time.
5. Set one task's deadline a few minutes in the future, select a notification, and save it. Confirm the actual due date/time in Apple Reminders. Confirm an optional companion block is a separate event in the chosen calendar, not a changed deadline.
6. Test several tasks due on the same day, overlapping inputs and a repeated import. Check for unintended duplicates, shifted dates or ghost displays. Record any issue rather than deleting unrelated calendar data.
7. With system notifications enabled and Focus configured to allow delivery, check a future notification. Past-due examples cannot validate notification delivery. Test extra Calendar alerts separately where enabled.
8. Check layout on each supported device, including iPad orientations if available, larger text, VoiceOver and keyboard navigation. Report any device/OS combination you could not test.

Report the device, OS version, selected language and exact steps for any failure. Avoid posting personal screenshots, calendar entries or account details in public GitHub issues. The safe Try Sample flow deliberately does not write real reminders/events; use a real import into dedicated test destinations for persistence testing.

App Review submission and manual public release are still pending. Store screenshots also remain to be prepared and uploaded.

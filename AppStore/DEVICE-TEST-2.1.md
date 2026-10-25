# Owner TestFlight check — 2.1 (20106)

Both macOS and iOS builds are in the existing Owner testing group. This is an
internal beta; build availability does not establish that the checks below pass.
Use disposable assignments, with no personal source images posted publicly.

1. Update to 2.1 (20106) on each device. Check the visual introduction in English
   and Simplified Chinese, try its calendar preview, finish it and relaunch.
   The normal first page should be Your Task Calendar. Replay remains available
   under User Guide.
2. Import the problematic Gradescope and Canvas layouts, including wrapped
   titles, cropped images and overlapping screenshots. Check all titles, numbers,
   real dates, year and timezone. Confirm that Released/Submitted/header text is
   not treated as an assignment. Compressed underlined numbers can still require
   correction. Choose your section when a course lists multiple sections. Missing
   course names must not prevent saving an uncategorized task.
3. On iPhone/iPad, take a photo of a laptop screen. Check the framing overlay,
   retake/crop, multi-page import and cancellation. Verify the result before save.
4. Save a local task; edit, complete and reopen it. Clear Import must leave saved
   tasks intact. Confirm course colours and their legend, narrow layouts, larger
   text and keyboard/VoiceOver navigation.
5. Use the same Apple account on Mac and iPhone. Save/edit a disposable local
   task and confirm it appears on the other device. Test offline changes and
   reconnection. Background iCloud sync can take time. Each device has separate
   notification permission and Google authorization. Do not switch Apple accounts
   or erase personal data just to complete this check.
6. In Settings, allow ReminderSnap notifications and use the five-second test.
   Test a real future task, then completion/deletion cancellation. Check custom
   lead times and date-only morning scheduling. Focus and system settings affect
   delivery. The nearest 60 alerts are scheduled; open the app regularly.
7. Connect Apple apps only if desired. Select dedicated test destinations and
   export a future task, verifying the real reminder deadline and companion block.
   Edit/retry it and check for duplicates. Updates to Apple-linked entries run on
   the original exporting device. External edits are not imported automatically.
8. Google sign-in is now enabled for external users; app-name branding verification
   is pending. Connect in Settings and grant the requested app-created-calendar
   access. Export one labelled test item, open it in Google, edit and retry it,
   then relaunch and confirm the connection restores. Verify an event is updated
   rather than duplicated. Existing unrelated calendars must remain untouched.
9. Select several disposable saved tasks and remove their linked planning blocks,
   keeping the tasks. Separately test deleting assignments with and without linked
   items. Google disconnect removes authorization on that device; it does not
   automatically delete exported events or revoke the Google account grant.

Report the build, device/OS, workflow, expected result and actual result. Mark any
untested item explicitly. Public App Review submission requires completed device
acceptance, Google launch configuration and refreshed store/privacy information.

## Checks performed on October 25

The owner completed native Google consent. On Mac, the connection survived an
app relaunch. A labelled test task exported to the dedicated calendar with a
22:00–23:00 block and its actual 23:59 deadline in the description. A linked edit
updated the same event (same task marker), with one event remaining. The corrected
destination link opened the personal connected account despite the browser's
default school account. The guide's external-test confirmation was visible after
moving its presentation onto the guide sheet. These checks do not establish
physical iPhone/iPad camera, notification or multi-device sync acceptance.

The real-task selection controls now expose Remove linked blocks. On the labelled
Google test, removing the block preserved the saved assignment. A Google 412
version conflict initially left the operation pending; fresh uncached reads,
version-checked deletion and bounded retries completed it. The app then reported
zero pending updates and Google Calendar showed no event on that day. The retained
DEMO 101 test assignment has notifications disabled and can be inspected locally.

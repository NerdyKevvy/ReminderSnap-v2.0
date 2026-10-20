# ReminderSnap Support

ReminderSnap turns screenshots and PDFs into reviewed Apple Reminders and optional Calendar blocks on Mac, iPhone and iPad. Recognition runs on your device with Apple Vision.

## Get help

[Report a problem or ask a question](https://github.com/NerdyKevvy/ReminderSnap-v2.0/issues/new).

Include your ReminderSnap version, device model, operating-system version, what you expected and what happened. If an example is useful, use a synthetic image or redact personal information first. GitHub issues are public; never post passwords, private assignment files, calendar contents or other personal information. No files are automatically attached.

## Getting started

1. Follow the first-launch pop-up guide, or open User Guide, and connect Reminders, Calendar, or both.
2. Choose a writable reminder list/calendar, or expand the creation option and choose a name and account.
3. After allowing or changing permissions, finish setup and quit/reopen ReminderSnap once before importing real tasks. On Mac use ReminderSnap → Quit ReminderSnap (⌘Q), not just the window's close button. On iPhone/iPad close it from the app switcher and reopen. Do not restart the device. Unsaved review items are not retained after quitting; saved Apple entries remain unchanged.
4. In Add Reminder, import screenshots or PDFs together. Review titles, courses, deadlines, timezone and alerts.
5. Select the tasks to save. Choose Add Selected. Clear All clears the review only, leaving saved Apple entries and original files intact.

No app login, paid subscription or school website credentials are required. Import and review also work before granting Apple app permissions. The safe sample never saves to your real lists or calendars.

## Common questions

- **Permission denied or destinations missing:** check ReminderSnap in System Settings / Settings → Privacy & Security → Reminders and Calendars, then return to User Guide and refresh. Verify the selected account is configured in Apple's apps.
- **Calendar is allowed in Settings but still looks disconnected:** quit and reopen ReminderSnap once, then use Check again in User Guide. The app refreshes access automatically, but Apple's permission/session state may lag on some systems. A successful request can show Approved · reopen app while confirmation is pending; that does not bypass the full-access requirement for saving.
- **The guide did not appear after an older TestFlight install:** build 20004 introduces a revised guide-completion marker, so it appears once even if an older guide was marked complete. You can always reopen it from User Guide → Replay first-launch guide.
- **I cannot see reminders in Calendar:** Apple's native scheduled-reminder display requires macOS 15 / iOS 18 or later and must be enabled in Calendar. Check account synchronization settings. ReminderSnap's optional Calendar companion blocks are separate events and work independently.
- **Late-night deadline:** a 23:59 reminder keeps its real deadline. Its optional Calendar block runs from 22:00 to 23:00 on that day. Hide the dedicated calendar in Apple Calendar whenever you do not want to see the blocks.
- **Notifications:** deadline notifications belong to Apple Reminders; extra alerts belong to the Calendar blocks. Check notifications for Apple's apps, Focus, sound and device settings. Keep a future due time when testing.
- **Recognition needs review:** use a sharp image with a little margin around the task title and deadline, include the course context, and import overlapping screenshots together. Always review the output before saving.
- **Clear All:** clears temporary review data; it does not delete saved reminders, Calendar blocks or source files. Manage saved entries in Apple's apps.

Requirements: macOS 13 or later; iOS/iPadOS 17 or later. Both Apple Silicon and Intel Mac builds are supported.

[Privacy Policy](PRIVACY-POLICY.md)

---

# ReminderSnap 支持

ReminderSnap 在 Mac、iPhone 和 iPad 上将截图和 PDF 转为可核对的 Apple 提醒事项及可选日历时间块，使用 Apple Vision 在设备本地识别。

[报告问题或提问](https://github.com/NerdyKevvy/ReminderSnap-v2.0/issues/new)。请说明应用版本、设备型号、系统版本及操作过程。GitHub 问题是公开的，请使用虚构或已遮挡私人信息的示例，不要发布密码、私人作业、日历内容等个人信息。

首次启动会弹出使用引导，也可以在「使用指南」中重新打开。连接提醒事项或日历并选择或创建保存位置后，请退出并重新打开 ReminderSnap 一次，再导入真实任务。Mac 上使用 ⌘Q（仅关闭窗口不算重启）；iPhone/iPad 上从 App 切换器关闭后重开。无需重启设备。退出不会保留尚未保存的核对列表，但已保存的 Apple 条目不受影响。

然后在「添加提醒」中导入文件、核对任务并保存所选条目。安全示例不会创建真实任务。无需应用账户、订阅或学校网站密码。构建版本 20004 会向已完成旧版引导的用户再次显示修订后的引导，完成后不再自动重复。

若缺少权限，请检查系统「隐私与安全性」中的提醒事项和日历权限，再返回使用指南刷新。日历原生显示计划提醒事项需 macOS 15 / iOS 18 或更新系统，并在日历中启用；可选日历时间块独立工作。23:59 截止的提醒事项保留真实时间，对应时间块为当天 22:00–23:00，可在日历中隐藏专用日历。通知受系统通知与专注模式设置影响。

若系统设置已允许日历访问，但应用仍显示未连接，请退出并重新打开一次，然后点击「重新检查」。成功的授权回调与系统确认的权限状态可能暂时不同，此时可显示「已批准 · 请重开应用」；系统确认完整访问权限前仍无法保存。

「清空全部」仅清空当前核对数据，不会删除原始文件或已保存的提醒事项与日历事件。识别不清晰时，请保留标题和日期周围的一点边距，并补充课程信息；保存前始终核对结果。

系统要求：macOS 13 或更新版本；iOS/iPadOS 17 或更新版本。

[隐私政策](PRIVACY-POLICY.md)

# ReminderSnap Privacy Policy

Updated October 22, 2026. The additional planner, iCloud, camera, Google and app-notification sections apply to version 2.1 beta and later. Version 2.0 does not contain those features.

Developer: Junhan Li (NerdyKevvy). This policy covers ReminderSnap for macOS, iPhone and iPad.

ReminderSnap reads assignment screenshots, photos and PDFs locally with Apple's Vision framework or embedded PDF text. It does not upload original images, PDFs, raw OCR text, source filenames or calendar contents to the developer or an AI service. The app contains no advertising, analytics SDK, tracking or developer-operated account/server system. No school-account credentials are requested. Camera access is requested only when you choose Take Photo.

## Your assignment center and private iCloud (2.1+)

Confirmed assignment titles, real deadlines/timezones, course and section preferences, completion state, notification settings, and identifiers needed for linked calendar updates are stored in the local database. When iCloud is available, these structured records are mirrored through your private CloudKit database to devices using the same Apple account. This uses your iCloud storage allowance; offline changes remain local and may sync later. The developer cannot read your production private database. Images, PDFs, raw OCR and source filenames are not synced. Different Apple accounts use separate local partitions. Local-only assignments are copied into a signed-in account only when you choose to do so.

## Apple Reminders and Calendar

With your permission, ReminderSnap reads available lists, calendars and existing entries to let you select destinations and avoid duplicates. It writes tasks only when you select and save them. Creating a named list or calendar is a separate explicit action. Any synchronization is handled by Apple and the account provider you selected, under their policies.

Edits made in ReminderSnap 2.1 can update app-owned linked entries; edits made in other calendar apps are not automatically imported. Apple-linked updates may wait for the original exporting device.

## Optional Google Calendar (2.1+)

Google authorization appears only when you choose Connect and opens the secure system browser using OAuth with PKCE. The requested scopes are `openid`, `userinfo.email` and `calendar.app.created`: account ID/email to identify the connection, and access to secondary calendars created by ReminderSnap. Gmail, school credentials and unrelated existing calendars are not requested. Your email is displayed on this device only. Google account IDs and calendar/event identifiers are retained with links, including in private iCloud, to avoid exporting to the wrong account.

When you choose the Google workflow, selected task titles, deadlines, planning-block times and configured alerts are sent directly from your device to Google Calendar. Google processes the connection, network information and exported data under its policies. No Google analytics or advertising SDK is included. Access/refresh tokens remain in this device’s non-synchronizing Keychain, not CloudKit or a developer server. Disconnect clears this device’s stored authorization; it does not delete existing Google events or revoke the grant in your Google account. Revoke the grant in your Google account’s third-party connections settings when desired.

ReminderSnap’s use and transfer of information received from Google APIs will adhere to the Google API Services User Data Policy, including its Limited Use requirements. Google user data is used only for visible calendar-connection features, never sold or used for advertising, profiling or AI training.

## Local storage and control

Recognition text and review tasks are held in memory. The raw recognition document is cleared after successful saving; review tasks stay visible until you clear them, replace the import, or quit. Temporary camera/Photos-picker copies are removed after reading or cancellation. Preferences and linked-entry management information remain locally. Clear Import (called Clear All in 2.0) does not delete source files or saved assignments/Apple entries. Version 2.1 lets you delete saved assignments separately, choose whether to delete app-owned linked items, or remove linked planning blocks while keeping assignments. Minimal deletion markers remain to prevent old offline copies restoring deleted tasks; pending linked deletion retains the identifiers needed to finish cleanup. Deleting the app or revoking permission does not delete entries already stored by Apple/Google. Device/account backups and retention are controlled by your providers and device settings.

## Notifications (2.1+)

Visible assignment notifications are scheduled locally only with your permission. Apple’s notification service may deliver silent iCloud sync signals; no device push token is sent to the developer. System limits, Focus, device permissions and background delivery can affect timing. Notification taps open the corresponding saved task.

## Support

Support: https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/SUPPORT.md

If you contact us through https://github.com/NerdyKevvy/ReminderSnap-v2.0/issues, the information you choose to provide is handled by GitHub and used to respond to your request, including privacy questions. Public issues are public: do not include private screenshots, credentials or personal assignments. The app does not automatically attach your files to support requests. Apple may separately process store, purchase or diagnostic information under its own policies and your device settings.

## Changes

The published policy will be updated if the app's data practices change. The effective date will identify the latest revision.

---

# ReminderSnap 隐私政策

更新日期：2026 年 10 月 22 日。新增作业日历、iCloud、相机、Google 和应用通知条款适用于 2.1 测试版及后续版本；2.0 不包含这些功能。

开发者：Junhan Li（NerdyKevvy）。本政策适用于 macOS、iPhone 和 iPad 版 ReminderSnap。

ReminderSnap 使用 Apple Vision 或 PDF 内嵌文本在设备本地读取截图、照片和 PDF，不会将原始图像、PDF、原始识别文本、源文件名或日历内容上传给开发者或 AI 服务。应用不包含广告、分析 SDK、追踪、开发者服务器或开发者账户系统，不索取学校账户凭据。仅在选择「拍照」时请求相机权限。

## 作业中心与私人 iCloud（2.1 起）

已确认的作业标题、真实截止日期与时区、课程及班级偏好、完成状态、通知设置和关联更新所需标识符保存在本机数据库。iCloud 可用时，这些结构化记录会通过私人 CloudKit 数据库同步至使用同一 Apple 账户的设备，占用你的 iCloud 存储配额。离线修改保留在本机，稍后可能同步。开发者无法读取你的生产环境私人数据库。图片、PDF、原始识别文本和源文件名不会同步。不同 Apple 账户使用独立本机存储分区；仅在你选择时，才将本机独立作业复制到已登录账户。

## 可选 Apple 连接

经过你的授权，应用读取可用的列表、日历和已有条目，以选择保存位置并避免重复。只有你选择并保存的任务才会写入，创建列表或日历需单独操作。同步由 Apple 及你选择的账户服务商处理，并适用其隐私政策。

2.1 中的修改可更新本应用拥有的关联条目，外部日历中的修改不会自动导入。Apple 关联更新可能需要等待最初导出的设备。

## 可选 Google 日历（2.1 起）

仅在选择连接时，通过安全系统浏览器进行 OAuth/PKCE 授权。请求范围为 `openid`、`userinfo.email` 和 `calendar.app.created`：用账户标识与邮箱识别连接，并访问 ReminderSnap 创建的辅助日历。不请求 Gmail、学校凭据或无关现有日历。邮箱仅在本机显示；Google 账户标识与日历、日程标识符会随关联信息保留，包括私人 iCloud 中的关联信息，以避免导出至错误账户。

选择 Google 工作流后，所选任务标题、截止日期、计划块时间和通知设置由设备直接发送给 Google 日历。Google 按其政策处理连接、网络信息与导出数据。应用不包含 Google 分析或广告 SDK。访问及刷新令牌仅保存在本机不参与同步的钥匙串，不发送至 CloudKit 或开发者服务器。「断开连接」清除本机授权，不会删除 Google 中的现有日程或撤销 Google 账户中的授权；可在 Google 账户的第三方连接设置中撤销授权。

ReminderSnap 使用和传输 Google API 信息时遵守 Google API 服务用户数据政策及有限使用要求，仅用于明确可见的日历连接功能，不出售，不用于广告、用户画像或 AI 训练。

## 本地数据与删除

识别文本和待核对任务保留在内存中，成功保存后清除原始识别文档；核对列表保留至清空、替换导入或退出。相机和照片的临时副本在读取或取消后移除。偏好和关联管理信息保存在本机。「清空导入」（2.0 中称「清空全部」）不删除源文件或已保存作业、Apple 条目。2.1 可单独删除已保存作业、选择是否删除本应用创建的关联条目，也可移除计划块而保留作业。为防止离线旧副本恢复已删除任务，会保留最小删除标记；待完成的关联删除会保留必要标识符。删除应用或撤销权限不会自动删除 Apple/Google 中已有的条目。备份与账户保留由服务商及设备设置控制。

## 通知（2.1 起）

仅在授权后在本机安排可见作业通知。Apple 通知服务可能发送静默 iCloud 同步信号，推送令牌不发送给开发者。系统限制、专注模式、设备权限和后台送达会影响通知时间。点击通知会打开对应作业。

## 支持与变更

支持页面：https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/SUPPORT.md

如通过 https://github.com/NerdyKevvy/ReminderSnap-v2.0/issues 联系支持或提出隐私问题，你主动提供的信息将由 GitHub 处理并用于答复。公开问题中的内容是公开的，请勿提供私人截图、凭据或个人作业内容。应用不会自动将文件附加到支持请求中。Apple 可能根据其政策及你的设备设置，单独处理商店、购买或诊断信息。

如果应用的数据处理方式发生变化，公开政策将更新，并注明新的生效日期。

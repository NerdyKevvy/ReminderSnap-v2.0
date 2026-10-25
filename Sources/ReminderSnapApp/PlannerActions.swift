import Foundation
import SwiftUI
import Combine
import ReminderSnapCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension AppModel {
    var workflow: PlannerWorkflow {
        get { outputMode == .local ? .inApp : outputMode == .google ? .google : .apple }
        set { outputMode = newValue == .inApp ? .local : newValue == .google ? .google : .both }
    }
    var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "Planner.DeviceID") { return id }
        let id = UUID().uuidString; UserDefaults.standard.set(id, forKey: "Planner.DeviceID"); return id
    }
    var savedAssignments: [SavedAssignment] { planner.tasks.filter { !$0.isDeleted } }
    var calendarAssignments: [SavedAssignment] {
        if showSampleCalendar {
            return items.map { SavedAssignment(candidate: $0.candidate, isSample: true) }
        }
        return savedAssignments
    }
    var visibleImportItems: [ImportItem] {
        items.filter { item in
            let profile = planner.courses.first { $0.id == item.candidate.courseTag }
            let isSubmitted = item.candidate.submissionStatus?.lowercased() == "submitted" ||
                item.candidate.submissionStatus?.contains("/") == true
            return (showOtherSections || SectionSelection.matches(item.candidate, profile: profile)) &&
                (includeSubmitted || !isSubmitted)
        }
    }

    func configurePlanner() {
        planner.onChange = { [weak self] in
            guard let self else { return }
            self.objectWillChange.send(); self.refreshPlannerAlerts()
            if let id = self.pendingNotificationTaskID,
               let task = self.savedAssignments.first(where: { $0.id == id }) {
                self.pendingNotificationTaskID = nil; self.selectedSavedTask = task
                if let date = task.candidate.dueDate { self.calendarDate = date }
            }
        }
        for publisher in [planner.objectWillChange.eraseToAnyPublisher(), notifications.objectWillChange.eraseToAnyPublisher(), googleCalendar.objectWillChange.eraseToAnyPublisher()] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &plannerObservers)
        }
        notifications.openTask = { [weak self] id in
            guard let self else { return }
            self.page = .calendar; self.showSampleCalendar = false
            if let task = self.savedAssignments.first(where: { $0.id == id }) {
                self.selectedSavedTask = task
                if let date = task.candidate.dueDate { self.calendarDate = date }
            } else { self.pendingNotificationTaskID = id }
        }
        Task {
            await planner.open(); await notifications.refresh()
            await googleCalendar.restore()
            refreshPlannerAlerts()
        }
    }

    func refreshPlannerAlerts() {
        Task { await notifications.schedule(tasks: planner.tasks, enabled: plannerNotificationsEnabled,
                                             chinese: language == .simplifiedChinese) }
    }
    func enableAppNotifications() {
        Task {
            await notifications.request()
            plannerNotificationsEnabled = notifications.authorized
            refreshPlannerAlerts()
        }
    }
    func saveReviewedAssignments() {
        guard !isProcessing, !isDemo else { return }
        let selected = visibleImportItems.filter(\.isSelected)
        guard !selected.isEmpty else { showingMissingDetails = true; return }
        guard selected.allSatisfy({ $0.candidate.dueDate != nil && !$0.candidate.assignmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            showingMissingDetails = true; return
        }
        guard planner.ready else { statusMessage = "Wait for the assignment calendar to finish opening."; return }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                for item in selected {
                    var task = SavedAssignment(candidate: item.candidate, workflow: workflow,
                        alertsEnabled: item.appAlertsEnabled, alertLeadTimes: item.appAlertLeadTimes, exportOwner: deviceID)
                    task.dateOnlyAlertHour = dateOnlyAlertHour
                    task.appleReminders = outputMode.usesReminders
                    task.appleCalendar = outputMode.usesCalendar
                    task.companionBlock = item.companionEventEnabled
                    if let existing = planner.tasks.first(where: { $0.id == task.id }) {
                        task.createdAt = existing.createdAt
                        task.isCompleted = existing.isCompleted
                        task.exportOwner = existing.exportOwner
                        task.googleCalendarID = existing.googleCalendarID
                        task.googleEventID = existing.googleEventID
                        task.googleEventURL = existing.googleEventURL
                        task.googleAccountID = existing.googleAccountID
                    }
                    try planner.save(task)
                    ensureCourse(item.candidate.courseCode)
                }
                showSampleCalendar = false; saveCompleted = true; documents = []
                statusMessage = LocalizedMessage(verbatim: copy("Saved to your assignment calendar. External updates run only for your selected workflow.", "已保存到作业日历，仅更新你选择的外部工作流。"))
                page = .calendar
                if let date = selected.first?.candidate.dueDate { calendarDate = date }
                refreshPlannerAlerts()
                await flushPendingExports()
            } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
        }
    }

    func ensureCourse(_ course: String) {
        guard !course.isEmpty, !planner.courses.contains(where: { $0.id == CourseNormalizer.tag(from: course) }) else { return }
        do { try planner.save(CourseProfile(name: course, colorIndex: planner.courses.count % 8)) }
        catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
    }
    func saveProfile(_ profile: CourseProfile) {
        var profile = profile; profile.modifiedAt = Date()
        do {
            try planner.save(profile)
            for index in items.indices where items[index].candidate.courseTag == profile.id {
                items[index].isSelected = items[index].candidate.dueDate != nil && SectionSelection.matches(items[index].candidate, profile: profile)
            }
        } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
    }
    func applyBatchDetails() {
        rereadText()
        for course in Set(items.map(\.candidate.courseCode)).filter({ !$0.isEmpty }) {
            let tag = CourseNormalizer.tag(from: course)
            var profile = planner.courses.first { $0.id == tag } ?? CourseProfile(name: course, colorIndex: planner.courses.count % 8)
            if let year = Int(batchYear) { profile.year = year }
            if !batchTimeZone.isEmpty { profile.timeZoneIdentifier = batchTimeZone }
            else if let zone = items.first(where: { $0.candidate.courseCode == course })?.candidate.timeZoneIdentifier { profile.timeZoneIdentifier = zone }
            saveProfile(profile)
        }
    }
    @discardableResult
    func updateSavedAssignment(_ task: SavedAssignment) -> Bool {
        guard let current = planner.tasks.first(where: { $0.id == task.id }), !current.isDeleted,
              current.modifiedAt == task.modifiedAt else {
            statusMessage = LocalizedMessage(verbatim: copy("This assignment changed on another device. Reload its saved version before editing again.", "这项作业已在其他设备修改，请重新加载已保存版本后再编辑。"))
            return false
        }
        var task = task; task.modifiedAt = Date(); task.exportError = nil
        do {
            try planner.save(task); ensureCourse(task.candidate.courseCode)
            refreshPlannerAlerts()
            Task { await flushPendingExports() }
            return true
        } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription); return false }
    }
    func completeAssignment(_ task: SavedAssignment) {
        var task = task; task.isCompleted.toggle(); updateSavedAssignment(task)
    }
    func deleteAssignments(_ ids: Set<UUID>, linked: Bool) {
        do {
            for var task in savedAssignments where ids.contains(task.id) {
                task.isDeleted = true; task.deleteLinkedItems = linked; task.modifiedAt = Date()
                if !linked { task.exportedAt = Date() }
                task.eraseDeletedContent()
                try planner.save(task)
            }
            refreshPlannerAlerts(); Task { await flushPendingExports() }
        } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
    }

    func flushPendingExports() async {
        guard !isExporting, planner.ready else { return }
        isExporting = true; defer { isExporting = false }
        for var task in planner.tasks where task.needsExport && !task.isSample {
            let revision = task.modifiedAt
            // Apple item identifiers are device-local. A remote edit is queued
            // for its original exporting device, never recreated on every Mac.
            if task.workflow == .apple && task.exportOwner != deviceID { continue }
            do {
                if task.workflow == .apple {
                    if task.removeCalendarBlockRequested == true {
                        try appleExporter.deleteCalendarBlock(task)
                        task.appleCalendar = false; task.removeCalendarBlockRequested = false
                    } else if task.isDeleted {
                        if task.deleteLinkedItems == true { try appleExporter.delete(task) }
                    } else {
                        try await appleExporter.save(task, listID: selectedListID, calendarID: selectedCalendarID,
                                                     externalAlerts: !plannerNotificationsEnabled && task.alertsEnabled && task.isTestItem != true)
                    }
                } else if task.workflow == .google {
                    guard googleCalendar.connected else { continue }
                    if let account = task.googleAccountID, account != googleCalendar.accountID { continue }
                    if task.removeCalendarBlockRequested == true {
                        try await googleCalendar.delete(task)
                        task.workflow = .inApp; task.removeCalendarBlockRequested = false
                        task.googleEventID = nil; task.googleEventURL = nil
                    } else if task.isDeleted {
                        if task.deleteLinkedItems == true { try await googleCalendar.delete(task) }
                    } else {
                        var calendarID = task.googleCalendarID ?? planner.googleCalendars[googleCalendar.accountID]
                        if calendarID == nil {
                            calendarID = try await googleCalendar.createCalendar()
                            try planner.saveGoogleCalendar(calendarID!, account: googleCalendar.accountID)
                        }
                        task.googleCalendarID = calendarID; task.googleAccountID = googleCalendar.accountID
                        // Persist the destination before making an event. A
                        // network retry uses the same stable event identifier.
                        guard planner.tasks.first(where: { $0.id == task.id })?.modifiedAt == revision else { continue }
                        try planner.save(task)
                        let result = try await googleCalendar.save(task, calendarID: calendarID!, externalAlerts: !plannerNotificationsEnabled && task.alertsEnabled && task.isTestItem != true)
                        task.googleEventID = result.id; task.googleEventURL = result.url
                    }
                }
                guard let current = planner.tasks.first(where: { $0.id == task.id }) else { continue }
                if current.modifiedAt != revision {
                    // Preserve edits/completion/deletion made while a network
                    // request was in flight; merge only returned link metadata.
                    var newer = current
                    newer.googleCalendarID = task.googleCalendarID ?? newer.googleCalendarID
                    newer.googleAccountID = task.googleAccountID ?? newer.googleAccountID
                    newer.googleEventID = task.googleEventID ?? newer.googleEventID
                    newer.googleEventURL = task.googleEventURL ?? newer.googleEventURL
                    try planner.save(newer); continue
                }
                task.exportedAt = Date(); task.exportError = nil; task.eraseDeletedContent(); try planner.save(task)
            } catch {
                if var current = planner.tasks.first(where: { $0.id == task.id }), current.modifiedAt == revision {
                    current.exportError = error.localizedDescription; try? planner.save(current)
                }
                statusMessage = LocalizedMessage(verbatim: error.localizedDescription)
            }
        }
    }

    func removeLinkedCalendarBlocks(_ ids: Set<UUID>) {
        for var task in savedAssignments where ids.contains(task.id) && task.workflow != .inApp {
            task.removeCalendarBlockRequested = true; task.modifiedAt = Date(); task.exportError = nil
            do { try planner.save(task) } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
        }
        Task { await flushPendingExports() }
    }

    func removeTestAssignments() {
        deleteAssignments(Set(savedAssignments.filter { $0.isTestItem == true }.map(\.id)), linked: true)
    }

    /// An explicit refresh also reapplies device-local notification preferences
    /// to links that were previously exported successfully. Never claim another
    /// device's Apple links or update a different connected Google account.
    func refreshLinkedAssignments() {
        do {
            for var task in savedAssignments where !task.isSample {
                let canRefresh = task.workflow == .apple ? task.exportOwner == deviceID :
                    task.workflow == .google && googleCalendar.connected &&
                    (task.googleAccountID == nil || task.googleAccountID == googleCalendar.accountID)
                guard canRefresh else { continue }
                task.modifiedAt = Date(); task.exportError = nil
                try planner.save(task)
            }
            Task { await flushPendingExports() }
        } catch { statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
    }

    func connectGoogle() {
        Task { await googleCalendar.connect(); if googleCalendar.connected { await flushPendingExports() } }
    }
    func openDestination(_ task: SavedAssignment) {
        if task.workflow == .google {
            guard googleCalendar.connected, task.googleAccountID == googleCalendar.accountID else {
                workflowNotice = copy("Connect the Google account linked to this assignment in Settings, then open it again.", "请先在设置中连接此作业关联的 Google 账户，然后重新打开。")
                return
            }
            guard let text = task.googleEventURL,
                  let url = GoogleCalendarEventLink.url(text, email: googleCalendar.email) else {
                workflowNotice = copy("This assignment is saved here. Retry its linked update in Settings before opening Google Calendar.", "作业已保存在本应用，请先在设置中重试关联更新，再打开 Google 日历。")
                return
            }
            openURL(url); return
        }
        if task.workflow == .apple {
            #if os(macOS)
            openAppleApp(task.appleCalendar ? "com.apple.iCal" : "com.apple.reminders")
            #else
            if task.appleCalendar, let id = appleExporter.eventIdentifier(for: task) {
                selectedSavedTask = nil; showingSetup = false
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(350))
                    selectedAppleEvent = LinkedAppleEventReference(id: id, taskID: task.id)
                }
            } else {
                workflowNotice = task.appleCalendar ? copy("Your assignment is saved. This device has not resolved the linked event yet; check Calendar sync or open it on the original exporting device.", "作业已保存，本设备尚未找到关联日程。请检查日历同步，或在最初导出设备查看。") : copy("Your task is saved in the selected Reminders list. Open Apple Reminders to view it there; iOS does not provide a supported link to a specific reminder.", "任务已保存在所选提醒事项列表，请打开 Apple 提醒事项查看。iOS 未提供直接打开特定提醒事项的公开链接。")
            }
            #endif
            return
        }
        page = .calendar; selectedSavedTask = task
    }
    func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
    func trySelectedWorkflow() {
        if workflow == .inApp {
            finishSetup(); showSample(); showSampleCalendar = true; page = .calendar
        } else { showingExternalSampleConfirmation = true }
    }
    func createExternalSample() {
        guard planner.ready else { return }
        showingExternalSampleConfirmation = false
        Task {
            do {
                var candidate = AssignmentCandidate(courseCode: "DEMO 101", assignmentName: copy("ReminderSnap test · safe to delete", "ReminderSnap 测试 · 可删除"),
                    dueDate: Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()), hasExplicitTime: true,
                    timeZoneIdentifier: TimeZone.current.identifier, sourcePlatform: .unknown, sourceImages: [])
                if candidate.dueDate! < Date() { candidate.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: candidate.dueDate!) }
                var task = SavedAssignment(candidate: candidate, workflow: workflow, alertsEnabled: false, exportOwner: deviceID)
                task.isTestItem = true
                task.appleCalendar = outputMode.usesCalendar; task.appleReminders = outputMode.usesReminders
                try planner.save(task); await flushPendingExports()
                if let saved = planner.tasks.first(where: { $0.id == task.id }), saved.exportedAt != nil {
                    finishSetup(); openDestination(saved)
                } else {
                    setupMessage = LocalizedMessage(verbatim: copy("Test task saved in ReminderSnap. Connect the selected calendar, then Retry linked updates in Settings.", "测试任务已保存在 ReminderSnap，请连接所选日历后在设置中重试关联更新。"))
                }
            } catch { setupMessage = LocalizedMessage(verbatim: error.localizedDescription) }
        }
    }
}

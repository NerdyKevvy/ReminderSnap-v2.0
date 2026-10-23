import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers
import Combine
import EventKit
import ReminderSnapCore

enum OutputMode: String, CaseIterable, Identifiable {
    case local = "ReminderSnap only"
    case google = "Google Calendar"
    case reminders = "Reminders only"
    case calendar = "Calendar only"
    case both = "Reminders + Calendar"
    var id: String { rawValue }
    var usesReminders: Bool { self == .reminders || self == .both }
    var usesCalendar: Bool { self == .calendar || self == .both }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var items: [ImportItem] = []
    @Published var isProcessing = false {
        didSet { if oldValue && !isProcessing && accessRefreshPending { requestAccessRefresh(reconnect: true) } }
    }
    @Published var isSettingUp = false
    @Published var statusMessage: LocalizedMessage = ""
    @Published var documents: [OCRDocument] = []
    @Published var readingSummary: LocalizedMessage = ""
    @Published var isDemo = false
    @Published var showingCalendarHelp = false
    @Published var showingImporter = false
    @Published var page: StudioPage = .calendar
    let planner = PlannerStore()
    let notifications = PlannerNotifications()
    let googleCalendar = GoogleCalendarConnection()
    let appleExporter = AppleTaskExporter()
    @Published var selectedSavedTask: SavedAssignment?
    @Published var selectedAppleEvent: LinkedAppleEventReference?
    @Published var workflowNotice = ""
    @Published var showingMissingDetails = false
    @Published var showingCamera = false
    @Published var calendarDate = Date()
    @Published var showSampleCalendar = false
    @Published var showingExternalSampleConfirmation = false
    @Published var plannerNotificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "Planner.NotificationsEnabled") {
        didSet { UserDefaults.standard.set(plannerNotificationsEnabled, forKey: "Planner.NotificationsEnabled"); refreshPlannerAlerts() }
    }
    @Published var appAlertLeadTimes: [TimeInterval] = UserDefaults.standard.array(forKey: "Planner.AlertLeadTimes") as? [Double] ?? [86400, 7200] {
        didSet { UserDefaults.standard.set(appAlertLeadTimes, forKey: "Planner.AlertLeadTimes") }
    }
    @Published var dateOnlyAlertHour = UserDefaults.standard.object(forKey: "Planner.DateOnlyHour") as? Int ?? 9 {
        didSet { UserDefaults.standard.set(dateOnlyAlertHour, forKey: "Planner.DateOnlyHour") }
    }
    @Published var showOtherSections = false
    @Published var includeSubmitted = false
    var isExporting = false
    var pendingNotificationTaskID: UUID?
    var plannerObservers = Set<AnyCancellable>()
    @Published var showingClearConfirmation = false
    @Published var previewSaved = false
    @Published var importedFileCount = 0
    @Published var saveCompleted = false
    // Present only after an active scene is attached; an initially true sheet
    // binding can race the first TestFlight window's presentation lifecycle.
    @Published var showingSetup = false
    @Published private(set) var permissionSetup = PermissionSetupProgress()
    @Published var setupMessage: LocalizedMessage = ""
    @Published var language: AppLanguage = .current {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.preferenceKey) }
    }
    @Published var reminderLists: [DestinationChoice] = []
    @Published var reminderAccounts: [AccountChoice] = []
    @Published var calendars: [DestinationChoice] = []
    @Published var calendarAccounts: [AccountChoice] = []
    @Published var reminderAccess = false
    @Published var calendarAccess = false
    @Published var reminderPermission: PermissionState = .notDetermined
    @Published var calendarPermission: PermissionState = .notDetermined
    @Published var isRefreshingAccess = false
    @Published var selectedListID: String {
        didSet { UserDefaults.standard.set(selectedListID, forKey: "ReminderSnap.SelectedListID") }
    }
    @Published var selectedCalendarID: String {
        didSet { UserDefaults.standard.set(selectedCalendarID, forKey: "ReminderSnap.SelectedCalendarID") }
    }
    @Published var outputMode: OutputMode {
        didSet {
            UserDefaults.standard.set(outputMode.rawValue, forKey: "ReminderSnap.OutputMode")
            defaultCompanionEventsEnabled = outputMode.usesCalendar || outputMode == .google
            UserDefaults.standard.set(defaultCompanionEventsEnabled, forKey: DefaultsKey.companionEventsEnabled)
            for index in items.indices { items[index].companionEventEnabled = defaultCompanionEventsEnabled }
        }
    }
    // Batch context is session-only; never guess a missing year from today's date.
    @Published var batchCourse = ""
    @Published var batchYear = ""
    @Published var batchTimeZone = ""
    @Published private(set) var defaultDeadlineNotificationEnabled: Bool
    @Published private(set) var defaultCompanionEventsEnabled: Bool
    @Published private(set) var defaultCompanionEventStartAlertEnabled: Bool
    @Published private(set) var defaultCompanionEventAdditionalLeadTimes: [TimeInterval]

    let reminderService = RemindersService()
    let calendarEventService = CalendarEventService()
    private var matches: [UUID: ReminderMatch] = [:]
    private var activeImport: Task<Void, Never>?
    private var importID = UUID()
    private let defaults = UserDefaults.standard
    private var storeObserver: AnyCancellable?
    private var accessRefreshPending = false
    private var accessRefreshObservation: Task<Void, Never>?
    private let setupGuide = SetupGuideProgress()
    private var didPresentGuideThisSession = false
    private var photoDirectory: URL?
    private lazy var accessRefresh = PermissionRefreshLoop { [weak self] reconnect in
        guard let self, !self.isProcessing, !self.isSettingUp else {
            self?.accessRefreshPending = true
            return false
        }
        self.accessRefreshPending = false
        self.refreshDestinations(reconnect: reconnect)
        return true
    }
    private enum DefaultsKey {
        static let deadlineNotificationEnabled = "ReminderSnap.DefaultDeadlineNotificationEnabled.v2"
        static let companionEventsEnabled = "ReminderSnap.DefaultCompanionEventsEnabled.v3"
        static let companionEventStartAlertEnabled = "ReminderSnap.DefaultCompanionStartAlertEnabled.v3"
        static let companionEventAdditionalLeadTimes = "ReminderSnap.DefaultCompanionAdditionalLeadTimes.v3"
    }

    init() {
        let defaults = UserDefaults.standard
        selectedListID = defaults.string(forKey: "ReminderSnap.SelectedListID") ?? ""
        selectedCalendarID = defaults.string(forKey: "ReminderSnap.SelectedCalendarID") ?? ""
        defaultDeadlineNotificationEnabled = defaults.object(forKey: DefaultsKey.deadlineNotificationEnabled) == nil ? true : defaults.bool(forKey: DefaultsKey.deadlineNotificationEnabled)
        defaultCompanionEventsEnabled = defaults.object(forKey: DefaultsKey.companionEventsEnabled) == nil ? true : defaults.bool(forKey: DefaultsKey.companionEventsEnabled)
        defaultCompanionEventStartAlertEnabled = defaults.object(forKey: DefaultsKey.companionEventStartAlertEnabled) == nil ? true : defaults.bool(forKey: DefaultsKey.companionEventStartAlertEnabled)
        defaultCompanionEventAdditionalLeadTimes = Self.normalizedCalendarLeadTimes(defaults.array(forKey: DefaultsKey.companionEventAdditionalLeadTimes) as? [Double] ?? [86_400])
        outputMode = defaults.string(forKey: "ReminderSnap.OutputMode").flatMap(OutputMode.init(rawValue:)) ?? .local
        refreshDestinations()
        storeObserver = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.requestAccessRefresh() }
        configurePlanner()
    }

    func t(_ key: String, _ arguments: String...) -> String { Localizer.text(key, language: language, arguments: arguments) }
    func t(_ message: LocalizedMessage) -> String { message.rendered(in: language) }
    func copy(_ english: String, _ chinese: String) -> String { language == .english ? english : chinese }
    var selectedCount: Int { visibleImportItems.filter(\.isSelected).count }
    var reviewCount: Int { items.filter { !$0.candidate.warnings.isEmpty || $0.candidate.dueDate == nil || $0.candidate.courseCode.isEmpty }.count }
    var targetListName: String { reminderLists.first { $0.id == selectedListID }?.name ?? "Choose a list" }
    var canCancelImport: Bool { activeImport != nil }
    var canClearImport: Bool { !isProcessing && (!items.isEmpty || !documents.isEmpty || importedFileCount > 0) }
    var context: ImportContext {
        ImportContext(course: batchCourse, year: Int(batchYear), timeZoneIdentifier: batchTimeZone.isEmpty ? nil : batchTimeZone)
    }
    var destinationNeedsRepair: Bool {
        (outputMode.usesReminders && (!reminderAccess || !reminderLists.contains { $0.id == selectedListID })) ||
        (outputMode.usesCalendar && (!calendarAccess || !calendars.contains { $0.id == selectedCalendarID }))
    }

    func refreshDestinations(reconnect: Bool = false) {
        guard !isProcessing else { accessRefreshPending = true; return }
        reminderService.refreshAccess(reconnect: reconnect)
        calendarEventService.refreshAccess(reconnect: reconnect)
        reminderPermission = reminderService.permissionState
        calendarPermission = calendarEventService.permissionState
        permissionSetup.observe(reminders: reminderPermission, calendar: calendarPermission)
        reminderAccess = reminderService.hasAccess
        calendarAccess = calendarEventService.hasAccess
        reminderLists = reminderService.lists(); reminderAccounts = reminderService.accounts()
        calendars = calendarEventService.calendars(); calendarAccounts = calendarEventService.accounts()
        if selectedListID.isEmpty {
            selectedListID = (reminderLists.first { $0.name == "NYU" } ?? reminderLists.first)?.id ?? ""
        }
        if selectedCalendarID.isEmpty {
            selectedCalendarID = calendars.first { $0.name == CalendarEventService.defaultCalendarName }?.id ?? ""
        }
    }

    func requestAccessRefresh(reconnect: Bool = false) {
        if isProcessing || isSettingUp { accessRefreshPending = true; return }
        isRefreshingAccess = true
        accessRefresh.start(reconnect: reconnect)
        accessRefreshObservation?.cancel()
        accessRefreshObservation = Task { [weak self] in
            guard let self else { return }
            await accessRefresh.waitForCompletion()
            guard !Task.isCancelled else { return }
            isRefreshingAccess = false
        }
    }

    func checkAccessAgain() { requestAccessRefresh(reconnect: true) }

    func sceneBecameActive() {
        Task { await planner.open(); await notifications.refresh(); refreshPlannerAlerts(); await flushPendingExports() }
        if setupGuide.needsPresentation && !didPresentGuideThisSession {
            didPresentGuideThisSession = true
            showingSetup = true
        }
        requestAccessRefresh(reconnect: true)
    }

    func connect(reminders: Bool) {
        guard !isSettingUp else { return }
        isSettingUp = true; setupMessage = ""
        Task {
            defer {
                isSettingUp = false
                // Keep the just-authorized store alive for the initial refresh.
                // Manual Check again / scene activation can rebuild it later.
                requestAccessRefresh()
            }
            do {
                if reminders { try await reminderService.requestAccess() }
                else { try await calendarEventService.requestAccess() }
                permissionSetup.recordApproval(reminders: reminders)
                refreshDestinations()
                setupMessage = "Access approved. After setup, quit and reopen ReminderSnap once to finish refreshing Apple app connections."
            } catch { setupMessage = LocalizedMessage(verbatim: error.localizedDescription) }
        }
    }

    func createDestination(name: String, accountID: String, reminders: Bool) {
        guard !isSettingUp else { return }
        isSettingUp = true
        defer { isSettingUp = false }
        do {
            let created = reminders
                ? try reminderService.createList(name: name, sourceID: accountID)
                : try calendarEventService.createCalendar(name: name, sourceID: accountID)
            refreshDestinations()
            if reminders { selectedListID = created.id } else { selectedCalendarID = created.id }
            setupMessage = "“\(created.name)” is ready in \(created.account)."
        } catch { setupMessage = LocalizedMessage(verbatim: error.localizedDescription) }
    }

    func finishSetup() {
        setupGuide.complete()
        showingSetup = false
        page = .calendar
    }

    func destinationChanged() {
        guard !isProcessing, !isDemo else { return }
        for index in items.indices {
            items[index].status = items[index].candidate.warnings.isEmpty ? .ready : .needsReview
            items[index].isSelected = items[index].candidate.dueDate != nil
        }
        Task { await refreshMatches() }
    }

    func openAppleApp(_ bundleID: String) {
        #if os(macOS)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        #else
        if bundleID == "com.apple.systempreferences", let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    func openSettings() { openAppleApp("com.apple.systempreferences") }

    func chooseScreenshots() {
        guard !isProcessing else { return }
        showingImporter = true
    }

    func importScreenshots(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard !isProcessing else { statusMessage = "Please wait for this import, or cancel it before importing more."; return }
        guard urls.count <= 50 else { statusMessage = "Import up to 50 files at a time."; return }
        guard batchYear.isEmpty || Int(batchYear).map({ (1900...2199).contains($0) }) == true else {
            statusMessage = "Enter a four-digit batch year, or leave it blank."; return
        }
        isProcessing = true; isDemo = false
        importedFileCount = urls.count; previewSaved = false; saveCompleted = false
        page = .addReminder
        documents = []; items = []; matches = [:]; readingSummary = ""
        let token = UUID(); importID = token
        let importContext = context
        statusMessage = "Reading \(urls.count) file(s) locally…"
        activeImport = Task.detached(priority: .userInitiated) { [weak self] in
            let started = Date()
            do {
                // At most two files in flight. Each page drains temporary image buffers.
                let results = try await withThrowingTaskGroup(of: (Int, [OCRDocument], String?).self) { group in
                    var next = 0
                    func enqueue(_ index: Int) {
                        group.addTask {
                            try Task.checkCancellation()
                            do {
                                let docs = try OCRService().recognizeAll(url: urls[index]) { label in
                                    Task { @MainActor [weak self] in
                                        guard self?.importID == token, self?.isProcessing == true else { return }
                                        self?.statusMessage = "Reading \(label)…"
                                    }
                                }
                                return (index, docs, nil)
                            } catch is CancellationError { throw CancellationError() }
                            catch { return (index, [], "\(urls[index].lastPathComponent): \(error.localizedDescription)") }
                        }
                    }
                    while next < min(2, urls.count) { enqueue(next); next += 1 }
                    var output: [(Int, [OCRDocument], String?)] = []
                    for try await result in group {
                        output.append(result)
                        if next < urls.count { enqueue(next); next += 1 }
                    }
                    return output.sorted { $0.0 < $1.0 }
                }
                try Task.checkCancellation()
                let docs = results.flatMap(\.1)
                let readTime = Date().timeIntervalSince(started)
                await self?.setImportStatus("Finding titles and deadlines…", token: token)
                let parseStart = Date()
                let candidates = AssignmentParser().parse(documents: docs, context: importContext)
                let parseTime = Date().timeIntervalSince(parseStart)
                try Task.checkCancellation()
                await self?.finishImport(candidates, documents: docs, errors: results.compactMap(\.2), readTime: readTime, parseTime: parseTime, token: token)
            } catch is CancellationError {
                await self?.finishWithError("Import cancelled. Temporary reading data was released.", token: token)
            } catch { await self?.finishWithError(LocalizedMessage(verbatim: error.localizedDescription), token: token) }
        }
    }

    private func setImportStatus(_ message: LocalizedMessage, token: UUID) {
        guard token == importID else { return }; statusMessage = message
    }

    func cancelImport() {
        activeImport?.cancel()
        statusMessage = "Cancelling after the current recognition operation…"
    }

    func importDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard !isProcessing else { return false }
        var urls: [URL] = []
        let group = DispatchGroup(), lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data, let string = String(data: data, encoding: .utf8) { url = URL(string: string) }
                else { url = item as? URL }
                if let url { lock.lock(); urls.append(url); lock.unlock() }
            }
        }
        group.notify(queue: .main) { [weak self] in self?.importScreenshots(urls) }
        return !providers.isEmpty
    }

    func clear() {
        guard !isProcessing else { return }
        importID = UUID() // Invalidate delayed duplicate lookups for the previous review.
        items = []; matches = [:]; documents = []; readingSummary = ""; isDemo = false
        previewSaved = false; saveCompleted = false; importedFileCount = 0
        showingClearConfirmation = false
        cleanPhotoCopies()
        statusMessage = "Review and temporary recognized text cleared. Your saved tasks are unchanged."
    }

    func rereadText() {
        guard !isProcessing, !documents.isEmpty else { return }
        guard batchYear.isEmpty || Int(batchYear).map({ (1900...2199).contains($0) }) == true else {
            statusMessage = "Enter a valid four-digit year."; return
        }
        loadItems(AssignmentParser().parse(documents: documents, context: context))
        statusMessage = "Re-interpreted the existing text with your batch context; no OCR repeated."
    }

    func showSample() {
        guard !isProcessing else { return }
        isDemo = true; documents = []
        previewSaved = false; saveCompleted = false; importedFileCount = 2
        let calendar = Calendar.current
        let names = ["Linear transformations", "Binary search trees", "Vector spaces & subspaces", "Laboratory report"]
        let courses = ["MA-UY 2034", "CS-UY 1134", "MA-UY 2034", "PH-UY 1013"]
        loadItems(names.indices.map { index in
            let day = calendar.date(byAdding: .day, value: index < 2 ? 1 : index + 1, to: Date())!
            let date = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)!
            return AssignmentCandidate(courseCode: courses[index], assignmentName: names[index], assignmentType: index == 3 ? "Lab" : "Homework",
                questionCount: index == 3 ? nil : [22, 8, 21][index], dueDate: date, hasExplicitTime: true,
                timeZoneIdentifier: TimeZone.current.identifier, sourcePlatform: index == 1 ? .brightspace : .webAssign,
                sourceImages: ["Built-in sample"], warnings: index == 3 ? ["Check the deadline against the source."] : [])
        })
        page = .addReminder
        statusMessage = "Example preview only. Import your own files to save real tasks."
    }

    func simulateSave() {
        guard isDemo, selectedCount > 0 else { return }
        previewSaved = true
        showSampleCalendar = true; page = .calendar
        statusMessage = LocalizedMessage(verbatim: copy("Preview complete. No Apple data was written.", "预览完成，未写入 Apple 数据。"))
    }

    func confirmReviewed(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].candidate.dueDate != nil else { return }
        items[index].candidate.warnings = []
        items[index].status = .ready
        saveCompleted = false; previewSaved = false
    }

    /// Photos picker copies are app-owned and removed after recognition or cancellation.
    func importPhotoData(_ data: [Data]) {
        guard !isProcessing, !data.isEmpty, data.count <= 20 else { return }
        cleanPhotoCopies()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ReminderSnapPhotos-" + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            photoDirectory = folder
            var urls: [URL] = []
            for (index, bytes) in data.enumerated() {
                let url = folder.appendingPathComponent("Screenshot-\(index + 1).image")
                try bytes.write(to: url, options: .atomic)
                urls.append(url)
            }
            importScreenshots(urls)
            if !isProcessing { cleanPhotoCopies() }
        } catch {
            cleanPhotoCopies()
            statusMessage = LocalizedMessage(verbatim: error.localizedDescription)
        }
    }

    private func cleanPhotoCopies() {
        if let folder = photoDirectory { try? FileManager.default.removeItem(at: folder) }
        photoDirectory = nil
    }

    private func loadItems(_ candidates: [AssignmentCandidate]) {
        items = candidates.map { source in
            var candidate = source
            if let profile = planner.courses.first(where: { $0.id == candidate.courseTag }) {
                if let text = candidate.sourceDeadlineText,
                   let date = DeadlineParser.parse(text, fallbackYear: Int(batchYear) ?? profile.year, fallbackTimeZone: batchTimeZone.isEmpty ? profile.timeZoneIdentifier : batchTimeZone) {
                    candidate.dueDate = date.date; candidate.hasExplicitTime = date.hasExplicitTime
                    candidate.timeZoneIdentifier = date.timeZoneIdentifier
                }
            }
            var item = ImportItem(candidate: candidate, deadlineNotificationEnabled: defaultDeadlineNotificationEnabled,
                       companionEventEnabled: outputMode.usesCalendar || outputMode == .google,
                       companionEventStartAlertEnabled: defaultCompanionEventStartAlertEnabled,
                       companionEventAdditionalLeadTimes: defaultCompanionEventAdditionalLeadTimes)
            item.appAlertLeadTimes = appAlertLeadTimes
            if !SectionSelection.matches(candidate, profile: planner.courses.first(where: { $0.id == candidate.courseTag })) {
                item.isSelected = false
            }
            if candidate.submissionStatus?.lowercased().contains("submitted") == true &&
               candidate.submissionStatus?.lowercased().contains("no submission") != true {
                item.isSelected = false
            }
            return item
        }
    }

    func setDefaultDeadlineNotificationEnabled(_ enabled: Bool) {
        defaultDeadlineNotificationEnabled = enabled; defaults.set(enabled, forKey: DefaultsKey.deadlineNotificationEnabled)
    }
    func setDefaultCompanionEventsEnabled(_ enabled: Bool) {
        defaultCompanionEventsEnabled = enabled; defaults.set(enabled, forKey: DefaultsKey.companionEventsEnabled)
        if enabled && outputMode == .reminders { outputMode = .both }
        else if !enabled && outputMode == .both { outputMode = .reminders }
    }
    func setDefaultCompanionEventStartAlertEnabled(_ enabled: Bool) {
        defaultCompanionEventStartAlertEnabled = enabled; defaults.set(enabled, forKey: DefaultsKey.companionEventStartAlertEnabled)
    }
    func setDefaultCompanionEventAdditionalLeadTimes(_ values: [TimeInterval]) {
        defaultCompanionEventAdditionalLeadTimes = Self.normalizedCalendarLeadTimes(values)
        defaults.set(defaultCompanionEventAdditionalLeadTimes, forKey: DefaultsKey.companionEventAdditionalLeadTimes)
    }
    func applyNotificationDefaultsToAll() {
        for index in items.indices {
            items[index].appAlertLeadTimes = appAlertLeadTimes
            items[index].appAlertsEnabled = true
            items[index].deadlineNotificationEnabled = defaultDeadlineNotificationEnabled
            items[index].companionEventStartAlertEnabled = defaultCompanionEventStartAlertEnabled
            items[index].companionEventAdditionalLeadTimes = defaultCompanionEventAdditionalLeadTimes
        }
    }
    func setAllNotifications(_ enabled: Bool) {
        for index in items.indices {
            items[index].appAlertsEnabled = enabled
            items[index].deadlineNotificationEnabled = enabled
            items[index].companionEventStartAlertEnabled = enabled
            items[index].companionEventAdditionalLeadTimes = enabled ? defaultCompanionEventAdditionalLeadTimes : []
        }
    }
    func setAllCompanionEvents(_ enabled: Bool) {
        if enabled && outputMode == .reminders { outputMode = .both }
        for index in items.indices { items[index].companionEventEnabled = enabled }
    }
    func setAllSelected(_ selected: Bool) {
        let visible = Set(visibleImportItems.map(\.id))
        for index in items.indices where items[index].candidate.dueDate != nil && (!selected || visible.contains(items[index].id)) {
            items[index].isSelected = selected
        }
    }

    func addSelected() {
        saveReviewedAssignments()
    }

    private func finishImport(_ candidates: [AssignmentCandidate], documents docs: [OCRDocument], errors: [String], readTime: TimeInterval, parseTime: TimeInterval, token: UUID) async {
        guard token == importID else { return }
        documents = docs; loadItems(candidates)
        let checkStart = Date()
        statusMessage = "Checking existing reminders…"
        await refreshMatches()
        guard token == importID else { return }
        readingSummary = LocalizedMessage("Reading %@s • interpretation %@s • duplicate check %@s • %@ page(s). Session-only text; Clear releases it.", arguments: [String(format: "%.1f", readTime), String(format: "%.2f", parseTime), String(format: "%.2f", Date().timeIntervalSince(checkStart)), String(docs.count)])
        statusMessage = candidates.isEmpty
            ? (docs.allSatisfy { $0.lines.isEmpty } ? "No readable text found. Try a sharper image with a little margin around the text." : "Text was read, but no title/deadline pair was found. Open Recognized Text and check the crop and batch context.")
            : "Found \(candidates.count) task(s). Review titles, dates, and warnings before saving."
        if !errors.isEmpty {
            statusMessage = .joined([statusMessage, LocalizedMessage("Some files failed: %@", arguments: [errors.joined(separator: "; ")])])
        }
        isProcessing = false; activeImport = nil
        cleanPhotoCopies()
        showingMissingDetails = candidates.contains { $0.dueDate == nil || $0.courseCode.isEmpty || $0.assignmentName.isEmpty } ||
            candidates.contains { candidate in
                (candidate.sectionCode != nil && planner.courses.first(where: { $0.id == candidate.courseTag })?.section.isEmpty != false) ||
                (!candidate.courseCode.isEmpty && !planner.courses.contains(where: { $0.id == candidate.courseTag }) &&
                 (candidate.sourceDeadlineText ?? "").range(of: #"\b(?:EDT|EST|PDT|PST|CDT|CST|MDT|MST|UTC|GMT)\b"#, options: .regularExpression) == nil)
            }
    }

    private func finishWithError(_ message: LocalizedMessage, token: UUID) {
        guard token == importID else { return }
        isProcessing = false; activeImport = nil; statusMessage = message
        cleanPhotoCopies()
    }

    private func refreshMatches() async {
        guard reminderAccess, outputMode.usesReminders, !items.isEmpty, !isDemo else { return }
        let token = importID, listID = selectedListID
        do {
            let updated = try await reminderService.matches(candidates: items.map(\.candidate), listName: targetListName, listID: listID)
            guard token == importID, listID == selectedListID else { return }
            matches = updated
            for index in items.indices {
                guard let match = matches[items[index].id] else { continue }
                switch match.disposition {
                case .create: items[index].status = items[index].candidate.warnings.isEmpty ? .ready : .needsReview
                case .duplicate: items[index].status = .duplicate; items[index].isSelected = false
                case .updateDeadline: items[index].status = .updateDeadline
                }
            }
        } catch { /* Parsing remains available without a valid destination. */ }
    }

    private static func normalizedCalendarLeadTimes(_ values: [TimeInterval]) -> [TimeInterval] {
        Array(Set(values.filter(\.isFinite).map { max(60, min(365 * 86_400, $0.rounded())) })).sorted(by: >).prefix(4).map { $0 }
    }
}

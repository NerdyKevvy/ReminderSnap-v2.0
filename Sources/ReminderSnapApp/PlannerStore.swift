import Foundation
import CoreData
import CloudKit
import Combine
import ReminderSnapCore

/// Persistent local replica of a private CloudKit database. Account partitions
/// prevent one Apple account's assignments being uploaded into another account.
@MainActor
final class PlannerStore: ObservableObject {
    static let cloudContainer = "iCloud.com.nerdykevvy.ReminderSnap"
    @Published private(set) var tasks: [SavedAssignment] = []
    @Published private(set) var courses: [CourseProfile] = []
    @Published private(set) var googleCalendars: [String: String] = [:]
    @Published private(set) var ready = false
    @Published private(set) var syncState = "Opening assignment calendar…"
    @Published private(set) var error: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var iCloudAvailable = false
    @Published private(set) var localAssignmentsAvailable = false
    var onChange: (() -> Void)?
    private var container: NSPersistentCloudKitContainer?
    private var observers: [NSObjectProtocol] = []
    private var storeObservers: [NSObjectProtocol] = []
    private var loading = false
    private var activePartition = ""
    private var activeCloud = false
    private let storeDirectory: URL?
    private var cloudEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["REMINDERSNAP_LOCAL_ONLY"] == "1" { return false }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "ReminderSnapCloudSyncEnabled") as? Bool == true
    }

    init(storeDirectory: URL? = nil) {
        self.storeDirectory = storeDirectory
        observers.append(NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.open(recheckAccount: true) }
        })
    }

    func open(recheckAccount: Bool = false) async {
        guard !loading, !ready || recheckAccount else { return }
        loading = true
        defer { loading = false }
        var partition = "local", useCloud = false
        if cloudEnabled {
            do {
                let cloud = CKContainer(identifier: Self.cloudContainer)
                let status = try await cloud.accountStatus()
                if status == .available {
                    let user = try await cloud.userRecordID()
                    partition = SavedAssignment.stableID(user.recordName).uuidString
                    UserDefaults.standard.set(partition, forKey: "Planner.LastAccountPartition")
                    useCloud = true
                } else if status == .couldNotDetermine || status == .temporarilyUnavailable {
                    partition = UserDefaults.standard.string(forKey: "Planner.LastAccountPartition") ?? "local"
                    error = "iCloud is temporarily unavailable. Saved assignments remain on this device."
                }
            } catch {
                partition = UserDefaults.standard.string(forKey: "Planner.LastAccountPartition") ?? "local"
                self.error = error.localizedDescription
            }
        }
        iCloudAvailable = useCloud
        guard activePartition != partition || container == nil || activeCloud != useCloud else {
            syncState = useCloud ? "iCloud enabled · changes sync automatically" : "On this device · iCloud unavailable"
            return
        }
        ready = false
        for observer in storeObservers { NotificationCenter.default.removeObserver(observer) }
        storeObservers = []
        if let old = container {
            if old.viewContext.hasChanges { try? old.viewContext.save() }
            for persistentStore in old.persistentStoreCoordinator.persistentStores {
                try? old.persistentStoreCoordinator.remove(persistentStore)
            }
        }
        container = nil
        // Do not display the prior account while changing storage partitions.
        tasks = []; courses = []; onChange?()
        do {
            let root = try storeDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("ReminderSnap", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let store = NSPersistentCloudKitContainer(name: "AssignmentCenter", managedObjectModel: Self.schema())
            let description = NSPersistentStoreDescription(url: root.appendingPathComponent("Planner-\(partition).sqlite"))
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.shouldMigrateStoreAutomatically = true; description.shouldInferMappingModelAutomatically = true
            if useCloud {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudContainer)
                options.databaseScope = .private
                description.cloudKitContainerOptions = options
            }
            store.persistentStoreDescriptions = [description]
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            store.viewContext.automaticallyMergesChangesFromParent = true
            store.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            store.viewContext.transactionAuthor = "ReminderSnap"
            container = store; activePartition = partition; activeCloud = useCloud; ready = true
            storeObservers.append(NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: store.persistentStoreCoordinator, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reload() }
            })
            storeObservers.append(NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: store, queue: .main) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                Task { @MainActor in
                    guard let self else { return }
                    if let failure = event.error {
                        self.error = Self.cloudErrorDescription(failure); self.syncState = "iCloud needs attention · changes kept locally"
                    } else if event.endDate == nil {
                        self.syncState = "Syncing with iCloud…"
                    } else if event.succeeded {
                        self.error = nil; self.lastSync = event.endDate
                        self.syncState = "iCloud sync activity completed"
                        self.reload()
                    }
                }
            })
            syncState = useCloud ? "iCloud enabled · waiting for sync" : "On this device · enable iCloud to sync"
            localAssignmentsAvailable = useCloud && FileManager.default.fileExists(atPath: root.appendingPathComponent("Planner-local.sqlite").path) &&
                !UserDefaults.standard.bool(forKey: "Planner.GuestMerged." + partition)
            reload()
        } catch {
            self.error = error.localizedDescription
            syncState = "Calendar could not open · your existing data was not removed"
        }
    }

    private static func schema() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = ["AssignmentRow", "CourseRow", "IntegrationRow"].map { name in
            let entity = NSEntityDescription(); entity.name = name
            entity.managedObjectClassName = "NSManagedObject"
            let key = NSAttributeDescription(); key.name = "key"; key.attributeType = .stringAttributeType
            key.isOptional = true
            let payload = NSAttributeDescription(); payload.name = "payload"; payload.attributeType = .binaryDataAttributeType
            payload.isOptional = true; payload.allowsExternalBinaryDataStorage = false
            entity.properties = [key, payload]
            return entity
        }
        return model
    }

    func reload() {
        guard let context = container?.viewContext else { return }
        do {
            let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "AssignmentRow"))
            let decoded: [SavedAssignment] = rows.compactMap { row in
                guard let data = row.value(forKey: "payload") as? Data else { return nil }
                return try? JSONDecoder().decode(SavedAssignment.self, from: data)
            }
            // CloudKit mirroring cannot enforce unique constraints. Stable IDs
            // coalesce duplicate offline creations without creating extra exports.
            tasks = Dictionary(grouping: decoded, by: \.id).values.compactMap { versions in
                versions.max { $0.modifiedAt < $1.modifiedAt }
            }.sorted { ($0.candidate.dueDate ?? .distantFuture) < ($1.candidate.dueDate ?? .distantFuture) }
            let profileRows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CourseRow"))
            let profiles: [CourseProfile] = profileRows.compactMap { row in
                guard let data = row.value(forKey: "payload") as? Data else { return nil }
                return try? JSONDecoder().decode(CourseProfile.self, from: data)
            }
            courses = Dictionary(grouping: profiles, by: \.id).values.compactMap {
                $0.max { $0.modifiedAt < $1.modifiedAt }
            }.filter { $0.isDeleted != true }.sorted { $0.name < $1.name }
            let integrationRows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "IntegrationRow"))
            googleCalendars = [:]
            for row in integrationRows {
                guard let key = row.value(forKey: "key") as? String,
                      let data = row.value(forKey: "payload") as? Data,
                      let id = try? JSONDecoder().decode(String.self, from: data) else { continue }
                googleCalendars[key] = id
            }
            onChange?()
        } catch { self.error = error.localizedDescription }
    }

    func save(_ task: SavedAssignment) throws {
        try put(task, key: task.id.uuidString, entity: "AssignmentRow")
        reload()
    }
    func save(_ profile: CourseProfile) throws {
        try put(profile, key: profile.id, entity: "CourseRow"); reload()
    }

    /// Rename a course and its assignments in one local transaction. Task IDs
    /// and export identifiers stay stable so linked entries are edited in place.
    func replaceCourse(_ original: CourseProfile, with updated: CourseProfile) throws {
        guard let context = container?.viewContext else { return }
        guard courses.first(where: { $0.id == original.id })?.modifiedAt == original.modifiedAt else {
            throw NSError(domain: "Planner", code: 2, userInfo: [NSLocalizedDescriptionKey: "This course changed on another device. Close and reopen its editor."])
        }
        do {
            if original.id != updated.id {
                try put(original.tombstone(), key: original.id, entity: "CourseRow", commit: false)
            }
            try put(updated, key: updated.id, entity: "CourseRow", commit: false)
            for var task in tasks where !task.isDeleted && task.candidate.courseTag == original.id && original.name != updated.name {
                task.candidate.courseCode = updated.name
                if let title = task.candidate.titleOverride, title.hasPrefix(original.id + " ") {
                    task.candidate.titleOverride = updated.id + title.dropFirst(original.id.count)
                }
                task.modifiedAt = Date(); task.exportError = nil
                try put(task, key: task.id.uuidString, entity: "AssignmentRow", commit: false)
            }
            try context.save(); reload()
        } catch { context.rollback(); reload(); throw error }
    }

    func deleteCourse(_ profile: CourseProfile) throws {
        // Keep saved assignments and links. Only remove the reusable preference.
        try put(profile.tombstone(), key: profile.id, entity: "CourseRow"); reload()
    }
    func saveGoogleCalendar(_ calendar: String, account: String) throws {
        try put(calendar, key: account, entity: "IntegrationRow"); reload()
    }

    private static func cloudErrorDescription(_ error: Error) -> String {
        if let error = error as? CKError, let nested = error.partialErrorsByItemID?.values.first {
            return cloudErrorDescription(nested)
        }
        let value = error as NSError
        return value.localizedFailureReason ?? value.userInfo[NSDebugDescriptionErrorKey] as? String ?? value.localizedDescription
    }
    #if DEBUG
    func initializeDevelopmentSchema() {
        guard activeCloud, let container else { return }
        do {
            try container.initializeCloudKitSchema(options: [])
            syncState = "Development schema initialized · ready to deploy in CloudKit Console"
            error = nil
        } catch { self.error = Self.cloudErrorDescription(error) }
    }
    #endif

    /// Explicit opt-in: never silently upload guest/local assignments after an
    /// Apple-account change. The original local database remains recoverable.
    func mergeLocalAssignments() async {
        guard ready, activeCloud, activePartition != "local", localAssignmentsAvailable else { return }
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("ReminderSnap", isDirectory: true)
            let local = NSPersistentContainer(name: "AssignmentCenter", managedObjectModel: Self.schema())
            let description = NSPersistentStoreDescription(url: root.appendingPathComponent("Planner-local.sqlite"))
            description.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
            local.persistentStoreDescriptions = [description]
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                local.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            defer {
                for store in local.persistentStoreCoordinator.persistentStores { try? local.persistentStoreCoordinator.remove(store) }
            }
            let rows = try local.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "AssignmentRow"))
            for row in rows {
                guard let data = row.value(forKey: "payload") as? Data,
                      let value = try? JSONDecoder().decode(SavedAssignment.self, from: data),
                      !value.isDeleted, !tasks.contains(where: { $0.id == value.id }) else { continue }
                try put(value, key: value.id.uuidString, entity: "AssignmentRow")
            }
            let profiles = try local.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "CourseRow"))
            for row in profiles {
                guard let data = row.value(forKey: "payload") as? Data,
                      let value = try? JSONDecoder().decode(CourseProfile.self, from: data),
                      !courses.contains(where: { $0.id == value.id }) else { continue }
                try put(value, key: value.id, entity: "CourseRow")
            }
            UserDefaults.standard.set(true, forKey: "Planner.GuestMerged." + activePartition)
            localAssignmentsAvailable = false; reload()
        } catch { self.error = error.localizedDescription }
    }
    private func put<T: Encodable>(_ value: T, key: String, entity: String, commit: Bool = true) throws {
        guard ready, let context = container?.viewContext else {
            throw NSError(domain: "Planner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Wait for the assignment calendar to finish opening."])
        }
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "key == %@", key)
        let rows = try context.fetch(request)
        let data = try JSONEncoder().encode(value)
        let row = rows.first ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
        row.setValue(key, forKey: "key"); row.setValue(data, forKey: "payload")
        // Keep duplicate backing rows consistent; do not delete a row remotely
        // and accidentally resurrect its older payload after an offline merge.
        for duplicate in rows.dropFirst() { duplicate.setValue(data, forKey: "payload") }
        if commit { try context.save() }
        if iCloudAvailable { syncState = "Saved on this device · iCloud sync pending" }
    }
}

import Foundation
import EventKit

public enum PermissionState: Equatable, Sendable {
    case notDetermined, denied, restricted, writeOnly, full
    public var canReadAndWrite: Bool { self == .full }
    public var descriptionKey: String {
        switch self {
        case .notDetermined: return "Access not requested yet"
        case .denied: return "Access denied — enable full access in System Settings"
        case .restricted: return "Access restricted by this Mac's policy"
        case .writeOnly: return "Add-only access — full access is needed to select and update destinations"
        case .full: return "Full access granted"
        }
    }
    public static func current(for type: EKEntityType) -> PermissionState {
        let status = EKEventStore.authorizationStatus(for: type)
        if #available(macOS 14.0, iOS 17.0, *) {
            if status == .fullAccess { return .full }
            if status == .writeOnly { return .writeOnly }
        } else if status == .authorized { return .full }
        switch status {
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }
}

/// Coalesces notifications and retries without blocking the main thread.
/// The callback returns false when a save/import is in progress. A requested
/// reconnect then remains pending, rather than resetting a store mid-write.
@MainActor
public final class PermissionRefreshLoop {
    private var task: Task<Void, Never>?
    private var reconnectPending = false
    private let delays: [UInt64]
    private let refresh: (Bool) -> Bool
    public init(delays: [UInt64] = [0, 200_000_000, 600_000_000, 1_200_000_000, 2_000_000_000, 3_000_000_000], refresh: @escaping (Bool) -> Bool) {
        self.delays = delays; self.refresh = refresh
    }
    public func start(reconnect: Bool = false) {
        reconnectPending = reconnectPending || reconnect
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            for delay in delays {
                if delay > 0 { do { try await Task.sleep(nanoseconds: delay) } catch { break } }
                guard !Task.isCancelled else { break }
                let requested = reconnectPending
                reconnectPending = false
                if !refresh(requested) { reconnectPending = reconnectPending || requested }
            }
            task = nil
        }
    }
    public func waitForCompletion() async { await task?.value }
    public func cancel() { task?.cancel() }
}

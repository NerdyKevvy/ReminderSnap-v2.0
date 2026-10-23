import Foundation
import Combine
import ReminderSnapCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum CalendarConnectionError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

/// No developer server or Google analytics SDK. OAuth credentials stay in this
/// device's Keychain; only app-created secondary calendars are requested.
@MainActor
final class GoogleCalendarConnection: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var accountID = ""
    @Published private(set) var email = ""
    @Published private(set) var busy = false
    @Published var message = ""
    static let scope = "https://www.googleapis.com/auth/calendar.app.created"
    private let oauth = GoogleOAuthSession()
    private let network = URLSession(configuration: .ephemeral)
    private var clientID: String { Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "" }
    var configured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    func restore() async {
        guard configured else { return }
        do {
            if let credentials = try oauth.restore() { accept(credentials) }
        } catch { message = "Reconnect Google Calendar to update linked events." }
    }

    func connect() async {
        guard configured else { message = "Google Calendar is not configured for this build."; return }
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            accept(try await oauth.signIn(clientID: clientID, scope: Self.scope))
            if !connected { message = "Calendar access was not granted. Assignments still work in ReminderSnap." }
        } catch { message = error.localizedDescription }
    }

    private func accept(_ user: GoogleOAuthSession.Credentials) {
        connected = user.scopes.split(separator: " ").contains(Substring(Self.scope))
        accountID = user.accountID; email = user.email
        message = connected ? "Connected · only ReminderSnap-created calendars" : "Google Calendar permission is needed."
    }

    func disconnect() {
        oauth.disconnect()
        connected = false; accountID = ""; email = ""
        message = "Disconnected on this device. Existing Google events were not deleted."
    }
    func handle(_ url: URL) {
        // ASWebAuthenticationSession owns and validates its callback; arbitrary
        // external deep links must never be interpreted as credentials.
    }

    private func token() async throws -> String {
        guard connected else {
            throw CalendarConnectionError.message("Connect Google Calendar in Settings first.")
        }
        return try await oauth.accessToken(clientID: clientID)
    }

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil,
                         accepted: Set<Int> = [200, 201, 204]) async throws -> ([String: Any], Int) {
        let accessToken = try await token()
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/" + path) else {
            throw CalendarConnectionError.message("Invalid Calendar request.")
        }
        var request = URLRequest(url: url); request.httpMethod = method
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await network.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard accepted.contains(code) else {
            if code == 401 { connected = false }
            throw CalendarConnectionError.message("Google Calendar request failed (\(code)). Your assignment remains saved; retry when connected.")
        }
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:], code)
    }
    private func escaped(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    }

    func createCalendar() async throws -> String {
        let (response, _) = try await request("calendars", method: "POST", body: [
            "summary": "ReminderSnap Assignments", "timeZone": TimeZone.current.identifier,
            "description": "Assignment planning blocks created by ReminderSnap. Actual deadlines are included in each event."
        ])
        guard let id = response["id"] as? String else { throw CalendarConnectionError.message("Google did not return a calendar identifier.") }
        return id
    }

    func save(_ assignment: SavedAssignment, calendarID: String, externalAlerts: Bool) async throws -> (id: String, url: String?) {
        guard let due = assignment.candidate.dueDate else { throw CalendarConnectionError.message("Choose a deadline first.") }
        let eventID = assignment.googleEventID ?? ("rs" + assignment.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased())
        let zone = assignment.candidate.timeZoneIdentifier ?? TimeZone.current.identifier
        let formatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "summary": (assignment.isCompleted ? "✓ " : "") + assignment.candidate.reminderTitle,
            "description": "Actual deadline: \(formatter.string(from: due)) (\(zone))\nReminderSnap-Task: \(assignment.id.uuidString)",
            "extendedProperties": ["private": ["remindersnapTask": assignment.id.uuidString]],
            "reminders": ["useDefault": false], "transparency": "transparent"
        ]
        if assignment.companionBlock, let range = CompanionBlockSchedule.range(for: assignment.candidate) {
            body["start"] = ["dateTime": formatter.string(from: range.start), "timeZone": zone]
            body["end"] = ["dateTime": formatter.string(from: range.end), "timeZone": zone]
        } else if assignment.candidate.hasExplicitTime {
            body["start"] = ["dateTime": formatter.string(from: due), "timeZone": zone]
            body["end"] = ["dateTime": formatter.string(from: due.addingTimeInterval(60)), "timeZone": zone]
        } else {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: zone) ?? .current
            let dateFormatter = DateFormatter(); dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = calendar.timeZone; dateFormatter.dateFormat = "yyyy-MM-dd"
            body["start"] = ["date": dateFormatter.string(from: due)]
            body["end"] = ["date": dateFormatter.string(from: calendar.date(byAdding: .day, value: 1, to: due)!)]
        }
        if externalAlerts, !assignment.isCompleted {
            // Google reminders are relative to the event start. Rebase lead
            // times to the real deadline rather than shifting that deadline.
            let start = assignment.companionBlock ? CompanionBlockSchedule.range(for: assignment.candidate)?.start ?? due : due
            let alarms = assignment.alertLeadTimes.compactMap { lead -> [String: Any]? in
                let minutes = Int(start.timeIntervalSince(due.addingTimeInterval(-lead)) / 60)
                guard (0...40320).contains(minutes) else { return nil }
                return ["method": "popup", "minutes": minutes]
            }
            body["reminders"] = ["useDefault": false, "overrides": Array(alarms.prefix(5))]
        }
        let path = "calendars/\(escaped(calendarID))/events/\(eventID)"
        let (existing, code) = try await request(path, accepted: [200, 404, 410])
        if code == 410 || existing["status"] as? String == "cancelled" {
            throw CalendarConnectionError.message("This linked Google event was deleted outside ReminderSnap. The assignment is still saved here; choose an in-app workflow or re-export it explicitly rather than silently recreating a deleted event.")
        }
        if code == 200 {
            let properties = existing["extendedProperties"] as? [String: Any]
            let marker = (properties?["private"] as? [String: String])?["remindersnapTask"]
            guard marker == assignment.id.uuidString else { throw CalendarConnectionError.message("The matching event is not owned by ReminderSnap; it was not changed.") }
            let (response, _) = try await request(path, method: "PATCH", body: body)
            return (eventID, response["htmlLink"] as? String)
        }
        body["id"] = eventID
        let (response, insertCode) = try await request("calendars/\(escaped(calendarID))/events", method: "POST", body: body, accepted: [200, 201, 409])
        if insertCode == 409 {
            // Another device created the same stable task ID concurrently.
            let (current, _) = try await request(path)
            let properties = current["extendedProperties"] as? [String: Any]
            guard (properties?["private"] as? [String: String])?["remindersnapTask"] == assignment.id.uuidString,
                  current["status"] as? String != "cancelled" else {
                throw CalendarConnectionError.message("The existing Google event could not be safely matched. It was not changed.")
            }
            let (updated, _) = try await request(path, method: "PATCH", body: body)
            return (eventID, updated["htmlLink"] as? String)
        }
        return (eventID, response["htmlLink"] as? String)
    }

    func delete(_ task: SavedAssignment) async throws {
        guard let calendar = task.googleCalendarID, let event = task.googleEventID else { return }
        let path = "calendars/\(escaped(calendar))/events/\(escaped(event))"
        let (existing, code) = try await request(path, accepted: [200, 404, 410])
        guard code == 200 else { return }
        let properties = existing["extendedProperties"] as? [String: Any]
        guard (properties?["private"] as? [String: String])?["remindersnapTask"] == task.id.uuidString else {
            throw CalendarConnectionError.message("This event is not owned by ReminderSnap; it was not deleted.")
        }
        _ = try await request(path, method: "DELETE", accepted: [200, 204, 404, 410])
    }
}

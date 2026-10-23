import Foundation
import AuthenticationServices
import CryptoKit
import Security
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Native public-client OAuth: system browser, state + S256 PKCE, no embedded
/// browser, client secret, analytics SDK, developer server, or synced token.
@MainActor
final class GoogleOAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Credentials: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var scopes: String
        var accountID: String
        var email: String
    }
    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Double
        let refresh_token: String?
        let scope: String?
    }
    private struct UserInfo: Decodable { let sub: String; let email: String? }
    private var credentials: Credentials?
    private var browserSession: ASWebAuthenticationSession?
    private var refreshTask: Task<Credentials, Error>?
    private var generation = 0
    private let network = URLSession(configuration: .ephemeral)
    private static let keychainService = "com.nerdykevvy.ReminderSnap.google-oauth"
    private static let keychainAccount = "calendar-connection-v1"

    func restore() throws -> Credentials? {
        var query = Self.keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CalendarConnectionError.message("Unlock this device and reconnect Google Calendar.")
        }
        let value = try JSONDecoder().decode(Credentials.self, from: data)
        credentials = value
        return value
    }

    func signIn(clientID: String, scope: String) async throws -> Credentials {
        let operation = generation
        let verifier = try randomString(), state = try randomString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let scheme = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirect = scheme + ":/oauthredirect"
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let requestedScopes = "openid email " + scope
        url.queryItems = [
            "client_id": clientID, "redirect_uri": redirect, "response_type": "code",
            "scope": requestedScopes, "code_challenge": challenge, "code_challenge_method": "S256",
            "state": state, "access_type": "offline", "prompt": "consent select_account"
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        let callback = try await authorize(url.url!, scheme: scheme)
        let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let values = parts?.queryItems ?? []
        guard callback.scheme == scheme, callback.path == "/oauthredirect",
              values.first(where: { $0.name == "state" })?.value == state else {
            throw CalendarConnectionError.message("Google sign-in could not be verified. Please try again.")
        }
        if values.contains(where: { $0.name == "error" }) {
            throw CalendarConnectionError.message("Google Calendar access was not granted. You can still use ReminderSnap without connecting.")
        }
        guard let code = values.first(where: { $0.name == "code" })?.value else {
            throw CalendarConnectionError.message("Google did not return a sign-in response.")
        }
        let token = try await exchange([
            "client_id": clientID, "code": code, "code_verifier": verifier,
            "redirect_uri": redirect, "grant_type": "authorization_code"
        ])
        guard let refresh = token.refresh_token, !refresh.isEmpty else {
            throw CalendarConnectionError.message("Google did not grant offline access. Reconnect and allow Calendar access.")
        }
        let scopes = token.scope ?? requestedScopes
        guard scopes.split(separator: " ").contains(Substring(scope)) else {
            throw CalendarConnectionError.message("Calendar permission was not granted. Your assignments remain in ReminderSnap.")
        }
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer " + token.access_token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await network.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CalendarConnectionError.message("Google account details could not be verified. Please reconnect.")
        }
        let user = try JSONDecoder().decode(UserInfo.self, from: data)
        let value = Credentials(accessToken: token.access_token, refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(token.expires_in), scopes: scopes,
            accountID: user.sub, email: user.email ?? "")
        guard generation == operation else { throw CancellationError() }
        try persist(value); credentials = value
        return value
    }

    func accessToken(clientID: String) async throws -> String {
        guard let value = credentials else {
            throw CalendarConnectionError.message("Connect Google Calendar in Settings first.")
        }
        if value.expiresAt.timeIntervalSinceNow > 90 { return value.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        let operation = generation
        let task = Task { @MainActor in
            let token = try await exchange(["client_id": clientID, "refresh_token": value.refreshToken, "grant_type": "refresh_token"])
            var updated = value
            updated.accessToken = token.access_token
            updated.expiresAt = Date().addingTimeInterval(token.expires_in)
            updated.refreshToken = token.refresh_token ?? value.refreshToken
            updated.scopes = token.scope ?? value.scopes
            guard generation == operation else { throw CancellationError() }
            try persist(updated); credentials = updated
            return updated
        }
        refreshTask = task; defer { refreshTask = nil }
        return try await task.value.accessToken
    }

    func disconnect() {
        generation += 1; browserSession?.cancel(); browserSession = nil
        refreshTask?.cancel(); refreshTask = nil; credentials = nil
        SecItemDelete(Self.keychainQuery as CFDictionary)
    }

    private func exchange(_ parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, response) = try await network.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            // Never put an auth code, token, response body, or callback URL in logs/UI.
            throw CalendarConnectionError.message("Google sign-in expired or could not refresh. Reconnect Google Calendar in Settings.")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func authorize(_ url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callback, error in
                Task { @MainActor in
                    self?.browserSession = nil
                    if let callback { continuation.resume(returning: callback) }
                    else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                        continuation.resume(throwing: CalendarConnectionError.message("Google connection cancelled. Nothing was uploaded."))
                    } else {
                        continuation.resume(throwing: CalendarConnectionError.message("Google sign-in could not open. Please try again."))
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            browserSession = session
            if !session.start() {
                browserSession = nil
                continuation.resume(throwing: CalendarConnectionError.message("Open the ReminderSnap window, then connect Google Calendar again."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #else
        return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
        #endif
    }
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: keychainAccount, kSecAttrSynchronizable as String: false,
         kSecUseDataProtectionKeychain as String: true]
    }
    private func persist(_ value: Credentials) throws {
        let data = try JSONEncoder().encode(value)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(Self.keychainQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = Self.keychainQuery
            attributes.forEach { query[$0.key] = $0.value }
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CalendarConnectionError.message("Google connection could not be stored securely in Keychain.") }
    }
    private func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CalendarConnectionError.message("Secure sign-in could not be initialized.")
        }
        return Data(bytes).base64URL
    }
}
private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}

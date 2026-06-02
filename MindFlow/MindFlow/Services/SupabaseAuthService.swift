//
//  SupabaseAuthService.swift
//  MindFlow
//
//  Supabase OAuth authentication service
//  Shared authentication with ZephyrOS ecosystem
//

import Foundation
import AuthenticationServices

/// Keychain keys shared between SupabaseAuthService and MindFlowAPIClient
/// for storing sensitive authentication tokens.
enum SupabaseKeychainKeys {
    static let accessToken = "supabase_access_token"
    static let refreshToken = "supabase_refresh_token"
}

/// Manages user authentication through Supabase OAuth with Google provider
///
/// This service handles the complete OAuth flow including:
/// - Initiating Google sign-in through Supabase
/// - Processing OAuth callbacks
/// - Managing user session state
/// - Storing and restoring authentication tokens
@MainActor
final class SupabaseAuthService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var userId: String?

    // MARK: - Private Properties

    private let supabaseURL: String
    private let redirectURI: String
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Initialization

    override init() {
        self.supabaseURL = ConfigurationManager.shared.supabaseURL
        self.redirectURI = ConfigurationManager.shared.supabaseRedirectURI
        super.init()
    }

    // MARK: - Public Methods

    /// Initiates Google OAuth sign-in flow through Supabase
    ///
    /// This method opens a web authentication session for the user to sign in with Google.
    /// Uses ephemeral session to require explicit consent and prevent automatic login.
    ///
    /// - Throws: `SupabaseAuthError` if authentication fails
    func signIn() async throws {
        let authURL = try buildSupabaseAuthURL()
        let callbackScheme = redirectURI.components(separatedBy: ":").first ?? "com.mindflow.app"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    self?.authSession = nil
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    self?.authSession = nil
                    continuation.resume(throwing: SupabaseAuthError.noCallbackURL)
                    return
                }

                _Concurrency.Task { @MainActor in
                    defer { self?.authSession = nil }
                    do {
                        try await self?.handleCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = true
            authSession?.start()
        }
    }

    /// Signs out the current user and clears all stored credentials
    func signOut() {
        accessToken = nil
        userEmail = nil
        userName = nil
        userId = nil
        isAuthenticated = false

        clearStoredCredentials()
    }

    /// Attempts to restore a previously authenticated session
    ///
    /// Validates the stored access token by fetching user info.
    /// If validation fails, clears stored credentials.
    func restoreSession() async {
        migrateTokensFromUserDefaultsIfNeeded()

        guard let token = KeychainManager.shared.get(key: SupabaseKeychainKeys.accessToken) else {
            return
        }

        do {
            try await fetchUserInfo(token: token)
            accessToken = token
            isAuthenticated = true
        } catch {
            // Access token may have expired. Attempt a single refresh before giving up.
            Logger.info("Session restore failed, attempting token refresh", category: .auth)
            do {
                let newToken = try await refreshSession()
                try await fetchUserInfo(token: newToken)
                accessToken = newToken
                isAuthenticated = true
            } catch {
                Logger.warning("Token refresh failed, signing out", category: .auth)
                signOut()
            }
        }
    }

    /// Refreshes the current session using the stored refresh token.
    ///
    /// Exchanges the refresh token for a new access/refresh token pair via the
    /// Supabase `grant_type=refresh_token` endpoint and persists both tokens.
    ///
    /// - Returns: The newly issued access token.
    /// - Throws: `SupabaseAuthError` if no refresh token is stored or the refresh fails.
    @discardableResult
    func refreshSession() async throws -> String {
        guard let refreshToken = KeychainManager.shared.get(key: SupabaseKeychainKeys.refreshToken) else {
            throw SupabaseAuthError.noAccessToken
        }

        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseAuthError.invalidCallback
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ConfigurationManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseAuthError.fetchUserInfoFailed
        }

        let session = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
        storeTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
        self.accessToken = session.accessToken
        return session.accessToken
    }

    // MARK: - Private Methods

    private func buildSupabaseAuthURL() throws -> URL {
        guard var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize") else {
            throw SupabaseAuthError.invalidCallback
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURI)
        ]
        guard let url = components.url else {
            throw SupabaseAuthError.invalidCallback
        }
        return url
    }

    private func handleCallback(url: URL) async throws {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        guard let fragment = components?.fragment else {
            throw SupabaseAuthError.invalidCallback
        }

        let params = parseFragmentParameters(fragment)

        guard let accessToken = params["access_token"] else {
            throw SupabaseAuthError.noAccessToken
        }

        self.accessToken = accessToken
        storeTokens(accessToken: accessToken, refreshToken: params["refresh_token"])

        try await fetchUserInfo(token: accessToken)
        isAuthenticated = true
    }

    /// One-time migration of pre-existing sessions: earlier builds stored the
    /// Supabase tokens in UserDefaults. Move any found there into the Keychain so
    /// already-logged-in users are not signed out on upgrade.
    private func migrateTokensFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard KeychainManager.shared.get(key: SupabaseKeychainKeys.accessToken) == nil,
              let legacyAccess = defaults.string(forKey: SupabaseKeychainKeys.accessToken) else {
            return
        }
        let legacyRefresh = defaults.string(forKey: SupabaseKeychainKeys.refreshToken)
        storeTokens(accessToken: legacyAccess, refreshToken: legacyRefresh)
        defaults.removeObject(forKey: SupabaseKeychainKeys.accessToken)
        defaults.removeObject(forKey: SupabaseKeychainKeys.refreshToken)
        Logger.info("Migrated Supabase tokens from UserDefaults to Keychain", category: .auth)
    }

    /// Persists authentication tokens securely in the Keychain.
    private func storeTokens(accessToken: String, refreshToken: String?) {
        KeychainManager.shared.save(key: SupabaseKeychainKeys.accessToken, value: accessToken)
        if let refreshToken = refreshToken {
            KeychainManager.shared.save(key: SupabaseKeychainKeys.refreshToken, value: refreshToken)
        }
    }

    private func parseFragmentParameters(_ fragment: String) -> [String: String] {
        fragment.components(separatedBy: "&").reduce(into: [String: String]()) { result, param in
            let parts = param.components(separatedBy: "=")
            if parts.count == 2 {
                result[parts[0]] = parts[1].removingPercentEncoding
            }
        }
    }

    private func fetchUserInfo(token: String) async throws {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/user") else {
            throw SupabaseAuthError.invalidCallback
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ConfigurationManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.fetchUserInfoFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            Logger.warning("fetchUserInfo failed with HTTP \(httpResponse.statusCode)", category: .auth)
            throw SupabaseAuthError.fetchUserInfoFailed
        }

        let userInfo = try JSONDecoder().decode(SupabaseUser.self, from: data)

        userId = userInfo.id
        userEmail = userInfo.email
        userName = userInfo.userMetadata.fullName ?? userInfo.email

        storeUserInfo()
    }

    private func storeUserInfo() {
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        }
        if let userEmail = userEmail {
            UserDefaults.standard.set(userEmail, forKey: "supabase_user_email")
        }
        if let userName = userName {
            UserDefaults.standard.set(userName, forKey: "supabase_user_name")
        }
    }

    private func clearStoredCredentials() {
        KeychainManager.shared.delete(key: SupabaseKeychainKeys.accessToken)
        KeychainManager.shared.delete(key: SupabaseKeychainKeys.refreshToken)
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        UserDefaults.standard.removeObject(forKey: "supabase_user_name")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SupabaseAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Supporting Types

/// User data model from Supabase authentication
struct SupabaseUser: Codable {
    let id: String
    let email: String
    let userMetadata: UserMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    struct UserMetadata: Codable {
        let fullName: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }
}

/// Token pair returned by the Supabase token endpoint (e.g. refresh_token grant)
struct SupabaseTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

/// Errors that can occur during Supabase authentication
enum SupabaseAuthError: LocalizedError {
    case noCallbackURL
    case invalidCallback
    case noAccessToken
    case fetchUserInfoFailed

    var errorDescription: String? {
        switch self {
        case .noCallbackURL:
            return "No callback URL received from authentication"
        case .invalidCallback:
            return "Invalid callback URL format"
        case .noAccessToken:
            return "No access token found in callback"
        case .fetchUserInfoFailed:
            return "Failed to fetch user information"
        }
    }
}

//
//  SupabaseAuthService.swift
//  MindFlow
//
//  Supabase OAuth authentication service
//  Shared authentication with ZephyrOS ecosystem
//

import Foundation
import AuthenticationServices

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
        let authURL = buildSupabaseAuthURL()
        let callbackScheme = redirectURI.components(separatedBy: ":").first ?? "com.mindflow.app"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: SupabaseAuthError.noCallbackURL)
                    return
                }

                _Concurrency.Task { @MainActor in
                    do {
                        try await self.handleCallback(url: callbackURL)
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
        guard let token = UserDefaults.standard.string(forKey: "supabase_access_token") else {
            return
        }

        do {
            try await fetchUserInfo(token: token)
            accessToken = token
            isAuthenticated = true
        } catch {
            signOut()
        }
    }

    // MARK: - Private Methods

    private func buildSupabaseAuthURL() -> URL {
        var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURI)
        ]
        return components.url!
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
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")

        if let refreshToken = params["refresh_token"] {
            UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
        }

        try await fetchUserInfo(token: accessToken)
        isAuthenticated = true
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
        let url = URL(string: "\(supabaseURL)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(ConfigurationManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: request)
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
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
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

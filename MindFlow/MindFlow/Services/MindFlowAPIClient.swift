//
//  MindFlowAPIClient.swift
//  MindFlow
//
//  API client for communicating with ZMemory backend
//

import Foundation

/// Client for MindFlow API endpoints on ZMemory server
class MindFlowAPIClient {
    static let shared = MindFlowAPIClient()

    private let session: URLSession
    private var baseURL: String {
        return ConfigurationManager.shared.zmemoryAPIURL
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Create a new interaction record
    func createInteraction(_ request: CreateInteractionRequest) async throws -> InteractionRecord {
        let url = try makeURL(path: "/api/mindflow-stt-interactions")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(request)

        let (data, httpResponse) = try await performAuthenticated { accessToken in
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
            return urlRequest
        }

        guard httpResponse.statusCode == 201 else {
            Logger.error("HTTP \(httpResponse.statusCode)", category: .api)
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: "Request failed")
        }

        let decoder = createDecoder()
        let interactionResponse = try decoder.decode(InteractionResponse.self, from: data)

        return interactionResponse.interaction
    }

    /// Get all interactions for the authenticated user
    func getInteractions(
        transcriptionApi: String? = nil,
        optimizationLevel: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [InteractionRecord] {
        Logger.info("Fetching interactions", category: .api)

        guard var components = URLComponents(string: "\(baseURL)/api/mindflow-stt-interactions") else {
            Logger.error("Invalid URL constructed", category: .api)
            throw MindFlowAPIError.invalidURL
        }
        var queryItems: [URLQueryItem] = []

        if let transcriptionApi = transcriptionApi {
            queryItems.append(URLQueryItem(name: "transcription_api", value: transcriptionApi))
        }
        if let optimizationLevel = optimizationLevel {
            queryItems.append(URLQueryItem(name: "optimization_level", value: optimizationLevel))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            Logger.error("Invalid URL constructed", category: .api)
            throw MindFlowAPIError.invalidURL
        }

        let (data, httpResponse) = try await performAuthenticated { accessToken in
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return urlRequest
        }

        Logger.debug("Response: HTTP \(httpResponse.statusCode)", category: .api)

        guard httpResponse.statusCode == 200 else {
            Logger.error("Fetch failed - HTTP \(httpResponse.statusCode)", category: .api)
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: "Request failed")
        }

        let decoder = createDecoder()

        do {
            let interactionsResponse = try decoder.decode(InteractionsResponse.self, from: data)
            Logger.info("Fetched \(interactionsResponse.interactions.count) interactions", category: .api)
            return interactionsResponse.interactions
        } catch {
            Logger.error("Decoding error", category: .api, error: error)
            throw MindFlowAPIError.decodingError(error)
        }
    }

    /// Get a single interaction by ID
    func getInteraction(_ id: UUID) async throws -> InteractionRecord {
        let url = try makeURL(path: "/api/mindflow-stt-interactions/\(id.uuidString)")

        let (data, httpResponse) = try await performAuthenticated { accessToken in
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return urlRequest
        }

        guard httpResponse.statusCode == 200 else {
            Logger.error("HTTP \(httpResponse.statusCode)", category: .api)
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: "Request failed")
        }

        let decoder = createDecoder()
        let interactionResponse = try decoder.decode(InteractionResponse.self, from: data)

        return interactionResponse.interaction
    }

    /// Delete an interaction by ID
    func deleteInteraction(_ id: UUID) async throws {
        Logger.info("Deleting interaction", category: .api)

        let url = try makeURL(path: "/api/mindflow-stt-interactions/\(id.uuidString)")

        let (_, httpResponse) = try await performAuthenticated { accessToken in
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "DELETE"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return urlRequest
        }

        Logger.debug("Response: HTTP \(httpResponse.statusCode)", category: .api)

        guard httpResponse.statusCode == 200 else {
            Logger.error("Delete failed - HTTP \(httpResponse.statusCode)", category: .api)
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: "Request failed")
        }

        Logger.info("Interaction deleted successfully", category: .api)
    }

    // MARK: - Helper Methods

    /// Builds a `URL` from a path relative to `baseURL`, throwing instead of crashing.
    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw MindFlowAPIError.invalidURL
        }
        return url
    }

    /// Executes an authenticated request, retrying once after a 401 with a refreshed token.
    ///
    /// The `build` closure receives the current access token and returns the request
    /// to send. On a 401 response, a token refresh is attempted and the request is
    /// rebuilt with the new token and retried exactly once.
    private func performAuthenticated(
        _ build: (_ accessToken: String) throws -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        guard let accessToken = getAccessToken() else {
            throw MindFlowAPIError.notAuthenticated
        }

        let request = try build(accessToken)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response", category: .api)
            throw MindFlowAPIError.invalidResponse
        }

        // On 401, attempt a single refresh-and-retry.
        guard httpResponse.statusCode == 401 else {
            return (data, httpResponse)
        }

        Logger.info("Received 401, attempting token refresh", category: .auth)
        guard let newToken = await refreshAccessToken() else {
            throw MindFlowAPIError.notAuthenticated
        }

        let retryRequest = try build(newToken)
        let (retryData, retryResponse) = try await session.data(for: retryRequest)
        guard let retryHTTP = retryResponse as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response", category: .api)
            throw MindFlowAPIError.invalidResponse
        }
        return (retryData, retryHTTP)
    }

    private func getAccessToken() -> String? {
        let token = KeychainManager.shared.get(key: SupabaseKeychainKeys.accessToken)
        if token != nil {
            Logger.debug("Access token found", category: .auth)
        } else {
            Logger.warning("No access token found", category: .auth)
        }
        return token
    }

    /// Attempts to refresh the access token after a 401 and returns the new token.
    ///
    /// Performs a single `grant_type=refresh_token` exchange using the stored
    /// refresh token, then persists the new token pair to the Keychain using the
    /// shared `SupabaseKeychainKeys`.
    /// - Returns: A fresh access token, or `nil` if refresh is not possible.
    private func refreshAccessToken() async -> String? {
        guard let refreshToken = KeychainManager.shared.get(key: SupabaseKeychainKeys.refreshToken) else {
            Logger.warning("No refresh token available", category: .auth)
            return nil
        }

        let supabaseURL = ConfigurationManager.shared.supabaseURL
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            Logger.error("Invalid refresh URL", category: .auth)
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ConfigurationManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Logger.warning("Token refresh rejected by server", category: .auth)
                return nil
            }

            let tokens = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
            KeychainManager.shared.save(key: SupabaseKeychainKeys.accessToken, value: tokens.accessToken)
            if let newRefresh = tokens.refreshToken {
                KeychainManager.shared.save(key: SupabaseKeychainKeys.refreshToken, value: newRefresh)
            }
            Logger.info("Access token refreshed", category: .auth)
            return tokens.accessToken
        } catch {
            Logger.warning("Token refresh failed", category: .auth)
            return nil
        }
    }

    /// Create a JSON decoder configured for our API responses
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // Note: We have custom CodingKeys, so .convertFromSnakeCase is not needed

        // Custom date decoder to handle ISO8601 with fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first (API format: 2025-10-13T07:28:19.710026+00:00)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }

        return decoder
    }
}

// MARK: - Errors

enum MindFlowAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated. Please sign in first."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "API error (HTTP \(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

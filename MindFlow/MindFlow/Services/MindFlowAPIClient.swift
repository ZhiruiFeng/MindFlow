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
        guard let accessToken = getAccessToken() else {
            Logger.error("Not authenticated", category: .api)
            throw MindFlowAPIError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/mindflow-stt-interactions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response", category: .api)
            throw MindFlowAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("HTTP \(httpResponse.statusCode)", category: .api)
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
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
        print("📥 [MindFlowAPI] Fetching interactions - Limit: \(limit ?? 0), Offset: \(offset ?? 0)")

        guard let accessToken = getAccessToken() else {
            print("❌ [MindFlowAPI] Fetch failed - No access token")
            throw MindFlowAPIError.notAuthenticated
        }

        var components = URLComponents(string: "\(baseURL)/api/mindflow-stt-interactions")!
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
            print("❌ [MindFlowAPI] Invalid URL constructed")
            throw MindFlowAPIError.invalidURL
        }

        print("🌐 [MindFlowAPI] GET \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [MindFlowAPI] Invalid HTTP response")
            throw MindFlowAPIError.invalidResponse
        }

        print("📥 [MindFlowAPI] Response: HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [MindFlowAPI] Fetch failed - HTTP \(httpResponse.statusCode): \(errorMessage)")
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Log the raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [MindFlowAPI] Raw response: \(responseString.prefix(500))...")
        }

        let decoder = createDecoder()

        do {
            let interactionsResponse = try decoder.decode(InteractionsResponse.self, from: data)
            print("✅ [MindFlowAPI] Fetched \(interactionsResponse.interactions.count) interactions")
            return interactionsResponse.interactions
        } catch {
            print("❌ [MindFlowAPI] Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                print("   📋 Decoding details: \(decodingError)")
            }
            throw MindFlowAPIError.decodingError(error)
        }
    }

    /// Get a single interaction by ID
    func getInteraction(_ id: UUID) async throws -> InteractionRecord {
        guard let accessToken = getAccessToken() else {
            throw MindFlowAPIError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/mindflow-stt-interactions/\(id.uuidString)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MindFlowAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = createDecoder()
        let interactionResponse = try decoder.decode(InteractionResponse.self, from: data)

        return interactionResponse.interaction
    }

    /// Delete an interaction by ID
    func deleteInteraction(_ id: UUID) async throws {
        print("🗑️ [MindFlowAPI] Deleting interaction - ID: \(id.uuidString)")

        guard let accessToken = getAccessToken() else {
            print("❌ [MindFlowAPI] Delete failed - No access token")
            throw MindFlowAPIError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/mindflow-stt-interactions/\(id.uuidString)")!
        print("🌐 [MindFlowAPI] DELETE \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [MindFlowAPI] Invalid HTTP response")
            throw MindFlowAPIError.invalidResponse
        }

        print("📥 [MindFlowAPI] Response: HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [MindFlowAPI] Delete failed - HTTP \(httpResponse.statusCode): \(errorMessage)")
            throw MindFlowAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        print("✅ [MindFlowAPI] Interaction deleted successfully")
    }

    // MARK: - Helper Methods

    private func getAccessToken() -> String? {
        let token = UserDefaults.standard.string(forKey: "supabase_access_token")
        if token != nil {
            Logger.debug("Access token found", category: .auth)
        } else {
            Logger.warning("No access token found", category: .auth)
        }
        return token
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

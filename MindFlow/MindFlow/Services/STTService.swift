//
//  STTService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// Speech-to-text service
class STTService {
    static let shared = STTService()

    private var settings: Settings {
        return Settings.shared
    }

    private init() {}
    
    // MARK: - Public Methods
    
    /// Transcribe audio file
    func transcribe(audioURL: URL) async throws -> String {
        switch settings.sttProvider {
        case .openAI:
            return try await transcribeWithOpenAI(audioURL: audioURL)
        case .elevenLabs:
            return try await transcribeWithElevenLabs(audioURL: audioURL)
        }
    }
    
    // MARK: - OpenAI Whisper API
    
    private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
        guard !settings.openAIKey.isEmpty else {
            throw STTError.missingAPIKey("OpenAI API Key not configured")
        }

        let endpoint = "https://api.openai.com/v1/audio/transcriptions"

        // Create request
        guard let url = URL(string: endpoint) else {
            throw STTError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let trimmedKey = settings.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        // Create multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")

        // Don't specify language, let Whisper auto-detect language
        // This allows transcription of any language

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // End boundary
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw STTError.apiError("OpenAI: HTTP \(httpResponse.statusCode) - \(errorMessage)")
        }

        // Parse response
        struct WhisperResponse: Codable {
            let text: String
        }

        let decoder = JSONDecoder()
        let whisperResponse = try decoder.decode(WhisperResponse.self, from: data)

        return whisperResponse.text
    }
    
    // MARK: - ElevenLabs API

    private func transcribeWithElevenLabs(audioURL: URL) async throws -> String {
        guard !settings.elevenLabsKey.isEmpty else {
            throw STTError.missingAPIKey("ElevenLabs API Key not configured")
        }

        let endpoint = "https://api.elevenlabs.io/v1/speech-to-text"

        // Create request
        guard let url = URL(string: endpoint) else {
            throw STTError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let trimmedKey = settings.elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")

        // Create multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model_id field (required)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n")
        body.append("scribe_v1\r\n")

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // End boundary
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw STTError.apiError("ElevenLabs: HTTP \(httpResponse.statusCode) - \(errorMessage)")
        }

        // Parse response
        struct ElevenLabsResponse: Codable {
            let text: String
        }

        let decoder = JSONDecoder()
        let elevenLabsResponse = try decoder.decode(ElevenLabsResponse.self, from: data)

        return elevenLabsResponse.text
    }
}

// MARK: - STT Error

enum STTError: LocalizedError {
    case missingAPIKey(String)
    case invalidAudioFile
    case invalidResponse
    case apiError(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidAudioFile:
            return "Invalid audio file"
        case .invalidResponse:
            return "Invalid server response"
        case .apiError(let message):
            return "API error: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


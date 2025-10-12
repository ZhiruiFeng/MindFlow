//
//  LLMService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// LLM text optimization service
class LLMService {
    static let shared = LLMService()

    private var settings: Settings {
        return Settings.shared
    }

    private init() {}
    
    // MARK: - Public Methods
    
    /// Optimize text
    func optimizeText(_ text: String, level: OptimizationLevel? = nil) async throws -> String {
        guard !settings.openAIKey.isEmpty else {
            throw LLMError.missingAPIKey("OpenAI API Key not configured")
        }
        
        let optimizationLevel = level ?? settings.optimizationLevel
        let outputStyle = settings.outputStyle
        
        return try await optimizeWithOpenAI(
            text: text,
            level: optimizationLevel,
            style: outputStyle
        )
    }
    
    // MARK: - OpenAI Chat API
    
    private func optimizeWithOpenAI(
        text: String,
        level: OptimizationLevel,
        style: OutputStyle
    ) async throws -> String {
        let endpoint = "https://api.openai.com/v1/chat/completions"

        // Create request
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build prompt
        let systemPrompt = """
        \(level.systemPrompt)
        \(style.additionalPrompt)

        Important rules:
        1. Output the optimized text directly without any explanation or description
        2. Keep the core meaning and key information of the original text
        3. If the original text has multiple sentences, maintain the paragraphing
        4. Add appropriate punctuation
        """

        // Build request body
        let requestBody: [String: Any] = [
            "model": settings.llmModel.rawValue,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Parse response
        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        
        guard let optimizedText = chatResponse.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }
        
        print("✅ 文本优化成功")
        return optimizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - LLM Error

enum LLMError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case apiError(String)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "Invalid server response"
        case .apiError(let message):
            return "API error: \(message)"
        case .emptyResponse:
            return "API returned empty response"
        }
    }
}


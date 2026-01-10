//
//  LLMService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// Result from text optimization with teacher explanation
struct OptimizationResult {
    let refinedText: String
    let teacherExplanation: String
}

/// LLM text optimization service
class LLMService {
    static let shared = LLMService()

    private var settings: Settings {
        return Settings.shared
    }

    private init() {}

    // MARK: - Public Methods

    /// Optimize text and generate teacher explanation in one call
    func optimizeTextWithExplanation(_ text: String, level: OptimizationLevel? = nil) async throws -> OptimizationResult {
        guard !settings.openAIKey.isEmpty else {
            throw LLMError.missingAPIKey("OpenAI API Key not configured")
        }

        let optimizationLevel = level ?? settings.optimizationLevel
        let outputStyle = settings.outputStyle

        // Build combined prompt that asks for both refined text and explanation
        let systemPrompt = """
        You are a language optimization assistant and teacher.

        \(optimizationLevel.systemPrompt)
        \(outputStyle.additionalPrompt)

        Your task:
        1. First, optimize the user's text following the guidelines above
        2. Then, provide specific teaching guidance like a teacher giving improvement feedback

        Output format (use exactly this structure):
        REFINED_TEXT:
        [Your optimized version here]

        TEACHER_NOTE:
        Score: [X/10]

        Key improvements (max 3 points):
        • [Specific point with before/after example or vocabulary suggestion]
        • [Specific point with before/after example or vocabulary suggestion]
        • [Specific point with before/after example or vocabulary suggestion]

        Teaching guidelines for TEACHER_NOTE:
        - Give specific, actionable feedback with examples (e.g., "Instead of 'very good', use 'excellent' or 'outstanding' for stronger impact")
        - Show which vocabulary or sentence structure would better express the intended meaning
        - Limit to maximum 3 most important improvement points
        - Provide a score out of 10 for the original text
        - DO NOT give generic comments like "removed filler words" or "improved expression"
        - Focus on WHY a specific word or structure is better for the meaning

        Important rules:
        - Keep the core meaning and key information
        - Maintain paragraphing if multiple sentences exist
        - Add appropriate punctuation
        """

        let result = try await callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: text,
            temperature: 0.3,
            maxTokens: 1500
        )

        // Parse the response to extract refined text and teacher note
        return try parseOptimizationResponse(result)
    }

    /// Optimize text only (backward compatibility)
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

    /// Look up vocabulary word and get AI explanation
    /// - Parameters:
    ///   - word: The word to look up
    ///   - context: Optional context where the word was encountered
    /// - Returns: WordExplanation with comprehensive information
    func lookupVocabulary(_ word: String, context: String? = nil) async throws -> WordExplanation {
        return try await VocabularyLookupService.shared.lookupWord(word, context: context)
    }

    // MARK: - OpenAI Chat API

    private func optimizeWithOpenAI(
        text: String,
        level: OptimizationLevel,
        style: OutputStyle
    ) async throws -> String {
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

        let result = try await callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: text,
            temperature: 0.3
        )

        return result
    }

    /// Generic method to call OpenAI Chat API
    private func callOpenAI(
        systemPrompt: String,
        userPrompt: String,
        temperature: Double = 0.3,
        maxTokens: Int = 1000
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
                    "content": userPrompt
                ]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
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

        guard let responseText = chatResponse.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the combined optimization response
    private func parseOptimizationResponse(_ response: String) throws -> OptimizationResult {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for the markers
        guard let refinedRange = trimmed.range(of: "REFINED_TEXT:"),
              let teacherRange = trimmed.range(of: "TEACHER_NOTE:") else {
            // If markers not found, try to use the whole response as refined text
            Logger.warning("Could not find markers in response, using fallback parsing", category: .optimization)
            return OptimizationResult(
                refinedText: trimmed,
                teacherExplanation: "No explanation provided"
            )
        }

        // Extract refined text (between REFINED_TEXT: and TEACHER_NOTE:)
        let refinedStart = trimmed.index(refinedRange.upperBound, offsetBy: 0)
        let refinedEnd = teacherRange.lowerBound
        let refinedText = String(trimmed[refinedStart..<refinedEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract teacher note (after TEACHER_NOTE:)
        let teacherStart = trimmed.index(teacherRange.upperBound, offsetBy: 0)
        let teacherExplanation = String(trimmed[teacherStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return OptimizationResult(
            refinedText: refinedText,
            teacherExplanation: teacherExplanation
        )
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


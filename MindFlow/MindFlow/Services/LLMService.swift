//
//  LLMService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// Result from text optimization with teacher explanation and vocabulary suggestions
struct OptimizationResult {
    let refinedText: String
    let teacherExplanation: String
    let vocabularySuggestions: [VocabularySuggestion]
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

        // Build combined prompt that asks for refined text, explanation, and vocabulary suggestions
        let systemPrompt = """
        You are a language optimization assistant and teacher.

        \(optimizationLevel.systemPrompt)
        \(outputStyle.additionalPrompt)

        Your task:
        1. First, optimize the user's text following the guidelines above
        2. Then, provide specific teaching guidance like a teacher giving improvement feedback
        3. Finally, suggest vocabulary words worth learning from this transcription

        Output format (use exactly this structure):
        REFINED_TEXT:
        [Your optimized version here]

        TEACHER_NOTE:
        Score: [X/10]

        Key improvements (max 3 points):
        • [Specific point with before/after example or vocabulary suggestion]
        • [Specific point with before/after example or vocabulary suggestion]
        • [Specific point with before/after example or vocabulary suggestion]

        VOCABULARY_SUGGESTIONS:
        [JSON array of 0-3 vocabulary suggestions]

        Teaching guidelines for TEACHER_NOTE:
        - Give specific, actionable feedback with examples (e.g., "Instead of 'very good', use 'excellent' or 'outstanding' for stronger impact")
        - Show which vocabulary or sentence structure would better express the intended meaning
        - Limit to maximum 3 most important improvement points
        - Provide a score out of 10 for the original text
        - DO NOT give generic comments like "removed filler words" or "improved expression"
        - Focus on WHY a specific word or structure is better for the meaning

        Vocabulary suggestion guidelines:
        - Select 0-3 words from the REFINED text that would benefit English language learners
        - Prioritize: uncommon but useful words, nuanced vocabulary, commonly confused words, eloquent alternatives
        - Exclude: top 1000 most common English words, proper nouns (names/places), slang
        - For each word, provide a JSON object with these fields:
          - word: the vocabulary word
          - partOfSpeech: noun/verb/adjective/adverb/phrase
          - definition: brief definition (1-2 sentences)
          - reason: why this word is worth learning (max 50 words)
          - sourceSentence: the exact sentence from the refined text where this word appears
        - Output as a valid JSON array, or empty array [] if no good vocabulary candidates
        - Example: [{"word": "eloquent", "partOfSpeech": "adjective", "definition": "fluent or persuasive in speaking or writing", "reason": "More expressive than 'well-spoken'", "sourceSentence": "She gave an eloquent presentation."}]

        Important rules:
        - Keep the core meaning and key information
        - Maintain paragraphing if multiple sentences exist
        - Add appropriate punctuation
        """

        let result = try await callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: text,
            temperature: 0.3,
            maxTokens: 2000  // Increased for vocabulary suggestions
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
                teacherExplanation: "No explanation provided",
                vocabularySuggestions: []
            )
        }

        // Extract refined text (between REFINED_TEXT: and TEACHER_NOTE:)
        let refinedStart = trimmed.index(refinedRange.upperBound, offsetBy: 0)
        let refinedEnd = teacherRange.lowerBound
        let refinedText = String(trimmed[refinedStart..<refinedEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if VOCABULARY_SUGGESTIONS marker exists
        let vocabRange = trimmed.range(of: "VOCABULARY_SUGGESTIONS:")

        // Extract teacher note (between TEACHER_NOTE: and VOCABULARY_SUGGESTIONS: if present)
        let teacherStart = trimmed.index(teacherRange.upperBound, offsetBy: 0)
        let teacherEnd = vocabRange?.lowerBound ?? trimmed.endIndex
        let teacherExplanation = String(trimmed[teacherStart..<teacherEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse vocabulary suggestions
        let vocabularySuggestions = parseVocabularySuggestions(from: trimmed, vocabRange: vocabRange)

        return OptimizationResult(
            refinedText: refinedText,
            teacherExplanation: teacherExplanation,
            vocabularySuggestions: vocabularySuggestions
        )
    }

    /// Parse vocabulary suggestions JSON from the LLM response
    /// - Parameters:
    ///   - response: The full LLM response
    ///   - vocabRange: Optional range of the VOCABULARY_SUGGESTIONS marker
    /// - Returns: Array of VocabularySuggestion (empty if parsing fails)
    private func parseVocabularySuggestions(from response: String, vocabRange: Range<String.Index>?) -> [VocabularySuggestion] {
        guard let vocabRange = vocabRange else {
            Logger.info("No VOCABULARY_SUGGESTIONS marker found in response", category: .optimization)
            return []
        }

        // Extract everything after VOCABULARY_SUGGESTIONS:
        let vocabStart = response.index(vocabRange.upperBound, offsetBy: 0)
        var vocabJSON = String(response[vocabStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Clean up the response - remove markdown code blocks if present
        if vocabJSON.hasPrefix("```json") {
            vocabJSON = String(vocabJSON.dropFirst(7))
        } else if vocabJSON.hasPrefix("```") {
            vocabJSON = String(vocabJSON.dropFirst(3))
        }
        if vocabJSON.hasSuffix("```") {
            vocabJSON = String(vocabJSON.dropLast(3))
        }
        vocabJSON = vocabJSON.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the JSON array boundaries
        guard let arrayStart = vocabJSON.firstIndex(of: "["),
              let arrayEnd = vocabJSON.lastIndex(of: "]") else {
            Logger.warning("Could not find JSON array in vocabulary suggestions", category: .optimization)
            return []
        }

        let jsonString = String(vocabJSON[arrayStart...arrayEnd])

        guard let jsonData = jsonString.data(using: .utf8) else {
            Logger.warning("Could not convert vocabulary suggestions to data", category: .optimization)
            return []
        }

        do {
            let suggestions = try JSONDecoder().decode([VocabularySuggestion].self, from: jsonData)
            Logger.info("Parsed \(suggestions.count) vocabulary suggestions", category: .optimization)
            return suggestions.filter { $0.isValid }
        } catch {
            Logger.warning("Failed to parse vocabulary suggestions: \(error)", category: .optimization)
            return []
        }
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


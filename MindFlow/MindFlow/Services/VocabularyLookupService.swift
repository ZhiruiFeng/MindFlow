//
//  VocabularyLookupService.swift
//  MindFlow
//
//  Service for AI-powered vocabulary lookups
//

import Foundation

/// Service for looking up word explanations using AI
class VocabularyLookupService {
    static let shared = VocabularyLookupService()

    private var settings: Settings {
        return Settings.shared
    }

    private init() {
        print("🔧 [VocabularyLookup] Service initialized")
    }

    // MARK: - Public Methods

    /// Look up a word and get AI-generated explanation
    /// - Parameters:
    ///   - word: The word to look up
    ///   - context: Optional context where the word was encountered
    /// - Returns: WordExplanation with comprehensive word information
    func lookupWord(_ word: String, context: String? = nil) async throws -> WordExplanation {
        // Snapshot Settings (an ObservableObject) on the main actor before any
        // background work to avoid a data race.
        let (apiKey, model) = await MainActor.run {
            (settings.openAIKey, settings.llmModel)
        }

        guard !apiKey.isEmpty else {
            throw VocabularyLookupError.missingAPIKey
        }

        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedWord.isEmpty else {
            throw VocabularyLookupError.invalidWord("Word cannot be empty")
        }

        Logger.info("Looking up vocabulary word", category: .vocabulary)

        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(word: trimmedWord, context: context)

        let response = try await callOpenAI(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.3,
            maxTokens: 1200
        )

        let explanation = try parseResponse(response, word: trimmedWord)

        Logger.info("Successfully looked up vocabulary word", category: .vocabulary)
        return explanation
    }

    // MARK: - Private Methods

    private func buildSystemPrompt() -> String {
        return """
        You are a vocabulary assistant helping a Chinese speaker learn English.
        Provide comprehensive word explanations optimized for second-language learners.
        Focus on practical usage, memorable examples, and Chinese-specific learning tips.
        Return ONLY valid JSON without markdown code blocks or any other text.
        """
    }

    private func buildUserPrompt(word: String, context: String?) -> String {
        var prompt = """
        Explain the English word: "\(word)"
        """

        if let context = context, !context.isEmpty {
            prompt += "\nContext where it was used: \"\(context)\""
        }

        prompt += """

        Return JSON with this exact structure:
        {
            "word": "\(word)",
            "phonetic": "IPA pronunciation, e.g., /ˈwɜːrd/",
            "partOfSpeech": "noun/verb/adjective/adverb/etc",
            "definitionEN": "clear English definition",
            "definitionCN": "中文释义",
            "exampleSentences": [
                {"en": "Example sentence in English.", "cn": "中文翻译。"},
                {"en": "Another example.", "cn": "另一个例子。"}
            ],
            "synonyms": ["word1", "word2"],
            "antonyms": ["word1", "word2"],
            "wordFamily": "related forms: noun, verb, adjective, adverb",
            "usageNotes": "context, register, common collocations",
            "etymology": "brief word origin",
            "memoryTips": "mnemonic device for Chinese speakers"
        }
        """

        return prompt
    }

    private func callOpenAI(
        apiKey: String,
        model: LLMModel,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        let endpoint = "https://api.openai.com/v1/chat/completions"

        guard let url = URL(string: endpoint) else {
            throw VocabularyLookupError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        var requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        // GPT-5 family models use `max_completion_tokens` and only support the
        // default temperature, so omit the custom temperature for them.
        if model.isGPT5Family {
            // Reasoning models share the completion-token budget between hidden
            // reasoning tokens and the visible answer. The lookup budget (1200)
            // is easily consumed entirely by reasoning, leaving an empty/truncated
            // response that fails to parse, so request minimal reasoning effort and
            // give a generous budget — matching LLMService.
            requestBody["reasoning_effort"] = "minimal"
            requestBody["max_completion_tokens"] = max(maxTokens, 4000)
        } else {
            requestBody["temperature"] = temperature
            requestBody["max_tokens"] = maxTokens
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VocabularyLookupError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VocabularyLookupError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let responseText = chatResponse.choices.first?.message.content else {
            throw VocabularyLookupError.emptyResponse
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseResponse(_ response: String, word: String) throws -> WordExplanation {
        // Clean up the response - remove markdown code blocks if present
        var cleanedResponse = response
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = String(cleanedResponse.dropFirst(7))
        } else if cleanedResponse.hasPrefix("```") {
            cleanedResponse = String(cleanedResponse.dropFirst(3))
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8) else {
            throw VocabularyLookupError.parseError("Could not convert response to data")
        }

        do {
            let explanation = try JSONDecoder().decode(WordExplanation.self, from: data)
            return explanation
        } catch {
            Logger.warning("JSON parse error: \(error)", category: .vocabulary)
            // Try to extract at least the basic information
            return try parsePartialResponse(cleanedResponse, word: word)
        }
    }

    private func parsePartialResponse(_ response: String, word: String) throws -> WordExplanation {
        // Attempt to create a basic explanation from partial data
        // This is a fallback when full JSON parsing fails

        Logger.warning("Attempting partial parse of vocabulary response", category: .vocabulary)

        // Try to extract definition if present in the response
        var definitionEN: String? = nil
        var definitionCN: String? = nil

        if let defENRange = response.range(of: "\"definitionEN\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = String(response[defENRange])
            if let colonIndex = match.firstIndex(of: ":") {
                definitionEN = String(match[match.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        if let defCNRange = response.range(of: "\"definitionCN\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = String(response[defCNRange])
            if let colonIndex = match.firstIndex(of: ":") {
                definitionCN = String(match[match.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        // If we couldn't extract anything useful, throw an error
        if definitionEN == nil && definitionCN == nil {
            throw VocabularyLookupError.parseError("Could not parse any useful information from response")
        }

        return WordExplanation(
            word: word,
            phonetic: nil,
            partOfSpeech: nil,
            definitionEN: definitionEN,
            definitionCN: definitionCN,
            exampleSentences: nil,
            synonyms: nil,
            antonyms: nil,
            wordFamily: nil,
            usageNotes: nil,
            etymology: nil,
            memoryTips: nil
        )
    }
}

// MARK: - Errors

enum VocabularyLookupError: LocalizedError {
    case missingAPIKey
    case invalidWord(String)
    case invalidResponse
    case apiError(String)
    case emptyResponse
    case parseError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API Key not configured. Please add your API key in Settings."
        case .invalidWord(let message):
            return "Invalid word: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API error: \(message)"
        case .emptyResponse:
            return "API returned empty response"
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

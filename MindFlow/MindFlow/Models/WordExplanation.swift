//
//  WordExplanation.swift
//  MindFlow
//
//  Model for AI-generated word explanations
//

import Foundation

/// Model representing an AI-generated word explanation
struct WordExplanation: Codable, Equatable {
    let word: String
    let phonetic: String?
    let partOfSpeech: String?
    let definitionEN: String?
    let definitionCN: String?
    let exampleSentences: [ExampleSentenceDTO]?
    let synonyms: [String]?
    let antonyms: [String]?
    let wordFamily: String?
    let usageNotes: String?
    let etymology: String?
    let memoryTips: String?

    /// Example sentence with English and Chinese translation
    struct ExampleSentenceDTO: Codable, Equatable {
        let en: String
        let cn: String

        /// Convert to ExampleSentence model
        func toModel() -> ExampleSentence {
            return ExampleSentence(en: en, cn: cn)
        }
    }

    // MARK: - Computed Properties

    /// Convert synonyms array to comma-separated string
    var synonymsString: String? {
        synonyms?.joined(separator: ", ")
    }

    /// Convert antonyms array to comma-separated string
    var antonymsString: String? {
        antonyms?.joined(separator: ", ")
    }

    /// Convert example sentences to model array
    var exampleSentencesModels: [ExampleSentence] {
        exampleSentences?.map { $0.toModel() } ?? []
    }

    /// Encode example sentences to JSON string for Core Data storage
    var exampleSentencesJSON: String? {
        guard let sentences = exampleSentences else { return nil }
        do {
            let models = sentences.map { ExampleSentence(en: $0.en, cn: $0.cn) }
            let data = try JSONEncoder().encode(models)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Validation

extension WordExplanation {
    /// Check if the explanation has minimum required content
    var isValid: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (definitionEN != nil || definitionCN != nil)
    }

    /// Check if this is an empty/placeholder response
    var isEmpty: Bool {
        word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        definitionEN == nil &&
        definitionCN == nil
    }
}

// MARK: - Factory Methods

extension WordExplanation {
    /// Create an empty explanation for manual entry
    static func empty(word: String) -> WordExplanation {
        return WordExplanation(
            word: word,
            phonetic: nil,
            partOfSpeech: nil,
            definitionEN: nil,
            definitionCN: nil,
            exampleSentences: nil,
            synonyms: nil,
            antonyms: nil,
            wordFamily: nil,
            usageNotes: nil,
            etymology: nil,
            memoryTips: nil
        )
    }

    /// Create a sample explanation for testing
    static func sample() -> WordExplanation {
        return WordExplanation(
            word: "eloquent",
            phonetic: "/ˈeləkwənt/",
            partOfSpeech: "adjective",
            definitionEN: "Fluent or persuasive in speaking or writing; clearly expressing feelings or meaning.",
            definitionCN: "雄辩的；有口才的；善于表达的",
            exampleSentences: [
                ExampleSentenceDTO(
                    en: "She gave an eloquent speech at the graduation ceremony.",
                    cn: "她在毕业典礼上发表了一场雄辩的演讲。"
                ),
                ExampleSentenceDTO(
                    en: "His silence was more eloquent than words.",
                    cn: "他的沉默比言语更能说明问题。"
                )
            ],
            synonyms: ["articulate", "fluent", "expressive", "persuasive"],
            antonyms: ["inarticulate", "halting", "tongue-tied"],
            wordFamily: "eloquently (adv), eloquence (n)",
            usageNotes: "Often used to describe speakers, writers, or their works. Can also describe non-verbal expressions.",
            etymology: "From Latin 'eloquens', present participle of 'eloqui' (to speak out)",
            memoryTips: "Think of 'e-' (out) + 'loqu' (speak, like 'loquacious') = speaking out effectively"
        )
    }
}

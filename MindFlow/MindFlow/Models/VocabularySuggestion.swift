//
//  VocabularySuggestion.swift
//  MindFlow
//
//  A vocabulary word suggested for learning from a transcription.
//  This is a transient display model - suggestions are not persisted until saved.
//

import Foundation

/// A vocabulary word suggested for learning from a transcription
struct VocabularySuggestion: Codable, Identifiable, Equatable {
    /// Unique identifier for SwiftUI list rendering (based on word)
    var id: String { word.lowercased() }

    /// The suggested word
    let word: String

    /// Part of speech (noun, verb, adjective, etc.)
    let partOfSpeech: String

    /// Brief definition (1-2 sentences)
    let definition: String

    /// Why this word is worth learning
    let reason: String

    /// The sentence from transcription where word appears
    let sourceSentence: String

    // MARK: - UI State (not from LLM)

    /// Whether this word already exists in user's vocabulary
    var isAlreadySaved: Bool = false

    /// Whether the word is currently being added (loading state)
    var isAdding: Bool = false

    /// Whether the word was just added (success state)
    var wasJustAdded: Bool = false

    /// Full word details fetched on expand (cached)
    var fullDetails: WordExplanation?

    /// Whether full details are currently being fetched
    var isFetchingDetails: Bool = false

    // MARK: - Codable

    /// Only encode/decode the LLM-provided fields
    enum CodingKeys: String, CodingKey {
        case word, partOfSpeech, definition, reason, sourceSentence
    }

    // MARK: - Equatable

    static func == (lhs: VocabularySuggestion, rhs: VocabularySuggestion) -> Bool {
        lhs.word.lowercased() == rhs.word.lowercased() &&
        lhs.partOfSpeech == rhs.partOfSpeech &&
        lhs.definition == rhs.definition &&
        lhs.reason == rhs.reason &&
        lhs.sourceSentence == rhs.sourceSentence &&
        lhs.isAlreadySaved == rhs.isAlreadySaved &&
        lhs.isAdding == rhs.isAdding &&
        lhs.wasJustAdded == rhs.wasJustAdded
    }
}

// MARK: - Validation

extension VocabularySuggestion {
    /// Check if the suggestion has all required fields
    var isValid: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sourceSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

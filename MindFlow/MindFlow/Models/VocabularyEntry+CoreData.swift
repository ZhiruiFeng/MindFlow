//
//  VocabularyEntry+CoreData.swift
//  MindFlow
//
//  Core Data model for vocabulary entries
//

import Foundation
import CoreData

@objc(VocabularyEntry)
public class VocabularyEntry: NSManagedObject {

    // MARK: - Sync Status Enum

    enum SyncStatus: String {
        case pending = "pending"
        case synced = "synced"
        case failed = "failed"
    }

    // MARK: - Mastery Level Enum

    enum MasteryLevel: Int16 {
        case new = 0
        case learning = 1
        case reviewing = 2
        case familiar = 3
        case mastered = 4

        var displayName: String {
            switch self {
            case .new: return "New"
            case .learning: return "Learning"
            case .reviewing: return "Reviewing"
            case .familiar: return "Familiar"
            case .mastered: return "Mastered"
            }
        }

        var color: String {
            switch self {
            case .new: return "gray"
            case .learning: return "red"
            case .reviewing: return "orange"
            case .familiar: return "blue"
            case .mastered: return "green"
            }
        }
    }

    // MARK: - Computed Properties

    /// Typed sync status
    var syncStatusEnum: SyncStatus {
        get {
            return SyncStatus(rawValue: syncStatus ?? "pending") ?? .pending
        }
        set {
            syncStatus = newValue.rawValue
        }
    }

    /// Typed mastery level
    var masteryLevelEnum: MasteryLevel {
        get {
            return MasteryLevel(rawValue: masteryLevel) ?? .new
        }
        set {
            masteryLevel = newValue.rawValue
        }
    }

    /// Check if this entry needs to be synced
    var needsSync: Bool {
        return syncStatusEnum == .pending && backendId == nil
    }

    /// Check if this entry is already synced
    var isSynced: Bool {
        return syncStatusEnum == .synced && backendId != nil
    }

    /// Check if this entry is due for review
    var isDueForReview: Bool {
        guard let nextReview = nextReviewAt else { return false }
        return nextReview <= Date()
    }

    /// Accuracy percentage
    var accuracy: Double {
        guard reviewCount > 0 else { return 0.0 }
        return Double(correctCount) / Double(reviewCount) * 100.0
    }

    /// Parse tags from comma-separated string to array
    var tagsArray: [String] {
        get {
            guard let tags = tags, !tags.isEmpty else { return [] }
            return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ",")
        }
    }

    /// Parse example sentences from JSON string
    var exampleSentencesArray: [ExampleSentence] {
        get {
            guard let jsonString = exampleSentences,
                  let data = jsonString.data(using: .utf8) else { return [] }
            do {
                return try JSONDecoder().decode([ExampleSentence].self, from: data)
            } catch {
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                exampleSentences = String(data: data, encoding: .utf8)
            } catch {
                exampleSentences = nil
            }
        }
    }

    /// Parse synonyms from comma-separated string to array
    var synonymsArray: [String] {
        get {
            guard let synonyms = synonyms, !synonyms.isEmpty else { return [] }
            return synonyms.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            synonyms = newValue.joined(separator: ",")
        }
    }

    /// Parse antonyms from comma-separated string to array
    var antonymsArray: [String] {
        get {
            guard let antonyms = antonyms, !antonyms.isEmpty else { return [] }
            return antonyms.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            antonyms = newValue.joined(separator: ",")
        }
    }
}

// MARK: - Fetch Request

extension VocabularyEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VocabularyEntry> {
        return NSFetchRequest<VocabularyEntry>(entityName: "VocabularyEntry")
    }

    // MARK: - Identity

    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // MARK: - Word Information

    @NSManaged public var word: String
    @NSManaged public var phonetic: String?
    @NSManaged public var partOfSpeech: String?
    @NSManaged public var definitionEN: String?
    @NSManaged public var definitionCN: String?
    @NSManaged public var exampleSentences: String?
    @NSManaged public var synonyms: String?
    @NSManaged public var antonyms: String?
    @NSManaged public var wordFamily: String?
    @NSManaged public var usageNotes: String?
    @NSManaged public var etymology: String?
    @NSManaged public var memoryTips: String?

    // MARK: - Context & Organization

    @NSManaged public var userContext: String?
    @NSManaged public var sourceInteractionId: UUID?
    @NSManaged public var tags: String?
    @NSManaged public var category: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isArchived: Bool

    // MARK: - Spaced Repetition

    @NSManaged public var masteryLevel: Int16
    @NSManaged public var reviewCount: Int32
    @NSManaged public var correctCount: Int32
    @NSManaged public var lastReviewedAt: Date?
    @NSManaged public var nextReviewAt: Date?
    @NSManaged public var easeFactor: Double
    @NSManaged public var interval: Int32

    // MARK: - Sync

    @NSManaged public var syncStatus: String?
    @NSManaged public var backendId: String?
}

// MARK: - Identifiable

extension VocabularyEntry: Identifiable {}

// MARK: - Example Sentence Model

struct ExampleSentence: Codable, Equatable {
    let en: String
    let cn: String
}

//
//  ReviewSession+CoreData.swift
//  MindFlow
//
//  Core Data model for review sessions
//

import Foundation
import CoreData

@objc(ReviewSession)
public class ReviewSession: NSManagedObject {

    // MARK: - Review Mode Enum

    enum ReviewMode: String, CaseIterable {
        case flashcard = "flashcard"
        case reverse = "reverse"
        case context = "context"

        var displayName: String {
            switch self {
            case .flashcard: return "Flashcard"
            case .reverse: return "Reverse"
            case .context: return "Context"
            }
        }

        var description: String {
            switch self {
            case .flashcard: return "Show word, recall meaning"
            case .reverse: return "Show meaning, recall word"
            case .context: return "Show context, recall word"
            }
        }
    }

    // MARK: - Computed Properties

    /// Typed review mode
    var reviewModeEnum: ReviewMode {
        get {
            return ReviewMode(rawValue: reviewMode) ?? .flashcard
        }
        set {
            reviewMode = newValue.rawValue
        }
    }

    /// Whether the session is completed
    var isCompleted: Bool {
        return completedAt != nil
    }

    /// Session accuracy percentage
    var accuracy: Double {
        let answered = correctCount + incorrectCount
        guard answered > 0 else { return 0.0 }
        return Double(correctCount) / Double(answered) * 100.0
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Progress percentage (completed / total)
    var progress: Double {
        guard totalWords > 0 else { return 0.0 }
        let completed = correctCount + incorrectCount + skippedCount
        return Double(completed) / Double(totalWords)
    }
}

// MARK: - Fetch Request

extension ReviewSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReviewSession> {
        return NSFetchRequest<ReviewSession>(entityName: "ReviewSession")
    }

    // MARK: - Identity

    @NSManaged public var id: UUID

    // MARK: - Timing

    @NSManaged public var startedAt: Date
    @NSManaged public var completedAt: Date?
    @NSManaged public var durationSeconds: Int32

    // MARK: - Statistics

    @NSManaged public var totalWords: Int32
    @NSManaged public var correctCount: Int32
    @NSManaged public var incorrectCount: Int32
    @NSManaged public var skippedCount: Int32

    // MARK: - Mode

    @NSManaged public var reviewMode: String
}

// MARK: - Identifiable

extension ReviewSession: Identifiable {}

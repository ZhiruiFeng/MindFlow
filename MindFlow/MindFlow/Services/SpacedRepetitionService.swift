//
//  SpacedRepetitionService.swift
//  MindFlow
//
//  Implementation of SM-2 spaced repetition algorithm
//

import Foundation

/// Service for calculating spaced repetition intervals using the SM-2 algorithm
class SpacedRepetitionService {
    static let shared = SpacedRepetitionService()

    private init() {
        print("🔧 [SpacedRepetition] Service initialized")
    }

    // MARK: - Types

    /// User's self-reported recall quality
    enum ResponseQuality: Int, CaseIterable {
        case forgot = 0     // Complete blackout, couldn't recall at all
        case hard = 1       // Struggled but eventually recalled
        case good = 2       // Recalled correctly with some effort

        var displayName: String {
            switch self {
            case .forgot: return "Forgot"
            case .hard: return "Hard"
            case .good: return "Good"
            }
        }

        var description: String {
            switch self {
            case .forgot: return "Couldn't remember"
            case .hard: return "Struggled to recall"
            case .good: return "Recalled correctly"
            }
        }

        var keyboardShortcut: String {
            switch self {
            case .forgot: return "1"
            case .hard: return "2"
            case .good: return "3"
            }
        }
    }

    /// Result of a review calculation
    struct ReviewResult {
        let nextInterval: Int           // Days until next review
        let newEaseFactor: Double       // Updated ease factor (min 1.3)
        let newMasteryLevel: Int        // Updated mastery level (0-4)
        let nextReviewDate: Date        // Calculated next review date
        let wasCorrect: Bool            // Whether the answer was correct (quality >= 2)
    }

    // MARK: - Public Methods

    /// Calculate the next review based on user's response quality
    /// - Parameters:
    ///   - currentInterval: Current interval in days (0 for new words)
    ///   - easeFactor: Current ease factor (default 2.5)
    ///   - quality: User's self-reported recall quality
    /// - Returns: ReviewResult with updated scheduling parameters
    func calculateNextReview(
        currentInterval: Int,
        easeFactor: Double,
        quality: ResponseQuality
    ) -> ReviewResult {
        var interval = currentInterval
        var ef = easeFactor

        // Ensure ease factor is within bounds
        ef = max(1.3, ef)

        let wasCorrect = quality.rawValue >= 2

        if wasCorrect {
            // Correct response: increase interval
            if interval == 0 {
                // First review: 1 day
                interval = 1
            } else if interval == 1 {
                // Second review: 3 days
                interval = 3
            } else {
                // Subsequent reviews: multiply by ease factor
                interval = Int(round(Double(interval) * ef))
            }

            // Update ease factor based on quality
            // Formula: EF' = EF + (0.1 - (2 - q) * (0.08 + (2 - q) * 0.02))
            // Simplified for our 3-grade scale
            let qualityAdjustment = Double(quality.rawValue - 2)
            ef = ef + (0.1 - (2.0 - Double(quality.rawValue)) * 0.08)
        } else {
            // Incorrect response: reset interval
            interval = 1

            // Decrease ease factor
            ef = ef - 0.2
        }

        // Ensure ease factor doesn't go below minimum
        ef = max(1.3, ef)

        // Calculate mastery level based on interval
        let masteryLevel = calculateMasteryLevel(interval: interval)

        // Calculate next review date
        let nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: interval,
            to: Date()
        ) ?? Date()

        print("📊 [SpacedRepetition] Calculated review:")
        print("   Quality: \(quality.displayName)")
        print("   Interval: \(currentInterval) → \(interval) days")
        print("   Ease: \(String(format: "%.2f", easeFactor)) → \(String(format: "%.2f", ef))")
        print("   Mastery: \(masteryLevel)")

        return ReviewResult(
            nextInterval: interval,
            newEaseFactor: ef,
            newMasteryLevel: masteryLevel,
            nextReviewDate: nextReviewDate,
            wasCorrect: wasCorrect
        )
    }

    /// Calculate mastery level based on current interval
    /// - Parameter interval: Current interval in days
    /// - Returns: Mastery level (0-4)
    func calculateMasteryLevel(interval: Int) -> Int {
        switch interval {
        case 0:
            return 0      // New
        case 1..<7:
            return 1      // Learning
        case 7..<21:
            return 2      // Reviewing
        case 21..<60:
            return 3      // Familiar
        default:
            return 4      // Mastered
        }
    }

    /// Get the mastery level enum from interval
    /// - Parameter interval: Current interval in days
    /// - Returns: VocabularyEntry.MasteryLevel
    func getMasteryLevel(interval: Int) -> VocabularyEntry.MasteryLevel {
        let level = calculateMasteryLevel(interval: interval)
        return VocabularyEntry.MasteryLevel(rawValue: Int16(level)) ?? .new
    }

    /// Calculate estimated review time based on number of words
    /// - Parameter wordCount: Number of words to review
    /// - Returns: Estimated time in minutes
    func estimateReviewTime(wordCount: Int) -> Int {
        // Assume ~15-20 seconds per word on average
        let secondsPerWord = 18
        let totalSeconds = wordCount * secondsPerWord
        return max(1, totalSeconds / 60)
    }

    /// Get words that should be reviewed today from a list
    /// - Parameters:
    ///   - words: Array of vocabulary entries
    ///   - limit: Optional limit on number of words
    /// - Returns: Filtered array of words due for review
    func getWordsDueForReview(from words: [VocabularyEntry], limit: Int? = nil) -> [VocabularyEntry] {
        let now = Date()

        var dueWords = words.filter { entry in
            guard !entry.isArchived else { return false }
            guard let nextReview = entry.nextReviewAt else { return true }
            return nextReview <= now
        }

        // Sort by next review date (oldest first) and mastery level (lower first)
        dueWords.sort { a, b in
            let dateA = a.nextReviewAt ?? Date.distantPast
            let dateB = b.nextReviewAt ?? Date.distantPast
            if dateA == dateB {
                return a.masteryLevel < b.masteryLevel
            }
            return dateA < dateB
        }

        if let limit = limit {
            return Array(dueWords.prefix(limit))
        }

        return dueWords
    }

    /// Calculate overall progress statistics
    /// - Parameter words: Array of vocabulary entries
    /// - Returns: Dictionary with progress statistics
    func calculateProgress(for words: [VocabularyEntry]) -> [String: Any] {
        let activeWords = words.filter { !$0.isArchived }

        let totalWords = activeWords.count
        let masteredWords = activeWords.filter { $0.masteryLevelEnum == .mastered }.count
        let learningWords = activeWords.filter { $0.masteryLevel >= 1 && $0.masteryLevel < 4 }.count
        let newWords = activeWords.filter { $0.masteryLevel == 0 }.count

        let totalReviews = activeWords.reduce(0) { $0 + Int($1.reviewCount) }
        let totalCorrect = activeWords.reduce(0) { $0 + Int($1.correctCount) }
        let accuracy = totalReviews > 0 ? Double(totalCorrect) / Double(totalReviews) * 100 : 0

        let averageEaseFactor = activeWords.isEmpty ? 2.5 :
            activeWords.reduce(0.0) { $0 + $1.easeFactor } / Double(activeWords.count)

        return [
            "totalWords": totalWords,
            "masteredWords": masteredWords,
            "learningWords": learningWords,
            "newWords": newWords,
            "masteryPercentage": totalWords > 0 ? Double(masteredWords) / Double(totalWords) * 100 : 0,
            "totalReviews": totalReviews,
            "accuracy": accuracy,
            "averageEaseFactor": averageEaseFactor
        ]
    }
}

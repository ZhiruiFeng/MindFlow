//
//  ReviewViewModel.swift
//  MindFlow
//
//  ViewModel for review session state management
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing vocabulary review sessions
@MainActor
class ReviewViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current review session
    @Published var session: ReviewSession?

    /// Words to review in this session
    @Published var reviewWords: [VocabularyEntry] = []

    /// Current word index
    @Published var currentIndex: Int = 0

    /// Whether the answer is revealed
    @Published var isAnswerRevealed: Bool = false

    /// Session in progress
    @Published var isSessionActive: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error state
    @Published var error: Error?

    /// Review mode
    @Published var reviewMode: ReviewSession.ReviewMode = .flashcard

    /// Session start time (for duration tracking)
    @Published var sessionStartTime: Date?

    // MARK: - Computed Properties

    /// Current word being reviewed
    var currentWord: VocabularyEntry? {
        guard currentIndex >= 0 && currentIndex < reviewWords.count else { return nil }
        return reviewWords[currentIndex]
    }

    /// Progress percentage (0.0 - 1.0)
    var progress: Double {
        guard !reviewWords.isEmpty else { return 0 }
        return Double(currentIndex) / Double(reviewWords.count)
    }

    /// Number of words remaining
    var remainingWords: Int {
        return max(0, reviewWords.count - currentIndex)
    }

    /// Session statistics
    var correctCount: Int {
        return Int(session?.correctCount ?? 0)
    }

    var incorrectCount: Int {
        return Int(session?.incorrectCount ?? 0)
    }

    var skippedCount: Int {
        return Int(session?.skippedCount ?? 0)
    }

    /// Accuracy percentage
    var accuracy: Double {
        let answered = correctCount + incorrectCount
        guard answered > 0 else { return 0 }
        return Double(correctCount) / Double(answered) * 100
    }

    /// Estimated time remaining in seconds
    var estimatedTimeRemaining: Int {
        return SpacedRepetitionService.shared.estimateReviewTime(wordCount: remainingWords) * 60
    }

    // MARK: - Private Properties

    private let storage = VocabularyStorage.shared
    private let spacedRepetition = SpacedRepetitionService.shared

    // MARK: - Public Methods

    /// Start a new review session
    /// - Parameters:
    ///   - limit: Maximum number of words to review (nil for all due words)
    ///   - mode: Review mode to use
    func startSession(limit: Int? = nil, mode: ReviewSession.ReviewMode = .flashcard) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Fetch words due for review
        let dueWords = storage.fetchWordsDueForReview(limit: limit)

        guard !dueWords.isEmpty else {
            error = ReviewError.noWordsDue
            return
        }

        // Shuffle the words for variety
        reviewWords = dueWords.shuffled()
        reviewMode = mode
        currentIndex = 0
        isAnswerRevealed = false
        sessionStartTime = Date()

        // Create session in storage
        session = storage.createReviewSession(totalWords: reviewWords.count, mode: mode)

        isSessionActive = true

        print("📚 [ReviewVM] Started session with \(reviewWords.count) words")
    }

    /// Start a session with specific words
    /// - Parameters:
    ///   - words: Array of words to review
    ///   - mode: Review mode
    func startSession(with words: [VocabularyEntry], mode: ReviewSession.ReviewMode = .flashcard) async {
        guard !words.isEmpty else {
            error = ReviewError.noWordsDue
            return
        }

        reviewWords = words.shuffled()
        reviewMode = mode
        currentIndex = 0
        isAnswerRevealed = false
        sessionStartTime = Date()

        session = storage.createReviewSession(totalWords: words.count, mode: mode)

        isSessionActive = true

        print("📚 [ReviewVM] Started custom session with \(words.count) words")
    }

    /// Reveal the answer for the current card
    func revealAnswer() {
        isAnswerRevealed = true
    }

    /// Rate the current word and move to next
    /// - Parameter quality: User's recall quality rating
    func rateAndProceed(quality: SpacedRepetitionService.ResponseQuality) {
        guard let word = currentWord, let session = session else { return }

        // Calculate next review using SM-2
        let result = spacedRepetition.calculateNextReview(
            currentInterval: Int(word.interval),
            easeFactor: word.easeFactor,
            quality: quality
        )

        // Update the word in storage
        storage.updateAfterReview(entry: word, result: result)

        // Update session statistics
        if result.wasCorrect {
            session.correctCount += 1
        } else {
            session.incorrectCount += 1
        }

        // Record in daily stats
        storage.recordReview(correct: result.wasCorrect)

        // Move to next word
        moveToNext()

        print("📝 [ReviewVM] Rated '\(word.word)' as \(quality.displayName)")
    }

    /// Skip the current word
    func skipWord() {
        guard let session = session else { return }

        session.skippedCount += 1
        moveToNext()

        print("⏭️ [ReviewVM] Skipped word")
    }

    /// Complete the current session
    func completeSession() {
        guard let session = session else { return }

        // Calculate duration
        if let startTime = sessionStartTime {
            let duration = Int32(Date().timeIntervalSince(startTime))
            storage.addStudyTime(seconds: duration)
        }

        // Complete the session
        storage.completeReviewSession(session)

        isSessionActive = false

        print("✅ [ReviewVM] Session completed")
        print("   ✓ Correct: \(session.correctCount)")
        print("   ✗ Incorrect: \(session.incorrectCount)")
        print("   → Skipped: \(session.skippedCount)")
    }

    /// Cancel the current session
    func cancelSession() {
        if let session = session {
            // Still save partial progress
            storage.completeReviewSession(session)
        }

        resetSession()

        print("❌ [ReviewVM] Session cancelled")
    }

    /// Reset session state
    func resetSession() {
        session = nil
        reviewWords = []
        currentIndex = 0
        isAnswerRevealed = false
        isSessionActive = false
        sessionStartTime = nil
        error = nil
    }

    /// Clear error
    func clearError() {
        error = nil
    }

    /// Get words due for review count
    func getDueCount() -> Int {
        return storage.getDueForReviewCount()
    }

    // MARK: - Private Methods

    private func moveToNext() {
        currentIndex += 1
        isAnswerRevealed = false

        // Check if session is complete
        if currentIndex >= reviewWords.count {
            completeSession()
        }
    }
}

// MARK: - Review Errors

enum ReviewError: LocalizedError {
    case noWordsDue
    case sessionNotActive
    case invalidWord

    var errorDescription: String? {
        switch self {
        case .noWordsDue:
            return "No words are due for review. Great job keeping up!"
        case .sessionNotActive:
            return "No active review session"
        case .invalidWord:
            return "Invalid word for review"
        }
    }
}

//
//  VocabularyStorage.swift
//  MindFlow
//
//  Service for managing vocabulary storage with Core Data
//

import Foundation
import CoreData

/// Service for vocabulary storage and retrieval
class VocabularyStorage {
    static let shared = VocabularyStorage()

    private let coreData = CoreDataManager.shared

    private init() {
        print("🔧 [VocabularyStorage] Service initialized")
    }

    // MARK: - Create

    /// Save a new vocabulary entry from AI explanation
    /// - Parameters:
    ///   - explanation: The AI-generated word explanation
    ///   - userContext: Optional user-provided context
    ///   - category: Optional category for the word
    ///   - sourceInteractionId: Optional link to transcription source
    /// - Returns: The created VocabularyEntry object
    @discardableResult
    func addWord(
        from explanation: WordExplanation,
        userContext: String? = nil,
        category: String? = nil,
        sourceInteractionId: UUID? = nil
    ) -> VocabularyEntry {
        let context = coreData.viewContext
        let entry = VocabularyEntry(context: context)

        // Identity
        entry.id = UUID()
        entry.createdAt = Date()
        entry.updatedAt = Date()

        // Word information
        entry.word = explanation.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        entry.phonetic = explanation.phonetic
        entry.partOfSpeech = explanation.partOfSpeech
        entry.definitionEN = explanation.definitionEN
        entry.definitionCN = explanation.definitionCN
        entry.exampleSentences = explanation.exampleSentencesJSON
        entry.synonyms = explanation.synonymsString
        entry.antonyms = explanation.antonymsString
        entry.wordFamily = explanation.wordFamily
        entry.usageNotes = explanation.usageNotes
        entry.etymology = explanation.etymology
        entry.memoryTips = explanation.memoryTips

        // Context & organization
        entry.userContext = userContext
        entry.sourceInteractionId = sourceInteractionId
        entry.category = category ?? Settings.shared.vocabularyDefaultCategory
        entry.tags = nil
        entry.isFavorite = false
        entry.isArchived = false

        // Spaced repetition - initialize with defaults
        entry.masteryLevel = 0
        entry.reviewCount = 0
        entry.correctCount = 0
        entry.lastReviewedAt = nil
        entry.nextReviewAt = Date() // Due for review immediately
        entry.easeFactor = 2.5
        entry.interval = 0

        // Sync status
        entry.syncStatus = VocabularyEntry.SyncStatus.pending.rawValue
        entry.backendId = nil

        coreData.saveContext()

        print("💾 [VocabularyStorage] Word saved: \(entry.word)")
        print("   📝 ID: \(entry.id)")

        return entry
    }

    /// Create a vocabulary entry with manual input (no AI explanation)
    /// - Parameters:
    ///   - word: The word to add
    ///   - definitionEN: Optional English definition
    ///   - definitionCN: Optional Chinese definition
    ///   - userContext: Optional context
    ///   - category: Optional category
    /// - Returns: The created VocabularyEntry object
    @discardableResult
    func addWordManually(
        word: String,
        definitionEN: String? = nil,
        definitionCN: String? = nil,
        userContext: String? = nil,
        category: String? = nil
    ) -> VocabularyEntry {
        let context = coreData.viewContext
        let entry = VocabularyEntry(context: context)

        // Identity
        entry.id = UUID()
        entry.createdAt = Date()
        entry.updatedAt = Date()

        // Word information
        entry.word = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        entry.definitionEN = definitionEN
        entry.definitionCN = definitionCN

        // Context & organization
        entry.userContext = userContext
        entry.category = category ?? Settings.shared.vocabularyDefaultCategory
        entry.isFavorite = false
        entry.isArchived = false

        // Spaced repetition defaults
        entry.masteryLevel = 0
        entry.reviewCount = 0
        entry.correctCount = 0
        entry.nextReviewAt = Date()
        entry.easeFactor = 2.5
        entry.interval = 0

        // Sync status
        entry.syncStatus = VocabularyEntry.SyncStatus.pending.rawValue

        coreData.saveContext()

        print("💾 [VocabularyStorage] Word saved manually: \(entry.word)")

        return entry
    }

    /// Create a vocabulary entry with full parameters
    /// - Parameters:
    ///   - word: The word to add
    ///   - phonetic: Optional phonetic pronunciation
    ///   - partOfSpeech: Optional part of speech
    ///   - definitionEN: Optional English definition
    ///   - definitionCN: Optional Chinese definition
    ///   - examples: Example sentences
    ///   - synonyms: List of synonyms
    ///   - antonyms: List of antonyms
    ///   - userContext: Optional context
    ///   - category: Optional category
    ///   - tags: Optional tags
    ///   - sourceInteractionId: Optional link to transcription source
    /// - Throws: Error if save fails
    /// - Returns: The created VocabularyEntry object
    @discardableResult
    func addWord(
        word: String,
        phonetic: String? = nil,
        partOfSpeech: String? = nil,
        definitionEN: String? = nil,
        definitionCN: String? = nil,
        examples: [ExampleSentence] = [],
        synonyms: [String] = [],
        antonyms: [String] = [],
        userContext: String? = nil,
        category: String? = nil,
        tags: [String]? = nil,
        sourceInteractionId: UUID? = nil
    ) throws -> VocabularyEntry {
        let context = coreData.viewContext
        let entry = VocabularyEntry(context: context)

        // Identity
        entry.id = UUID()
        entry.createdAt = Date()
        entry.updatedAt = Date()

        // Word information
        entry.word = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        entry.phonetic = phonetic
        entry.partOfSpeech = partOfSpeech
        entry.definitionEN = definitionEN
        entry.definitionCN = definitionCN

        // Examples - store directly using the computed property
        if !examples.isEmpty {
            entry.exampleSentencesArray = examples
        }

        // Synonyms and antonyms
        entry.synonyms = synonyms.isEmpty ? nil : synonyms.joined(separator: ",")
        entry.antonyms = antonyms.isEmpty ? nil : antonyms.joined(separator: ",")

        // Context & organization
        entry.userContext = userContext
        entry.sourceInteractionId = sourceInteractionId
        entry.category = category ?? Settings.shared.vocabularyDefaultCategory
        entry.tags = tags?.joined(separator: ",")
        entry.isFavorite = false
        entry.isArchived = false

        // Spaced repetition defaults
        entry.masteryLevel = 0
        entry.reviewCount = 0
        entry.correctCount = 0
        entry.nextReviewAt = Date()
        entry.easeFactor = 2.5
        entry.interval = 0

        // Sync status
        entry.syncStatus = VocabularyEntry.SyncStatus.pending.rawValue

        coreData.saveContext()

        print("💾 [VocabularyStorage] Word saved with full params: \(entry.word)")

        return entry
    }

    // MARK: - Read

    /// Fetch all vocabulary entries sorted by creation date (newest first)
    /// - Parameters:
    ///   - includeArchived: Whether to include archived entries
    /// - Returns: Array of VocabularyEntry objects
    func fetchAllWords(includeArchived: Bool = false) -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        if !includeArchived {
            request.predicate = NSPredicate(format: "isArchived == NO")
        }

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("📋 [VocabularyStorage] Fetched \(entries.count) words")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch vocabulary entries with pagination
    /// - Parameters:
    ///   - limit: Maximum number of entries to fetch
    ///   - offset: Number of entries to skip
    ///   - includeArchived: Whether to include archived entries
    /// - Returns: Array of VocabularyEntry objects
    func fetchWords(limit: Int, offset: Int, includeArchived: Bool = false) -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        request.fetchOffset = offset

        if !includeArchived {
            request.predicate = NSPredicate(format: "isArchived == NO")
        }

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("📋 [VocabularyStorage] Fetched \(entries.count) words (limit: \(limit), offset: \(offset))")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single entry by ID
    /// - Parameter id: The UUID of the entry
    /// - Returns: VocabularyEntry if found, nil otherwise
    func fetchWord(by id: UUID) -> VocabularyEntry? {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let entries = try coreData.viewContext.fetch(request)
            return entries.first
        } catch {
            print("❌ [VocabularyStorage] Fetch by ID error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch entry by word text (case-insensitive)
    /// - Parameter word: The word to search for
    /// - Returns: VocabularyEntry if found, nil otherwise
    func fetchWord(byText word: String) -> VocabularyEntry? {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "word ==[c] %@", word.trimmingCharacters(in: .whitespacesAndNewlines))
        request.fetchLimit = 1

        do {
            let entries = try coreData.viewContext.fetch(request)
            return entries.first
        } catch {
            print("❌ [VocabularyStorage] Fetch by word error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if a word already exists in vocabulary
    /// - Parameter word: The word to check
    /// - Returns: True if word exists
    func wordExists(_ word: String) -> Bool {
        return fetchWord(byText: word) != nil
    }

    /// Search words by query (searches word, definitions, tags)
    /// - Parameter query: Search query string
    /// - Returns: Array of matching VocabularyEntry objects
    func searchWords(_ query: String) -> [VocabularyEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return fetchAllWords()
        }

        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "isArchived == NO AND (word CONTAINS[cd] %@ OR definitionEN CONTAINS[cd] %@ OR definitionCN CONTAINS[cd] %@ OR tags CONTAINS[cd] %@)",
            trimmedQuery, trimmedQuery, trimmedQuery, trimmedQuery
        )
        request.sortDescriptors = [NSSortDescriptor(key: "word", ascending: true)]

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("🔍 [VocabularyStorage] Search '\(trimmedQuery)' found \(entries.count) results")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Search error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch words by category
    /// - Parameter category: Category name
    /// - Returns: Array of VocabularyEntry objects in that category
    func fetchWordsByCategory(_ category: String) -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(key: "word", ascending: true)]

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("📂 [VocabularyStorage] Category '\(category)' has \(entries.count) words")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch by category error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch words due for review
    /// - Parameter limit: Optional limit on number of words to return
    /// - Returns: Array of VocabularyEntry objects due for review
    func fetchWordsDueForReview(limit: Int? = nil) -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "isArchived == NO AND (nextReviewAt == nil OR nextReviewAt <= %@)",
            Date() as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(key: "nextReviewAt", ascending: true)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("📚 [VocabularyStorage] \(entries.count) words due for review")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch due for review error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch favorite words
    /// - Returns: Array of favorite VocabularyEntry objects
    func fetchFavorites() -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "word", ascending: true)]

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("⭐ [VocabularyStorage] \(entries.count) favorite words")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch favorites error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch words by mastery level
    /// - Parameter level: Mastery level (0-4)
    /// - Returns: Array of VocabularyEntry objects at that mastery level
    func fetchWordsByMasteryLevel(_ level: VocabularyEntry.MasteryLevel) -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND masteryLevel == %d", level.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "word", ascending: true)]

        do {
            let entries = try coreData.viewContext.fetch(request)
            print("📊 [VocabularyStorage] \(entries.count) words at \(level.displayName) level")
            return entries
        } catch {
            print("❌ [VocabularyStorage] Fetch by mastery error: \(error.localizedDescription)")
            return []
        }
    }

    /// Get all unique categories
    /// - Returns: Array of category names
    func fetchAllCategories() -> [String] {
        let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "VocabularyEntry")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["category"]
        request.returnsDistinctResults = true
        request.predicate = NSPredicate(format: "category != nil AND category != ''")

        do {
            let results = try coreData.viewContext.fetch(request)
            let categories = results.compactMap { $0["category"] as? String }
            print("📁 [VocabularyStorage] Found \(categories.count) categories")
            return categories.sorted()
        } catch {
            print("❌ [VocabularyStorage] Fetch categories error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Update

    /// Update a vocabulary entry after review
    /// - Parameters:
    ///   - entry: The entry to update
    ///   - result: The spaced repetition result
    func updateAfterReview(entry: VocabularyEntry, result: SpacedRepetitionService.ReviewResult) {
        entry.reviewCount += 1
        if result.newMasteryLevel >= 0 {
            entry.correctCount += 1
        }
        entry.lastReviewedAt = Date()
        entry.nextReviewAt = result.nextReviewDate
        entry.easeFactor = result.newEaseFactor
        entry.interval = Int32(result.nextInterval)
        entry.masteryLevel = Int16(result.newMasteryLevel)
        entry.updatedAt = Date()
        entry.syncStatusEnum = .pending

        coreData.saveContext()

        print("📝 [VocabularyStorage] Updated after review: \(entry.word)")
        print("   📅 Next review: \(entry.nextReviewAt?.description ?? "nil")")
        print("   📊 Mastery: \(entry.masteryLevelEnum.displayName)")
    }

    /// Update entry metadata (tags, category, favorite status)
    /// - Parameters:
    ///   - entry: The entry to update
    ///   - tags: New tags (optional)
    ///   - category: New category (optional)
    ///   - isFavorite: New favorite status (optional)
    ///   - userContext: New user context (optional)
    func updateMetadata(
        entry: VocabularyEntry,
        tags: [String]? = nil,
        category: String? = nil,
        isFavorite: Bool? = nil,
        userContext: String? = nil
    ) {
        if let tags = tags {
            entry.tagsArray = tags
        }
        if let category = category {
            entry.category = category
        }
        if let isFavorite = isFavorite {
            entry.isFavorite = isFavorite
        }
        if let userContext = userContext {
            entry.userContext = userContext
        }

        entry.updatedAt = Date()
        entry.syncStatusEnum = .pending

        coreData.saveContext()

        print("📝 [VocabularyStorage] Metadata updated: \(entry.word)")
    }

    /// Toggle favorite status
    /// - Parameter entry: The entry to toggle
    func toggleFavorite(entry: VocabularyEntry) {
        entry.isFavorite.toggle()
        entry.updatedAt = Date()
        entry.syncStatusEnum = .pending
        coreData.saveContext()

        print("⭐ [VocabularyStorage] Favorite toggled for \(entry.word): \(entry.isFavorite)")
    }

    /// Archive/unarchive an entry (soft delete)
    /// - Parameters:
    ///   - entry: The entry to archive
    ///   - archived: Whether to archive or unarchive
    func setArchived(entry: VocabularyEntry, archived: Bool) {
        entry.isArchived = archived
        entry.updatedAt = Date()
        entry.syncStatusEnum = .pending
        coreData.saveContext()

        print("📦 [VocabularyStorage] Archive status for \(entry.word): \(archived)")
    }

    // MARK: - Delete

    /// Permanently delete a vocabulary entry
    /// - Parameter entry: The entry to delete
    func deleteWord(_ entry: VocabularyEntry) {
        let word = entry.word
        coreData.viewContext.delete(entry)
        coreData.saveContext()

        print("🗑️ [VocabularyStorage] Word deleted: \(word)")
    }

    /// Delete all vocabulary entries (use with caution!)
    func deleteAllWords() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VocabularyEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try coreData.viewContext.execute(deleteRequest)
            coreData.saveContext()
            print("🗑️ [VocabularyStorage] All words deleted")
        } catch {
            print("❌ [VocabularyStorage] Delete all error: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    /// Get total word count
    /// - Parameter includeArchived: Whether to include archived words
    /// - Returns: Total number of words
    func getWordCount(includeArchived: Bool = false) -> Int {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        if !includeArchived {
            request.predicate = NSPredicate(format: "isArchived == NO")
        }

        do {
            let count = try coreData.viewContext.count(for: request)
            return count
        } catch {
            print("❌ [VocabularyStorage] Count error: \(error.localizedDescription)")
            return 0
        }
    }

    /// Get count of words due for review
    /// - Returns: Number of words due for review
    func getDueForReviewCount() -> Int {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "isArchived == NO AND (nextReviewAt == nil OR nextReviewAt <= %@)",
            Date() as CVarArg
        )

        do {
            let count = try coreData.viewContext.count(for: request)
            return count
        } catch {
            print("❌ [VocabularyStorage] Due count error: \(error.localizedDescription)")
            return 0
        }
    }

    /// Get word counts by mastery level
    /// - Returns: Dictionary with counts for each mastery level
    func getCountsByMasteryLevel() -> [VocabularyEntry.MasteryLevel: Int] {
        var counts: [VocabularyEntry.MasteryLevel: Int] = [:]

        for level in [VocabularyEntry.MasteryLevel.new, .learning, .reviewing, .familiar, .mastered] {
            let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
            request.predicate = NSPredicate(format: "isArchived == NO AND masteryLevel == %d", level.rawValue)

            do {
                let count = try coreData.viewContext.count(for: request)
                counts[level] = count
            } catch {
                print("❌ [VocabularyStorage] Count error for \(level.displayName): \(error)")
                counts[level] = 0
            }
        }

        print("📊 [VocabularyStorage] Mastery counts: \(counts)")
        return counts
    }

    // MARK: - Learning Stats

    /// Get or create today's learning stats
    /// - Returns: LearningStats for today
    func getOrCreateTodayStats() -> LearningStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let request: NSFetchRequest<LearningStats> = LearningStats.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@",
            startOfDay as CVarArg,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as CVarArg
        )
        request.fetchLimit = 1

        do {
            if let existing = try coreData.viewContext.fetch(request).first {
                return existing
            }
        } catch {
            print("❌ [VocabularyStorage] Fetch today stats error: \(error.localizedDescription)")
        }

        // Create new stats for today
        let stats = LearningStats(context: coreData.viewContext)
        stats.id = UUID()
        stats.date = startOfDay
        stats.wordsAdded = 0
        stats.wordsReviewed = 0
        stats.correctReviews = 0
        stats.incorrectReviews = 0
        stats.studyTimeSeconds = 0
        stats.streakDays = calculateStreak()

        coreData.saveContext()
        print("📊 [VocabularyStorage] Created today's stats")

        return stats
    }

    /// Update daily stats after adding a word
    func incrementWordsAdded() {
        let stats = getOrCreateTodayStats()
        stats.wordsAdded += 1
        coreData.saveContext()
    }

    /// Update daily stats after a review
    /// - Parameter correct: Whether the review was correct
    func recordReview(correct: Bool) {
        let stats = getOrCreateTodayStats()
        stats.wordsReviewed += 1
        if correct {
            stats.correctReviews += 1
        } else {
            stats.incorrectReviews += 1
        }
        coreData.saveContext()
    }

    /// Add study time to today's stats
    /// - Parameter seconds: Seconds to add
    func addStudyTime(seconds: Int32) {
        let stats = getOrCreateTodayStats()
        stats.studyTimeSeconds += seconds
        coreData.saveContext()
    }

    /// Calculate current streak
    /// - Returns: Number of consecutive days with activity
    func calculateStreak() -> Int32 {
        let request: NSFetchRequest<LearningStats> = LearningStats.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 365 // Max 1 year of history

        do {
            let allStats = try coreData.viewContext.fetch(request)
            var streak: Int32 = 0
            let calendar = Calendar.current
            var expectedDate = calendar.startOfDay(for: Date())

            for stats in allStats {
                let statsDate = calendar.startOfDay(for: stats.date)
                if statsDate == expectedDate && stats.hasActivity {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                } else if statsDate < expectedDate {
                    break
                }
            }

            return streak
        } catch {
            print("❌ [VocabularyStorage] Streak calculation error: \(error.localizedDescription)")
            return 0
        }
    }

    /// Fetch learning stats for a date range
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    /// - Returns: Array of LearningStats objects
    func fetchStats(from startDate: Date, to endDate: Date) -> [LearningStats] {
        let request: NSFetchRequest<LearningStats> = LearningStats.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
            startDate as CVarArg, endDate as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            return try coreData.viewContext.fetch(request)
        } catch {
            print("❌ [VocabularyStorage] Fetch stats error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Review Session

    /// Create a new review session
    /// - Parameters:
    ///   - totalWords: Number of words in the session
    ///   - mode: Review mode
    /// - Returns: The created ReviewSession object
    @discardableResult
    func createReviewSession(totalWords: Int, mode: ReviewSession.ReviewMode) -> ReviewSession {
        let context = coreData.viewContext
        let session = ReviewSession(context: context)

        session.id = UUID()
        session.startedAt = Date()
        session.totalWords = Int32(totalWords)
        session.reviewMode = mode.rawValue
        session.correctCount = 0
        session.incorrectCount = 0
        session.skippedCount = 0
        session.durationSeconds = 0

        coreData.saveContext()
        print("📚 [VocabularyStorage] Review session started with \(totalWords) words")

        return session
    }

    /// Complete a review session
    /// - Parameter session: The session to complete
    func completeReviewSession(_ session: ReviewSession) {
        session.completedAt = Date()
        if let startedAt = session.startedAt as Date? {
            session.durationSeconds = Int32(Date().timeIntervalSince(startedAt))
        }

        coreData.saveContext()
        print("✅ [VocabularyStorage] Review session completed")
        print("   ✓ Correct: \(session.correctCount)")
        print("   ✗ Incorrect: \(session.incorrectCount)")
        print("   → Skipped: \(session.skippedCount)")
    }

    /// Fetch recent review sessions
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of ReviewSession objects
    func fetchRecentSessions(limit: Int = 10) -> [ReviewSession] {
        let request: NSFetchRequest<ReviewSession> = ReviewSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = limit

        do {
            return try coreData.viewContext.fetch(request)
        } catch {
            print("❌ [VocabularyStorage] Fetch sessions error: \(error.localizedDescription)")
            return []
        }
    }
}

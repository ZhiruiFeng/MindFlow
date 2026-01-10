//
//  VocabularyViewModel.swift
//  MindFlow
//
//  ViewModel for vocabulary list state management
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing vocabulary list state
@MainActor
class VocabularyViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All vocabulary entries (filtered based on current state)
    @Published var words: [VocabularyEntry] = []

    /// Current search query
    @Published var searchText: String = ""

    /// Selected category filter
    @Published var selectedCategory: String?

    /// Selected mastery level filter
    @Published var selectedMasteryLevel: VocabularyEntry.MasteryLevel?

    /// Show only favorites
    @Published var showFavoritesOnly: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Current error (if any)
    @Published var error: Error?

    /// Number of words due for review
    @Published var dueForReviewCount: Int = 0

    /// All unique categories
    @Published var categories: [String] = []

    /// Word counts by mastery level
    @Published var masteryLevelCounts: [VocabularyEntry.MasteryLevel: Int] = [:]

    /// Total word count
    @Published var totalWordCount: Int = 0

    /// Current word being looked up (for loading state)
    @Published var lookingUpWord: String?

    /// Last lookup result (for display)
    @Published var lastLookupResult: WordExplanation?

    // MARK: - Private Properties

    private let storage = VocabularyStorage.shared
    private let lookupService = VocabularyLookupService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.performSearch()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Load all words and refresh statistics
    func loadWords() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            // Fetch words based on current filters
            if showFavoritesOnly {
                words = storage.fetchFavorites()
            } else if let category = selectedCategory {
                words = storage.fetchWordsByCategory(category)
            } else if let level = selectedMasteryLevel {
                words = storage.fetchWordsByMasteryLevel(level)
            } else if !searchText.isEmpty {
                words = storage.searchWords(searchText)
            } else {
                words = storage.fetchAllWords()
            }

            // Refresh statistics
            await refreshStatistics()

            print("📋 [VocabularyVM] Loaded \(words.count) words")
        } catch {
            self.error = error
            print("❌ [VocabularyVM] Load error: \(error.localizedDescription)")
        }
    }

    /// Refresh statistics without reloading words
    func refreshStatistics() async {
        dueForReviewCount = storage.getDueForReviewCount()
        categories = storage.fetchAllCategories()
        masteryLevelCounts = storage.getCountsByMasteryLevel()
        totalWordCount = storage.getWordCount()
    }

    /// Look up a word using AI and add to vocabulary
    /// - Parameters:
    ///   - word: The word to look up
    ///   - context: Optional context
    ///   - category: Optional category
    func lookupAndAddWord(_ word: String, context: String? = nil, category: String? = nil) async {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedWord.isEmpty else {
            error = VocabularyLookupError.invalidWord("Word cannot be empty")
            return
        }

        // Check for duplicates
        if storage.wordExists(trimmedWord) {
            error = VocabularyError.duplicateWord(trimmedWord)
            return
        }

        isLoading = true
        lookingUpWord = trimmedWord
        error = nil

        defer {
            isLoading = false
            lookingUpWord = nil
        }

        do {
            // Look up the word
            let explanation = try await lookupService.lookupWord(trimmedWord, context: context)
            lastLookupResult = explanation

            // Save to storage
            storage.addWord(from: explanation, userContext: context, category: category)

            // Update statistics
            storage.incrementWordsAdded()

            // Reload words
            await loadWords()

            print("✅ [VocabularyVM] Added word: \(trimmedWord)")
        } catch {
            self.error = error
            print("❌ [VocabularyVM] Lookup error: \(error.localizedDescription)")
        }
    }

    /// Add a word manually without AI lookup
    /// - Parameters:
    ///   - word: The word to add
    ///   - definitionEN: English definition
    ///   - definitionCN: Chinese definition
    ///   - context: Optional context
    ///   - category: Optional category
    func addWordManually(
        _ word: String,
        definitionEN: String? = nil,
        definitionCN: String? = nil,
        context: String? = nil,
        category: String? = nil
    ) async {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedWord.isEmpty else {
            error = VocabularyLookupError.invalidWord("Word cannot be empty")
            return
        }

        // Check for duplicates
        if storage.wordExists(trimmedWord) {
            error = VocabularyError.duplicateWord(trimmedWord)
            return
        }

        storage.addWordManually(
            word: trimmedWord,
            definitionEN: definitionEN,
            definitionCN: definitionCN,
            userContext: context,
            category: category
        )

        storage.incrementWordsAdded()
        await loadWords()

        print("✅ [VocabularyVM] Added word manually: \(trimmedWord)")
    }

    /// Delete a word
    /// - Parameter entry: The word to delete
    func deleteWord(_ entry: VocabularyEntry) async {
        storage.deleteWord(entry)
        await loadWords()
    }

    /// Toggle favorite status
    /// - Parameter entry: The word to toggle
    func toggleFavorite(_ entry: VocabularyEntry) {
        storage.toggleFavorite(entry: entry)
        // Update local state
        if let index = words.firstIndex(where: { $0.id == entry.id }) {
            objectWillChange.send()
        }
    }

    /// Archive a word (soft delete)
    /// - Parameter entry: The word to archive
    func archiveWord(_ entry: VocabularyEntry) async {
        storage.setArchived(entry: entry, archived: true)
        await loadWords()
    }

    /// Update word metadata
    /// - Parameters:
    ///   - entry: The word to update
    ///   - tags: New tags
    ///   - category: New category
    ///   - userContext: New context
    func updateWordMetadata(
        _ entry: VocabularyEntry,
        tags: [String]? = nil,
        category: String? = nil,
        userContext: String? = nil
    ) {
        storage.updateMetadata(
            entry: entry,
            tags: tags,
            category: category,
            userContext: userContext
        )
        objectWillChange.send()
    }

    /// Apply category filter
    /// - Parameter category: Category to filter by (nil to clear filter)
    func filterByCategory(_ category: String?) async {
        selectedCategory = category
        selectedMasteryLevel = nil
        showFavoritesOnly = false
        await loadWords()
    }

    /// Apply mastery level filter
    /// - Parameter level: Mastery level to filter by (nil to clear filter)
    func filterByMasteryLevel(_ level: VocabularyEntry.MasteryLevel?) async {
        selectedMasteryLevel = level
        selectedCategory = nil
        showFavoritesOnly = false
        await loadWords()
    }

    /// Toggle favorites filter
    func toggleFavoritesFilter() async {
        showFavoritesOnly.toggle()
        if showFavoritesOnly {
            selectedCategory = nil
            selectedMasteryLevel = nil
        }
        await loadWords()
    }

    /// Clear all filters
    func clearFilters() async {
        selectedCategory = nil
        selectedMasteryLevel = nil
        showFavoritesOnly = false
        searchText = ""
        await loadWords()
    }

    /// Clear error state
    func clearError() {
        error = nil
    }

    // MARK: - Private Methods

    private func performSearch() async {
        if !searchText.isEmpty {
            words = storage.searchWords(searchText)
        } else if selectedCategory == nil && selectedMasteryLevel == nil && !showFavoritesOnly {
            words = storage.fetchAllWords()
        }
    }
}

// MARK: - Vocabulary Errors

enum VocabularyError: LocalizedError {
    case duplicateWord(String)
    case wordNotFound(String)
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .duplicateWord(let word):
            return "'\(word)' already exists in your vocabulary"
        case .wordNotFound(let word):
            return "Could not find '\(word)'"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

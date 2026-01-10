# Quickstart: Vocabulary Learning Feature

**Feature**: 001-vocabulary-learning
**Date**: 2026-01-09

## Overview

This guide helps developers get started implementing the vocabulary learning feature for MindFlow. It covers the macOS app (Swift/SwiftUI) and Chrome extension (JavaScript) implementations.

---

## Prerequisites

### macOS Development
- Xcode 14+ with Swift 5.0
- macOS 12+ target
- Existing MindFlow project cloned and building

### Chrome Extension Development
- Node.js 18+
- Chrome browser for testing
- Existing MindFlow-Extension project

### API Access
- OpenAI API key (for word explanations)
- Supabase project (optional, for cloud sync)

---

## Quick Implementation Guide

### Phase 1: Core Data Layer (macOS)

**Step 1: Add Core Data entities**

Create new model version `MindFlow 2.xcdatamodel` with entities:

```
VocabularyEntry:
├── id: UUID
├── word: String (indexed)
├── phonetic, partOfSpeech, definitionEN, definitionCN: String
├── exampleSentences: String (JSON)
├── synonyms, antonyms, wordFamily, usageNotes, etymology, memoryTips: String
├── userContext, tags, category: String
├── isFavorite, isArchived: Boolean
├── masteryLevel: Int16, reviewCount, correctCount: Int32
├── lastReviewedAt, nextReviewAt: Date (indexed)
├── easeFactor: Double, interval: Int32
├── createdAt, updatedAt: Date
└── syncStatus, backendId: String

ReviewSession:
├── id, startedAt, completedAt, totalWords
├── correctCount, incorrectCount, skippedCount
├── reviewMode, durationSeconds

LearningStats:
├── id, date (unique), wordsAdded, wordsReviewed
├── correctReviews, incorrectReviews
├── studyTimeSeconds, streakDays
```

**Step 2: Create VocabularyStorage service**

```swift
// MindFlow/Storage/VocabularyStorage.swift
import CoreData

class VocabularyStorage {
    static let shared = VocabularyStorage()
    private let coreDataManager = CoreDataManager.shared

    // CRUD Operations
    func addWord(_ data: WordExplanation, context: String? = nil) async throws -> VocabularyEntry
    func getWord(by id: UUID) async throws -> VocabularyEntry?
    func getWordByText(_ word: String) async throws -> VocabularyEntry?
    func updateWord(_ entry: VocabularyEntry, with data: VocabularyEntryUpdate) async throws
    func deleteWord(_ entry: VocabularyEntry) async throws

    // Queries
    func getAllWords(limit: Int? = nil, offset: Int? = nil) async throws -> [VocabularyEntry]
    func searchWords(_ query: String) async throws -> [VocabularyEntry]
    func getWordsByCategory(_ category: String) async throws -> [VocabularyEntry]
    func getWordsDueForReview() async throws -> [VocabularyEntry]
    func getFavorites() async throws -> [VocabularyEntry]

    // Statistics
    func getWordCount() async throws -> Int
    func getCountByMasteryLevel() async throws -> [Int: Int]
}
```

### Phase 2: AI Lookup Service

**Step 3: Create VocabularyLookupService**

```swift
// MindFlow/Services/VocabularyLookupService.swift
import Foundation

class VocabularyLookupService {
    static let shared = VocabularyLookupService()
    private let llmService = LLMService.shared

    func lookupWord(_ word: String, context: String? = nil) async throws -> WordExplanation {
        let systemPrompt = """
        You are a vocabulary assistant helping a Chinese speaker learn English.
        Return ONLY valid JSON without markdown code blocks.
        """

        let userPrompt = """
        Explain the English word: "\(word)"
        \(context.map { "Context: \($0)" } ?? "")

        Return JSON: {"word":"","phonetic":"","partOfSpeech":"","definitionEN":"",
        "definitionCN":"","exampleSentences":[{"en":"","cn":""}],"synonyms":[],
        "antonyms":[],"wordFamily":"","usageNotes":"","etymology":"","memoryTips":""}
        """

        let response = try await llmService.callOpenAI(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.3,
            maxTokens: 1000
        )

        return try JSONDecoder().decode(WordExplanation.self, from: Data(response.utf8))
    }
}
```

### Phase 3: Spaced Repetition Service

**Step 4: Implement SM-2 algorithm**

```swift
// MindFlow/Services/SpacedRepetitionService.swift
import Foundation

class SpacedRepetitionService {
    static let shared = SpacedRepetitionService()

    enum ResponseQuality: Int {
        case forgot = 0
        case hard = 1
        case good = 2
    }

    struct ReviewResult {
        let nextInterval: Int
        let newEaseFactor: Double
        let newMasteryLevel: Int
        let nextReviewDate: Date
    }

    func calculateNextReview(
        currentInterval: Int,
        easeFactor: Double,
        quality: ResponseQuality
    ) -> ReviewResult {
        var interval = currentInterval
        var ef = easeFactor

        if quality.rawValue >= 2 { // Correct
            if interval == 0 { interval = 1 }
            else if interval == 1 { interval = 3 }
            else { interval = Int(round(Double(interval) * ef)) }

            ef = ef + (0.1 - Double(2 - quality.rawValue) * 0.08)
            ef = max(1.3, ef)
        } else { // Incorrect
            interval = 1
            ef = max(1.3, ef - 0.2)
        }

        let masteryLevel = calculateMasteryLevel(interval: interval)
        let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: Date())!

        return ReviewResult(
            nextInterval: interval,
            newEaseFactor: ef,
            newMasteryLevel: masteryLevel,
            nextReviewDate: nextDate
        )
    }

    private func calculateMasteryLevel(interval: Int) -> Int {
        switch interval {
        case 0: return 0      // New
        case 1..<7: return 1  // Learning
        case 7..<21: return 2 // Reviewing
        case 21..<60: return 3 // Familiar
        default: return 4     // Mastered
        }
    }
}
```

### Phase 4: Basic UI

**Step 5: Create VocabularyViewModel**

```swift
// MindFlow/ViewModels/VocabularyViewModel.swift
import SwiftUI
import Combine

@MainActor
class VocabularyViewModel: ObservableObject {
    @Published var words: [VocabularyEntry] = []
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var dueForReviewCount = 0

    private let storage = VocabularyStorage.shared
    private let lookup = VocabularyLookupService.shared

    func loadWords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            words = try await storage.getAllWords()
            dueForReviewCount = try await storage.getWordsDueForReview().count
        } catch {
            self.error = error
        }
    }

    func addWord(_ word: String, context: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let explanation = try await lookup.lookupWord(word, context: context)
            _ = try await storage.addWord(explanation, context: context)
            await loadWords()
        } catch {
            self.error = error
        }
    }

    func search(_ query: String) async {
        guard !query.isEmpty else {
            await loadWords()
            return
        }

        do {
            words = try await storage.searchWords(query)
        } catch {
            self.error = error
        }
    }
}
```

**Step 6: Create VocabularyTabView**

```swift
// MindFlow/Views/VocabularyTabView.swift
import SwiftUI

struct VocabularyTabView: View {
    @StateObject private var viewModel = VocabularyViewModel()
    @State private var showingAddWord = false

    var body: some View {
        NavigationSplitView {
            VocabularySidebarView(
                selectedCategory: $viewModel.selectedCategory,
                dueCount: viewModel.dueForReviewCount
            )
        } detail: {
            VStack {
                // Search bar
                TextField("Search words...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: viewModel.searchText) { newValue in
                        Task { await viewModel.search(newValue) }
                    }

                // Word list
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    List(viewModel.words) { word in
                        VocabularyRowView(entry: word)
                    }
                }
            }
            .toolbar {
                Button("Add Word") { showingAddWord = true }
                Button("Review") { /* Navigate to review */ }
            }
        }
        .sheet(isPresented: $showingAddWord) {
            AddWordView(viewModel: viewModel)
        }
        .task { await viewModel.loadWords() }
    }
}
```

### Phase 5: Chrome Extension

**Step 7: Add vocabulary storage**

```javascript
// MindFlow-Extension/src/lib/vocabulary-storage.js
export class VocabularyStorage {
    static PREFIX = 'vocab_entry_';
    static INDEX_KEY = 'vocab_index';

    static async addWord(entry) {
        const id = crypto.randomUUID();
        const now = new Date().toISOString();

        const vocabEntry = {
            id,
            ...entry,
            masteryLevel: 0,
            reviewCount: 0,
            correctCount: 0,
            easeFactor: 2.5,
            interval: 0,
            isFavorite: false,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
            syncStatus: 'pending'
        };

        // Save entry
        await chrome.storage.local.set({
            [`${this.PREFIX}${id}`]: vocabEntry
        });

        // Update index
        await this.updateIndex(id, vocabEntry);

        return vocabEntry;
    }

    static async getWordsDueForReview() {
        const index = await this.getIndex();
        const entries = [];

        for (const id of index.dueForReview || []) {
            const entry = await this.getWord(id);
            if (entry) entries.push(entry);
        }

        return entries;
    }

    static async search(query) {
        const index = await this.getIndex();
        const results = [];
        const q = query.toLowerCase();

        for (const id of index.allIds || []) {
            const entry = await this.getWord(id);
            if (entry &&
                (entry.word.toLowerCase().includes(q) ||
                 entry.definitionEN?.toLowerCase().includes(q) ||
                 entry.definitionCN?.includes(q))) {
                results.push(entry);
            }
        }

        return results;
    }

    // ... more methods
}
```

---

## Key Files to Create/Modify

### macOS App (New Files)
| File | Purpose |
|------|---------|
| `Models/VocabularyEntry+CoreData.swift` | Core Data entity class |
| `Models/WordExplanation.swift` | AI response model |
| `Storage/VocabularyStorage.swift` | CRUD operations |
| `Services/VocabularyLookupService.swift` | AI word lookup |
| `Services/SpacedRepetitionService.swift` | SM-2 algorithm |
| `ViewModels/VocabularyViewModel.swift` | List state management |
| `ViewModels/ReviewViewModel.swift` | Review session state |
| `Views/VocabularyTabView.swift` | Main container |
| `Views/AddWordView.swift` | Add word modal |
| `Views/WordDetailView.swift` | Word details |
| `Views/ReviewSessionView.swift` | Flashcard review |

### macOS App (Modified Files)
| File | Change |
|------|--------|
| `Views/MainView.swift` | Add Vocabulary tab |
| `Models/Settings.swift` | Add vocabulary settings |
| `Services/LLMService.swift` | Add vocabulary prompt method |

### Chrome Extension (New Files)
| File | Purpose |
|------|---------|
| `lib/vocabulary-storage.js` | Chrome storage operations |
| `lib/vocabulary-lookup.js` | AI lookup |
| `vocabulary/vocabulary.html/js/css` | Full vocabulary page |
| `review/review.html/js/css` | Review interface |

### Chrome Extension (Modified Files)
| File | Change |
|------|--------|
| `popup/popup.html/js` | Add vocabulary section |
| `lib/storage-manager.js` | Add vocab methods |
| `content/content-script.js` | Add context menu |

---

## Testing Checklist

### Unit Tests
- [ ] VocabularyStorage CRUD operations
- [ ] SpacedRepetitionService interval calculations
- [ ] VocabularyLookupService JSON parsing

### Integration Tests
- [ ] Add word end-to-end flow
- [ ] Review session completion
- [ ] Search functionality

### Manual Tests
- [ ] Offline browsing/review works
- [ ] AI lookup handles errors gracefully
- [ ] Keyboard shortcuts work in review mode
- [ ] Extension context menu lookup works

---

## Common Patterns

### Error Handling
```swift
do {
    let result = try await service.method()
    // Success
} catch LLMError.missingAPIKey {
    showError("Please configure your OpenAI API key in Settings")
} catch LLMError.apiError(let message) {
    showError("API error: \(message)")
} catch {
    showError("An unexpected error occurred")
}
```

### Core Data Background Operations
```swift
let context = coreDataManager.newBackgroundContext()
try await context.perform {
    // Fetch/create/update operations
    try context.save()
}
```

### Chrome Storage Async Pattern
```javascript
async function saveWord(word) {
    try {
        const entry = await VocabularyStorage.addWord(word);
        updateUI(entry);
    } catch (error) {
        showError(`Failed to save: ${error.message}`);
    }
}
```

---

## Next Steps

After completing the basic implementation:

1. Run `/speckit.tasks` to generate detailed implementation tasks
2. Implement P1 user stories first (Add Word, Review)
3. Add unit tests for core services
4. Implement P2 features (Browse, Statistics)
5. Add Chrome extension support (P3)
6. Implement cloud sync (P3)

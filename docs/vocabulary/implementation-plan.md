# Vocabulary Learning Feature - Implementation Plan

## Overview

This document outlines the phased implementation plan for the Vocabulary Learning feature. The implementation follows MindFlow's existing architecture patterns and leverages existing services where possible.

## Implementation Phases

```
Phase 1: Core Data Layer (macOS)
    ↓
Phase 2: Word Lookup Service
    ↓
Phase 3: Basic UI (macOS)
    ↓
Phase 4: Spaced Repetition System
    ↓
Phase 5: Review Interface
    ↓
Phase 6: Chrome Extension Support
    ↓
Phase 7: Cloud Sync & Polish
```

---

## Phase 1: Core Data Layer (macOS)

**Goal**: Set up the data persistence layer for vocabulary entries.

### Tasks

#### 1.1 Core Data Schema Setup

- [ ] Create new Core Data model version (`MindFlow 2.xcdatamodel`)
- [ ] Define `VocabularyEntry` entity with all attributes
- [ ] Define `ReviewSession` entity
- [ ] Define `LearningStats` entity
- [ ] Add relationship from `VocabularyEntry` to `LocalInteraction`
- [ ] Set up indexes for frequently queried fields

**Files to Create/Modify:**
```
MindFlow/Models/MindFlow.xcdatamodeld/
├── MindFlow 2.xcdatamodel (new)
    ├── VocabularyEntry
    ├── ReviewSession
    └── LearningStats
```

#### 1.2 Core Data Classes

- [ ] Generate `VocabularyEntry+CoreDataClass.swift`
- [ ] Generate `VocabularyEntry+CoreDataProperties.swift`
- [ ] Generate `ReviewSession+CoreDataClass.swift`
- [ ] Generate `ReviewSession+CoreDataProperties.swift`
- [ ] Generate `LearningStats+CoreDataClass.swift`
- [ ] Generate `LearningStats+CoreDataProperties.swift`

**Files to Create:**
```
MindFlow/Models/
├── VocabularyEntry+CoreDataClass.swift
├── VocabularyEntry+CoreDataProperties.swift
├── ReviewSession+CoreDataClass.swift
├── ReviewSession+CoreDataProperties.swift
├── LearningStats+CoreDataClass.swift
└── LearningStats+CoreDataProperties.swift
```

#### 1.3 Storage Service

- [ ] Create `VocabularyStorageService.swift`
- [ ] Implement CRUD operations for vocabulary entries
- [ ] Implement search functionality
- [ ] Implement filtering (by category, tags, mastery level)
- [ ] Implement review queue retrieval (words due for review)
- [ ] Add unit tests for storage operations

**Files to Create:**
```
MindFlow/Services/
└── VocabularyStorageService.swift

MindFlowTests/
└── VocabularyStorageServiceTests.swift
```

**Key Methods:**
```swift
class VocabularyStorageService {
    // CRUD
    func addWord(_ word: VocabularyEntryData) async throws -> VocabularyEntry
    func updateWord(_ id: UUID, with data: VocabularyEntryData) async throws
    func deleteWord(_ id: UUID) async throws
    func getWord(_ id: UUID) async throws -> VocabularyEntry?
    func getWordByWord(_ word: String) async throws -> VocabularyEntry?

    // Queries
    func getAllWords(limit: Int?, offset: Int?) async throws -> [VocabularyEntry]
    func searchWords(_ query: String) async throws -> [VocabularyEntry]
    func getWordsByCategory(_ category: String) async throws -> [VocabularyEntry]
    func getWordsByTag(_ tag: String) async throws -> [VocabularyEntry]
    func getWordsDueForReview() async throws -> [VocabularyEntry]
    func getFavoriteWords() async throws -> [VocabularyEntry]

    // Statistics
    func getWordCount() async throws -> Int
    func getWordCountByMasteryLevel() async throws -> [Int: Int]
    func getDailyStats(for date: Date) async throws -> LearningStats?
}
```

### Deliverables
- Core Data schema with all entities
- VocabularyStorageService with full CRUD and query support
- Unit tests achieving >80% coverage

### Estimated Effort
- Schema setup: 2-3 hours
- Storage service: 4-6 hours
- Testing: 2-3 hours

---

## Phase 2: Word Lookup Service

**Goal**: Create AI-powered word explanation service using existing LLM infrastructure.

### Tasks

#### 2.1 Word Lookup Service

- [ ] Create `VocabularyLookupService.swift`
- [ ] Design prompt template for word explanations
- [ ] Implement API call using existing `LLMService`
- [ ] Parse and structure AI response
- [ ] Handle errors and edge cases (word not found, API failure)
- [ ] Add caching to avoid duplicate lookups

**Files to Create:**
```
MindFlow/Services/
└── VocabularyLookupService.swift
```

#### 2.2 Prompt Template

Design a structured prompt for consistent word explanations:

```
System: You are a vocabulary assistant helping a Chinese speaker learn English.
Provide comprehensive word explanations in a structured JSON format.

User: Explain the English word: "{word}"

Required JSON output:
{
    "word": "the word",
    "phonetic": "IPA pronunciation",
    "partOfSpeech": "noun/verb/adjective/etc",
    "definitionEN": "English definition",
    "definitionCN": "Chinese translation",
    "exampleSentences": [
        {"en": "Example sentence", "cn": "中文翻译"}
    ],
    "synonyms": ["word1", "word2"],
    "antonyms": ["word1", "word2"],
    "wordFamily": "related forms",
    "usageNotes": "usage context",
    "etymology": "word origin",
    "memoryTips": "mnemonic hint for Chinese speakers"
}
```

#### 2.3 Response Parser

- [ ] Create `WordExplanation` model struct
- [ ] Implement JSON parsing with error handling
- [ ] Handle partial responses gracefully
- [ ] Validate required fields

**Files to Create:**
```
MindFlow/Models/
└── WordExplanation.swift
```

**Model Definition:**
```swift
struct WordExplanation: Codable {
    let word: String
    let phonetic: String?
    let partOfSpeech: String?
    let definitionEN: String?
    let definitionCN: String?
    let exampleSentences: [ExampleSentence]?
    let synonyms: [String]?
    let antonyms: [String]?
    let wordFamily: String?
    let usageNotes: String?
    let etymology: String?
    let memoryTips: String?
}

struct ExampleSentence: Codable {
    let en: String
    let cn: String
}
```

### Deliverables
- VocabularyLookupService with AI integration
- WordExplanation model
- Comprehensive error handling

### Estimated Effort
- Service implementation: 3-4 hours
- Prompt engineering & testing: 2-3 hours
- Error handling: 1-2 hours

---

## Phase 3: Basic UI (macOS)

**Goal**: Implement the vocabulary tab with word list and add functionality.

### Tasks

#### 3.1 ViewModel

- [ ] Create `VocabularyViewModel.swift`
- [ ] Implement state management for word list
- [ ] Implement search functionality
- [ ] Implement filtering
- [ ] Implement add word flow
- [ ] Handle loading and error states

**Files to Create:**
```
MindFlow/ViewModels/
└── VocabularyViewModel.swift
```

#### 3.2 Main Vocabulary View

- [ ] Create `VocabularyTabView.swift` (main container)
- [ ] Create `VocabularySidebarView.swift` (categories, filters)
- [ ] Create `VocabularyListView.swift` (word list)
- [ ] Create `VocabularyRowView.swift` (single word row)
- [ ] Add to main tab bar navigation

**Files to Create:**
```
MindFlow/Views/
├── VocabularyTabView.swift
├── VocabularySidebarView.swift
├── VocabularyListView.swift
└── VocabularyRowView.swift
```

#### 3.3 Add Word View

- [ ] Create `AddWordView.swift` (modal/sheet)
- [ ] Implement word input (text field + voice button)
- [ ] Show loading state during AI lookup
- [ ] Display explanation preview
- [ ] Category and tag selection
- [ ] Save confirmation

**Files to Create:**
```
MindFlow/Views/
└── AddWordView.swift
```

#### 3.4 Word Detail View

- [ ] Create `WordDetailView.swift`
- [ ] Display all word information
- [ ] Edit functionality
- [ ] Delete functionality
- [ ] Favorite toggle
- [ ] Show review history

**Files to Create:**
```
MindFlow/Views/
└── WordDetailView.swift
```

#### 3.5 Navigation Integration

- [ ] Modify `MainView.swift` to include Vocabulary tab
- [ ] Add tab icon and label
- [ ] Handle deep linking (open specific word)

**Files to Modify:**
```
MindFlow/Views/MainView.swift
```

### Deliverables
- Complete vocabulary UI with list, detail, and add views
- Integration with main app navigation
- Search and filter functionality

### Estimated Effort
- ViewModel: 3-4 hours
- List/Row views: 3-4 hours
- Add word view: 3-4 hours
- Detail view: 2-3 hours
- Navigation: 1-2 hours

---

## Phase 4: Spaced Repetition System

**Goal**: Implement SM-2 based spaced repetition algorithm.

### Tasks

#### 4.1 Algorithm Implementation

- [ ] Create `SpacedRepetitionService.swift`
- [ ] Implement SM-2 algorithm
- [ ] Calculate next review date based on response quality
- [ ] Update ease factor and interval
- [ ] Handle mastery level progression

**Files to Create:**
```
MindFlow/Services/
└── SpacedRepetitionService.swift
```

**Algorithm Implementation:**
```swift
class SpacedRepetitionService {
    /// Response quality: 0 = forgot, 1 = hard, 2 = good, 3 = easy
    func calculateNextReview(
        currentInterval: Int,
        easeFactor: Double,
        responseQuality: Int
    ) -> (nextInterval: Int, newEaseFactor: Double, masteryLevel: Int)

    func getWordsDueForReview() -> [VocabularyEntry]

    func recordReview(
        word: VocabularyEntry,
        responseQuality: Int
    ) async throws
}
```

**SM-2 Algorithm (Simplified):**
```
If responseQuality >= 2 (correct):
    If interval == 0: interval = 1
    Else if interval == 1: interval = 3
    Else: interval = round(interval * easeFactor)

    easeFactor = easeFactor + (0.1 - (3 - responseQuality) * 0.08)
    easeFactor = max(1.3, easeFactor)

If responseQuality < 2 (incorrect):
    interval = 1
    easeFactor = max(1.3, easeFactor - 0.2)

nextReviewDate = today + interval days
```

#### 4.2 Review Queue Management

- [ ] Query words due for review
- [ ] Sort by priority (overdue first, then by ease factor)
- [ ] Limit daily review count based on settings
- [ ] Track session progress

#### 4.3 Statistics Tracking

- [ ] Update daily stats after each review
- [ ] Calculate streak days
- [ ] Track accuracy rate

### Deliverables
- Complete spaced repetition algorithm
- Review queue management
- Statistics tracking

### Estimated Effort
- Algorithm: 3-4 hours
- Queue management: 2-3 hours
- Statistics: 2-3 hours

---

## Phase 5: Review Interface

**Goal**: Build the flashcard review interface.

### Tasks

#### 5.1 Review ViewModel

- [ ] Create `ReviewViewModel.swift`
- [ ] Manage review session state
- [ ] Track progress (current card, total, correct/incorrect)
- [ ] Handle card navigation
- [ ] Record responses

**Files to Create:**
```
MindFlow/ViewModels/
└── ReviewViewModel.swift
```

#### 5.2 Review Views

- [ ] Create `ReviewSessionView.swift` (main container)
- [ ] Create `FlashcardView.swift` (single card)
- [ ] Create `ReviewSummaryView.swift` (session complete)
- [ ] Implement card flip animation
- [ ] Add keyboard shortcuts

**Files to Create:**
```
MindFlow/Views/
├── ReviewSessionView.swift
├── FlashcardView.swift
└── ReviewSummaryView.swift
```

#### 5.3 Review Modes

- [ ] Flashcard mode (word → meaning)
- [ ] Reverse mode (meaning → word)
- [ ] Context mode (fill-in-blank) - optional for MVP

#### 5.4 Progress Display

- [ ] Progress bar
- [ ] Current/total count
- [ ] Session timer
- [ ] Accuracy indicator

### Deliverables
- Complete review interface with flashcard mode
- Session summary view
- Keyboard navigation support

### Estimated Effort
- ViewModel: 2-3 hours
- Flashcard views: 4-5 hours
- Animation: 2-3 hours
- Summary view: 1-2 hours

---

## Phase 6: Chrome Extension Support

**Goal**: Implement vocabulary feature in Chrome extension.

### Tasks

#### 6.1 Storage Layer

- [ ] Create `vocabulary-storage.js`
- [ ] Implement CRUD using Chrome Storage API
- [ ] Implement index management
- [ ] Port search functionality

**Files to Create:**
```
MindFlow-Extension/src/lib/
└── vocabulary-storage.js
```

#### 6.2 Lookup Service

- [ ] Create `vocabulary-lookup.js`
- [ ] Port AI lookup functionality
- [ ] Handle API calls from extension context

**Files to Create:**
```
MindFlow-Extension/src/lib/
└── vocabulary-lookup.js
```

#### 6.3 Popup Integration

- [ ] Modify `popup.html` to add vocabulary section
- [ ] Create vocabulary UI components
- [ ] Implement quick add functionality
- [ ] Show due reviews count

**Files to Modify:**
```
MindFlow-Extension/src/popup/
├── popup.html
├── popup.js
└── popup.css
```

#### 6.4 Full Vocabulary Page

- [ ] Create `vocabulary.html` (full page)
- [ ] Create `vocabulary.js`
- [ ] Create `vocabulary.css`
- [ ] Implement list view with filtering
- [ ] Implement search

**Files to Create:**
```
MindFlow-Extension/src/vocabulary/
├── vocabulary.html
├── vocabulary.js
└── vocabulary.css
```

#### 6.5 Content Script Integration

- [ ] Add context menu for word lookup
- [ ] Create inline popup for quick add
- [ ] Handle text selection

**Files to Modify:**
```
MindFlow-Extension/src/content/
└── content-script.js

MindFlow-Extension/src/background/
└── service-worker.js
```

#### 6.6 Review Interface

- [ ] Create `review.html`
- [ ] Create `review.js`
- [ ] Create `review.css`
- [ ] Port flashcard functionality

**Files to Create:**
```
MindFlow-Extension/src/review/
├── review.html
├── review.js
└── review.css
```

### Deliverables
- Full vocabulary feature in Chrome extension
- Context menu integration
- Review interface

### Estimated Effort
- Storage layer: 3-4 hours
- Popup integration: 2-3 hours
- Full page: 4-5 hours
- Content script: 3-4 hours
- Review interface: 3-4 hours

---

## Phase 7: Cloud Sync & Polish

**Goal**: Enable cloud sync and polish the feature.

### Tasks

#### 7.1 Supabase Schema

- [ ] Create migration for vocabulary tables
- [ ] Set up RLS policies
- [ ] Test with Supabase

**SQL Files:**
```
supabase/migrations/
└── xxxx_vocabulary_tables.sql
```

#### 7.2 Sync Service (macOS)

- [ ] Create `VocabularySyncService.swift`
- [ ] Implement upload to Supabase
- [ ] Implement download from Supabase
- [ ] Handle conflict resolution
- [ ] Background sync

**Files to Create:**
```
MindFlow/Services/
└── VocabularySyncService.swift
```

#### 7.3 Sync Service (Chrome)

- [ ] Create `vocabulary-sync.js`
- [ ] Port sync functionality
- [ ] Handle extension-specific constraints

**Files to Create:**
```
MindFlow-Extension/src/lib/
└── vocabulary-sync.js
```

#### 7.4 Settings Integration

- [ ] Add vocabulary settings to Settings tab
- [ ] Daily goals configuration
- [ ] Review reminder settings
- [ ] Import/Export functionality

**Files to Modify:**
```
MindFlow/Views/SettingsTabView.swift
MindFlow-Extension/src/settings/settings.html
MindFlow-Extension/src/settings/settings.js
```

#### 7.5 Statistics View

- [ ] Create `VocabularyStatsView.swift`
- [ ] Implement charts (learning progress, accuracy)
- [ ] Streak display
- [ ] Export statistics

**Files to Create:**
```
MindFlow/Views/
└── VocabularyStatsView.swift
```

#### 7.6 Notifications

- [ ] Implement review reminders (macOS)
- [ ] Implement browser notifications (Chrome)
- [ ] Daily summary notifications

#### 7.7 Polish & Testing

- [ ] UI polish and animations
- [ ] Accessibility improvements
- [ ] Performance optimization
- [ ] End-to-end testing
- [ ] User documentation

### Deliverables
- Cloud sync functionality
- Complete settings integration
- Statistics and analytics
- Polished user experience

### Estimated Effort
- Supabase schema: 2-3 hours
- macOS sync: 4-5 hours
- Chrome sync: 3-4 hours
- Settings: 2-3 hours
- Statistics: 3-4 hours
- Polish: 4-6 hours

---

## Dependencies

### External Dependencies

| Dependency | Usage | Already Available |
|------------|-------|-------------------|
| OpenAI API | Word explanations | Yes (LLMService) |
| Supabase | Cloud sync | Yes (existing setup) |
| Core Data | Local storage | Yes (CoreDataManager) |
| Chrome Storage | Extension storage | Yes |

### Internal Dependencies

| Component | Depends On |
|-----------|------------|
| VocabularyStorageService | CoreDataManager |
| VocabularyLookupService | LLMService, Settings |
| VocabularyViewModel | VocabularyStorageService, VocabularyLookupService |
| SpacedRepetitionService | VocabularyStorageService |
| ReviewViewModel | SpacedRepetitionService, VocabularyStorageService |
| VocabularySyncService | SupabaseAuthService, VocabularyStorageService |

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| AI response inconsistency | Medium | Medium | Robust parsing, fallback to manual input |
| Performance with large vocab | Medium | Low | Pagination, lazy loading, indexed queries |
| Sync conflicts | High | Medium | Last-write-wins, clear conflict UI |
| Extension storage limits | Medium | Low | Efficient storage, cleanup old data |
| API rate limiting | Medium | Low | Caching, request throttling |

---

## Testing Strategy

### Unit Tests
- VocabularyStorageService CRUD operations
- SpacedRepetitionService algorithm
- VocabularyLookupService parsing

### Integration Tests
- End-to-end add word flow
- Review session completion
- Sync round-trip

### UI Tests
- Navigation flows
- Keyboard shortcuts
- Accessibility

### Manual Testing
- Voice input for words
- Cross-device sync
- Various screen sizes (extension)

---

## Success Criteria

### Phase 1-3 (MVP)
- [ ] Users can add words and see AI explanations
- [ ] Words are persisted locally
- [ ] Basic list and detail views work
- [ ] Search works correctly

### Phase 4-5 (Core Learning)
- [ ] Spaced repetition calculates correct intervals
- [ ] Review interface is intuitive
- [ ] Progress is tracked accurately

### Phase 6 (Extension)
- [ ] Feature parity with macOS (core features)
- [ ] Context menu works on webpages
- [ ] Extension storage is efficient

### Phase 7 (Complete)
- [ ] Cloud sync works reliably
- [ ] Statistics provide useful insights
- [ ] Feature feels polished and integrated

---

## File Summary

### New Files (macOS)
```
MindFlow/
├── Models/
│   ├── MindFlow 2.xcdatamodel
│   ├── VocabularyEntry+CoreDataClass.swift
│   ├── VocabularyEntry+CoreDataProperties.swift
│   ├── ReviewSession+CoreDataClass.swift
│   ├── ReviewSession+CoreDataProperties.swift
│   ├── LearningStats+CoreDataClass.swift
│   ├── LearningStats+CoreDataProperties.swift
│   └── WordExplanation.swift
├── Services/
│   ├── VocabularyStorageService.swift
│   ├── VocabularyLookupService.swift
│   ├── SpacedRepetitionService.swift
│   └── VocabularySyncService.swift
├── ViewModels/
│   ├── VocabularyViewModel.swift
│   └── ReviewViewModel.swift
└── Views/
    ├── VocabularyTabView.swift
    ├── VocabularySidebarView.swift
    ├── VocabularyListView.swift
    ├── VocabularyRowView.swift
    ├── AddWordView.swift
    ├── WordDetailView.swift
    ├── ReviewSessionView.swift
    ├── FlashcardView.swift
    ├── ReviewSummaryView.swift
    └── VocabularyStatsView.swift
```

### New Files (Chrome Extension)
```
MindFlow-Extension/src/
├── lib/
│   ├── vocabulary-storage.js
│   ├── vocabulary-lookup.js
│   └── vocabulary-sync.js
├── vocabulary/
│   ├── vocabulary.html
│   ├── vocabulary.js
│   └── vocabulary.css
└── review/
    ├── review.html
    ├── review.js
    └── review.css
```

### Modified Files
```
MindFlow/Views/MainView.swift
MindFlow/Views/SettingsTabView.swift
MindFlow-Extension/src/popup/*
MindFlow-Extension/src/content/content-script.js
MindFlow-Extension/src/background/service-worker.js
MindFlow-Extension/src/settings/*
```

---

**Related Documents:**
- [Feature Overview](./feature-overview.md)
- [Database Design](./database-design.md)
- [UI/UX Design](./ui-design.md)

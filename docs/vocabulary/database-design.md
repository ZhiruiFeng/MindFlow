# Vocabulary Learning Feature - Database Design

## Overview

This document details the database schema design for the Vocabulary Learning feature. Following MindFlow's local-first architecture, the design supports:

- **macOS App**: Core Data (SQLite) for local storage
- **Chrome Extension**: Chrome Storage API
- **Cloud Sync**: Supabase PostgreSQL (optional)

## Design Principles

1. **Local-First**: All data stored locally by default
2. **Sync-Ready**: Schema supports bidirectional cloud sync
3. **Extensible**: Easy to add new fields without migrations
4. **Performance**: Optimized for common queries (search, review queue)
5. **Consistency**: Same logical schema across platforms

---

## Core Data Schema (macOS App)

### Entity: `VocabularyEntry`

The main entity storing vocabulary words and their information.

```
Entity: VocabularyEntry
├── Attributes
│   ├── id: UUID (required, indexed)
│   ├── word: String (required, indexed)
│   ├── phonetic: String (optional)
│   ├── partOfSpeech: String (optional)
│   ├── definitionEN: String (optional)
│   ├── definitionCN: String (optional)
│   ├── exampleSentences: String (optional, JSON array)
│   ├── synonyms: String (optional)
│   ├── antonyms: String (optional)
│   ├── wordFamily: String (optional)
│   ├── usageNotes: String (optional)
│   ├── etymology: String (optional)
│   ├── memoryTips: String (optional)
│   ├── userContext: String (optional)
│   ├── sourceInteractionId: UUID (optional)
│   ├── tags: String (optional, comma-separated)
│   ├── category: String (optional)
│   ├── masteryLevel: Int16 (default: 0)
│   ├── reviewCount: Int32 (default: 0)
│   ├── correctCount: Int32 (default: 0)
│   ├── lastReviewedAt: Date (optional)
│   ├── nextReviewAt: Date (optional)
│   ├── easeFactor: Double (default: 2.5)
│   ├── interval: Int32 (default: 0)
│   ├── isFavorite: Boolean (default: false)
│   ├── isArchived: Boolean (default: false)
│   ├── createdAt: Date (required)
│   ├── updatedAt: Date (required)
│   ├── syncStatus: String (default: "pending")
│   ├── backendId: String (optional)
│   ├── lastSyncAttempt: Date (optional)
│   └── syncErrorMessage: String (optional)
│
└── Relationships
    └── sourceInteraction: LocalInteraction (optional, to-one)
```

### Attribute Details

#### Core Word Information

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | UUID | Yes | Unique identifier for the entry |
| `word` | String | Yes | The English word (normalized to lowercase) |
| `phonetic` | String | No | IPA pronunciation (e.g., "/ˈeləkwənt/") |
| `partOfSpeech` | String | No | Part of speech (noun, verb, adjective, etc.) |
| `definitionEN` | String | No | English definition |
| `definitionCN` | String | No | Chinese translation/definition |
| `exampleSentences` | String | No | JSON array of example sentences |
| `synonyms` | String | No | Comma-separated synonyms |
| `antonyms` | String | No | Comma-separated antonyms |
| `wordFamily` | String | No | Related word forms |
| `usageNotes` | String | No | Usage context and register |
| `etymology` | String | No | Word origin |
| `memoryTips` | String | No | Mnemonic hints for memorization |

#### Context & Organization

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `userContext` | String | No | User-provided context where word was encountered |
| `sourceInteractionId` | UUID | No | Link to transcription where word was found |
| `tags` | String | No | User-defined tags (comma-separated) |
| `category` | String | No | Category/word list name |
| `isFavorite` | Boolean | No | Marked as favorite for quick access |
| `isArchived` | Boolean | No | Soft delete / archived status |

#### Spaced Repetition Data

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `masteryLevel` | Int16 | No | Learning stage (0-4, see below) |
| `reviewCount` | Int32 | No | Total number of reviews |
| `correctCount` | Int32 | No | Number of correct reviews |
| `lastReviewedAt` | Date | No | Timestamp of last review |
| `nextReviewAt` | Date | No | Scheduled next review date |
| `easeFactor` | Double | No | SM-2 ease factor (default: 2.5) |
| `interval` | Int32 | No | Current review interval in days |

#### Mastery Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | New | Just added, not yet reviewed |
| 1 | Learning | In initial learning phase |
| 2 | Reviewing | Regular review cycle |
| 3 | Familiar | Longer intervals, well-known |
| 4 | Mastered | Very long intervals, fully learned |

#### Sync Metadata

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `createdAt` | Date | Yes | Creation timestamp |
| `updatedAt` | Date | Yes | Last modification timestamp |
| `syncStatus` | String | No | "pending", "synced", "failed" |
| `backendId` | String | No | Server-side ID for sync |
| `lastSyncAttempt` | Date | No | Last sync attempt timestamp |
| `syncErrorMessage` | String | No | Error message if sync failed |

### Entity: `ReviewSession`

Tracks individual review sessions for analytics.

```
Entity: ReviewSession
├── Attributes
│   ├── id: UUID (required)
│   ├── startedAt: Date (required)
│   ├── completedAt: Date (optional)
│   ├── totalWords: Int32 (required)
│   ├── correctCount: Int32 (default: 0)
│   ├── incorrectCount: Int32 (default: 0)
│   ├── skippedCount: Int32 (default: 0)
│   ├── reviewMode: String (required)
│   └── durationSeconds: Int32 (optional)
```

### Entity: `LearningStats`

Daily aggregated learning statistics.

```
Entity: LearningStats
├── Attributes
│   ├── id: UUID (required)
│   ├── date: Date (required, indexed, unique)
│   ├── wordsAdded: Int32 (default: 0)
│   ├── wordsReviewed: Int32 (default: 0)
│   ├── correctReviews: Int32 (default: 0)
│   ├── incorrectReviews: Int32 (default: 0)
│   ├── studyTimeSeconds: Int32 (default: 0)
│   └── streakDays: Int32 (default: 0)
```

---

## Chrome Extension Storage Schema

Chrome Storage uses a key-value structure. We'll organize data with prefixes for namespacing.

### Storage Keys

```javascript
// Vocabulary entries stored individually for efficient updates
"vocab_entry_{uuid}": {
    id: string,              // UUID
    word: string,
    phonetic: string | null,
    partOfSpeech: string | null,
    definitionEN: string | null,
    definitionCN: string | null,
    exampleSentences: string[] | null,
    synonyms: string | null,
    antonyms: string | null,
    wordFamily: string | null,
    usageNotes: string | null,
    etymology: string | null,
    memoryTips: string | null,
    userContext: string | null,
    sourceInteractionId: string | null,
    tags: string[],
    category: string | null,
    masteryLevel: number,
    reviewCount: number,
    correctCount: number,
    lastReviewedAt: string | null,    // ISO date string
    nextReviewAt: string | null,
    easeFactor: number,
    interval: number,
    isFavorite: boolean,
    isArchived: boolean,
    createdAt: string,
    updatedAt: string,
    syncStatus: string,
    backendId: string | null
}

// Index for efficient lookups
"vocab_index": {
    allIds: string[],                    // All entry IDs
    byWord: { [word: string]: string },  // word -> id mapping
    byCategory: { [cat: string]: string[] },
    byTag: { [tag: string]: string[] },
    dueForReview: string[]               // IDs due for review
}

// Review sessions
"vocab_review_session_{uuid}": {
    id: string,
    startedAt: string,
    completedAt: string | null,
    totalWords: number,
    correctCount: number,
    incorrectCount: number,
    skippedCount: number,
    reviewMode: string,
    durationSeconds: number | null
}

// Daily stats
"vocab_stats_{date}": {    // date format: YYYY-MM-DD
    date: string,
    wordsAdded: number,
    wordsReviewed: number,
    correctReviews: number,
    incorrectReviews: number,
    studyTimeSeconds: number,
    streakDays: number
}

// Settings
"vocab_settings": {
    dailyNewWordsGoal: number,
    dailyReviewGoal: number,
    enableNotifications: boolean,
    reviewReminderTime: string,   // HH:MM format
    defaultCategory: string | null,
    autoPlayPronunciation: boolean
}
```

### Storage Sync Strategy

```javascript
// Use chrome.storage.local for vocabulary data (larger quota)
chrome.storage.local.set({ "vocab_entry_xxx": { ... } });

// Use chrome.storage.sync for settings (syncs across devices)
chrome.storage.sync.set({ "vocab_settings": { ... } });
```

---

## Supabase Cloud Schema (PostgreSQL)

For optional cloud sync, the following tables are needed:

### Table: `vocabulary_entries`

```sql
CREATE TABLE vocabulary_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Core word information
    word VARCHAR(255) NOT NULL,
    phonetic VARCHAR(100),
    part_of_speech VARCHAR(50),
    definition_en TEXT,
    definition_cn TEXT,
    example_sentences JSONB DEFAULT '[]',
    synonyms TEXT,
    antonyms TEXT,
    word_family TEXT,
    usage_notes TEXT,
    etymology TEXT,
    memory_tips TEXT,

    -- Context & organization
    user_context TEXT,
    source_interaction_id UUID REFERENCES interactions(id),
    tags TEXT[] DEFAULT '{}',
    category VARCHAR(100),
    is_favorite BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,

    -- Spaced repetition
    mastery_level SMALLINT DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    last_reviewed_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ,
    ease_factor DECIMAL(3,2) DEFAULT 2.5,
    interval_days INTEGER DEFAULT 0,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    client_id VARCHAR(255),  -- Original client-side ID for sync

    -- Constraints
    CONSTRAINT unique_user_word UNIQUE (user_id, word)
);

-- Indexes for performance
CREATE INDEX idx_vocab_user_id ON vocabulary_entries(user_id);
CREATE INDEX idx_vocab_word ON vocabulary_entries(word);
CREATE INDEX idx_vocab_next_review ON vocabulary_entries(user_id, next_review_at);
CREATE INDEX idx_vocab_category ON vocabulary_entries(user_id, category);
CREATE INDEX idx_vocab_mastery ON vocabulary_entries(user_id, mastery_level);
CREATE INDEX idx_vocab_tags ON vocabulary_entries USING GIN(tags);
```

### Table: `review_sessions`

```sql
CREATE TABLE review_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    total_words INTEGER NOT NULL,
    correct_count INTEGER DEFAULT 0,
    incorrect_count INTEGER DEFAULT 0,
    skipped_count INTEGER DEFAULT 0,
    review_mode VARCHAR(50) NOT NULL,
    duration_seconds INTEGER,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_review_user ON review_sessions(user_id);
CREATE INDEX idx_review_date ON review_sessions(user_id, started_at);
```

### Table: `learning_stats`

```sql
CREATE TABLE learning_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    stat_date DATE NOT NULL,
    words_added INTEGER DEFAULT 0,
    words_reviewed INTEGER DEFAULT 0,
    correct_reviews INTEGER DEFAULT 0,
    incorrect_reviews INTEGER DEFAULT 0,
    study_time_seconds INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_user_date UNIQUE (user_id, stat_date)
);

CREATE INDEX idx_stats_user_date ON learning_stats(user_id, stat_date);
```

### Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE vocabulary_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_stats ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only access their own data
CREATE POLICY "Users can view own vocabulary"
    ON vocabulary_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own vocabulary"
    ON vocabulary_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own vocabulary"
    ON vocabulary_entries FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own vocabulary"
    ON vocabulary_entries FOR DELETE
    USING (auth.uid() = user_id);

-- Similar policies for other tables...
```

---

## Sync Strategy

### Conflict Resolution

Following MindFlow's existing sync pattern:

1. **Last-Write-Wins**: Use `updated_at` timestamp for conflict resolution
2. **Client ID Mapping**: Map local `id` to server `backendId` after sync
3. **Soft Deletes**: Use `isArchived` flag instead of hard deletes

### Sync Flow

```
Local Change → Mark syncStatus = "pending"
           → Attempt sync
           → Success: syncStatus = "synced", store backendId
           → Failure: syncStatus = "failed", increment retry count
```

### Sync Triggers

- New word added
- Word updated (definition, tags, etc.)
- Review completed (mastery level, interval changed)
- Manual sync button
- App launch (background sync)

---

## Data Migration

### Adding to Existing Core Data Model

1. Create new `VocabularyEntry` entity in `MindFlow.xcdatamodeld`
2. Add relationship to existing `LocalInteraction` entity
3. Use lightweight migration (no manual migration needed for new entities)

### Version Control

```
MindFlow.xcdatamodeld/
├── MindFlow.xcdatamodel (v1 - existing)
└── MindFlow 2.xcdatamodel (v2 - with vocabulary)
```

---

## Query Patterns

### Common Queries (Core Data)

```swift
// Get words due for review today
let today = Date()
let predicate = NSPredicate(
    format: "nextReviewAt <= %@ AND isArchived == NO",
    today as NSDate
)
let sortDescriptor = NSSortDescriptor(key: "nextReviewAt", ascending: true)

// Search words
let searchPredicate = NSPredicate(
    format: "word CONTAINS[cd] %@ OR definitionEN CONTAINS[cd] %@ OR definitionCN CONTAINS[cd] %@",
    searchText, searchText, searchText
)

// Get words by category
let categoryPredicate = NSPredicate(
    format: "category == %@ AND isArchived == NO",
    categoryName
)

// Get learning statistics
let statsRequest: NSFetchRequest<LearningStats> = LearningStats.fetchRequest()
statsRequest.predicate = NSPredicate(
    format: "date >= %@ AND date <= %@",
    startDate as NSDate, endDate as NSDate
)
```

### Performance Considerations

1. **Indexed Fields**: `id`, `word`, `nextReviewAt`, `category`, `masteryLevel`
2. **Batch Operations**: Use batch insert/update for bulk operations
3. **Fetch Limits**: Always use `fetchLimit` for list views
4. **Background Context**: Perform heavy operations on background context

---

## Data Size Estimates

| Data Type | Size per Entry | Expected Entries | Total Size |
|-----------|---------------|------------------|------------|
| VocabularyEntry | ~2 KB | 5,000 words | ~10 MB |
| ReviewSession | ~200 B | 1,000 sessions | ~200 KB |
| LearningStats | ~100 B | 365 days | ~36 KB |
| **Total** | - | - | **~11 MB** |

Chrome Storage quotas:
- `chrome.storage.local`: 10 MB (sufficient)
- `chrome.storage.sync`: 100 KB (settings only)

---

## Appendix: JSON Structures

### Example Sentences Format

```json
[
    {
        "sentence": "She gave an eloquent speech at the conference.",
        "translation": "她在会议上发表了一篇雄辩的演讲。"
    },
    {
        "sentence": "His eloquent writing style captivated readers.",
        "translation": "他雄辩的写作风格吸引了读者。"
    }
]
```

### Tags Format

```
// Core Data: Comma-separated string
"technology,programming,daily"

// Chrome Storage / Supabase: Array
["technology", "programming", "daily"]
```

---

**Related Documents:**
- [Feature Overview](./feature-overview.md)
- [UI/UX Design](./ui-design.md)
- [Implementation Plan](./implementation-plan.md)

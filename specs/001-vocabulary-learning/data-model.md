# Data Model: Vocabulary Learning

**Feature**: 001-vocabulary-learning
**Date**: 2026-01-09
**Status**: Complete

## Overview

This document defines the data model for the vocabulary learning feature. It covers Core Data entities for macOS, Chrome Storage structures for the extension, and Supabase tables for optional cloud sync.

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        VocabularyEntry                          │
├─────────────────────────────────────────────────────────────────┤
│ id: UUID (PK)                                                   │
│ word: String (required, indexed)                                │
│ phonetic, partOfSpeech, definitionEN, definitionCN: String      │
│ exampleSentences: JSON Array                                    │
│ synonyms, antonyms, wordFamily, usageNotes, etymology: String   │
│ memoryTips, userContext: String                                 │
│ tags: String (comma-separated), category: String                │
│ isFavorite, isArchived: Boolean                                 │
│ masteryLevel: Int, reviewCount, correctCount: Int               │
│ lastReviewedAt, nextReviewAt: Date (indexed)                    │
│ easeFactor: Double, interval: Int                               │
│ createdAt, updatedAt: Date                                      │
│ syncStatus, backendId: String                                   │
├─────────────────────────────────────────────────────────────────┤
│ sourceInteraction: LocalInteraction? (optional relationship)    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1:N (implicit via date aggregation)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ReviewSession                            │
├─────────────────────────────────────────────────────────────────┤
│ id: UUID (PK)                                                   │
│ startedAt: Date (required)                                      │
│ completedAt: Date (optional)                                    │
│ totalWords: Int                                                 │
│ correctCount, incorrectCount, skippedCount: Int                 │
│ reviewMode: String                                              │
│ durationSeconds: Int                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        LearningStats                            │
├─────────────────────────────────────────────────────────────────┤
│ id: UUID (PK)                                                   │
│ date: Date (required, unique, indexed)                          │
│ wordsAdded: Int                                                 │
│ wordsReviewed: Int                                              │
│ correctReviews, incorrectReviews: Int                           │
│ studyTimeSeconds: Int                                           │
│ streakDays: Int                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Data Entities (macOS)

### VocabularyEntry

The primary entity storing vocabulary words and their information.

| Attribute | Type | Required | Indexed | Default | Description |
|-----------|------|----------|---------|---------|-------------|
| **id** | UUID | Yes | Yes | auto-generated | Unique identifier |
| **word** | String | Yes | Yes | - | The English word (normalized to lowercase) |
| phonetic | String | No | No | nil | IPA pronunciation (e.g., "/ˈeləkwənt/") |
| partOfSpeech | String | No | No | nil | Part of speech (noun, verb, adj, etc.) |
| definitionEN | String | No | No | nil | English definition |
| definitionCN | String | No | No | nil | Chinese translation/definition |
| exampleSentences | String | No | No | nil | JSON array of {en, cn} objects |
| synonyms | String | No | No | nil | Comma-separated synonyms |
| antonyms | String | No | No | nil | Comma-separated antonyms |
| wordFamily | String | No | No | nil | Related word forms |
| usageNotes | String | No | No | nil | Usage context and register |
| etymology | String | No | No | nil | Word origin |
| memoryTips | String | No | No | nil | Mnemonic hints |
| userContext | String | No | No | nil | User-provided context |
| sourceInteractionId | UUID | No | No | nil | Link to transcription |
| tags | String | No | No | nil | Comma-separated tags |
| category | String | No | Yes | nil | Category/word list name |
| isFavorite | Boolean | No | No | false | Marked as favorite |
| isArchived | Boolean | No | No | false | Soft delete status |
| **masteryLevel** | Int16 | No | Yes | 0 | Learning stage (0-4) |
| reviewCount | Int32 | No | No | 0 | Total reviews |
| correctCount | Int32 | No | No | 0 | Correct reviews |
| lastReviewedAt | Date | No | No | nil | Last review timestamp |
| **nextReviewAt** | Date | No | Yes | nil | Next scheduled review |
| easeFactor | Double | No | No | 2.5 | SM-2 ease factor |
| interval | Int32 | No | No | 0 | Current interval in days |
| **createdAt** | Date | Yes | No | now | Creation timestamp |
| **updatedAt** | Date | Yes | No | now | Last modification |
| syncStatus | String | No | No | "pending" | Sync state |
| backendId | String | No | No | nil | Server-side ID |

**Relationships**:
- `sourceInteraction` → `LocalInteraction` (optional, to-one)

**Mastery Level Values**:
| Value | Name | Description |
|-------|------|-------------|
| 0 | New | Just added, not yet reviewed |
| 1 | Learning | In initial learning phase (interval < 7 days) |
| 2 | Reviewing | Regular review cycle (7-20 days) |
| 3 | Familiar | Longer intervals (21-59 days) |
| 4 | Mastered | Very long intervals (60+ days) |

---

### ReviewSession

Tracks individual review sessions for analytics.

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| **id** | UUID | Yes | auto-generated | Unique identifier |
| **startedAt** | Date | Yes | - | Session start time |
| completedAt | Date | No | nil | Session end time |
| **totalWords** | Int32 | Yes | - | Words in session |
| correctCount | Int32 | No | 0 | Correct answers |
| incorrectCount | Int32 | No | 0 | Incorrect answers |
| skippedCount | Int32 | No | 0 | Skipped cards |
| **reviewMode** | String | Yes | - | Mode (flashcard, reverse, context) |
| durationSeconds | Int32 | No | nil | Session duration |

---

### LearningStats

Daily aggregated learning statistics.

| Attribute | Type | Required | Indexed | Default | Description |
|-----------|------|----------|---------|---------|-------------|
| **id** | UUID | Yes | No | auto-generated | Unique identifier |
| **date** | Date | Yes | Yes | - | Stats date (unique per day) |
| wordsAdded | Int32 | No | No | 0 | New words added |
| wordsReviewed | Int32 | No | No | 0 | Words reviewed |
| correctReviews | Int32 | No | No | 0 | Correct reviews |
| incorrectReviews | Int32 | No | No | 0 | Incorrect reviews |
| studyTimeSeconds | Int32 | No | No | 0 | Total study time |
| streakDays | Int32 | No | No | 0 | Current streak |

---

## Chrome Extension Storage (JavaScript)

### VocabularyEntry Object

```typescript
interface VocabularyEntry {
    id: string;                        // UUID
    word: string;                      // Required
    phonetic: string | null;
    partOfSpeech: string | null;
    definitionEN: string | null;
    definitionCN: string | null;
    exampleSentences: ExampleSentence[] | null;
    synonyms: string | null;
    antonyms: string | null;
    wordFamily: string | null;
    usageNotes: string | null;
    etymology: string | null;
    memoryTips: string | null;
    userContext: string | null;
    sourceInteractionId: string | null;
    tags: string[];                    // Array (not comma-separated)
    category: string | null;
    isFavorite: boolean;               // Default: false
    isArchived: boolean;               // Default: false
    masteryLevel: number;              // 0-4
    reviewCount: number;               // Default: 0
    correctCount: number;              // Default: 0
    lastReviewedAt: string | null;     // ISO date string
    nextReviewAt: string | null;       // ISO date string
    easeFactor: number;                // Default: 2.5
    interval: number;                  // Default: 0
    createdAt: string;                 // ISO date string
    updatedAt: string;                 // ISO date string
    syncStatus: string;                // "pending" | "synced" | "failed"
    backendId: string | null;
}

interface ExampleSentence {
    en: string;
    cn: string;
}
```

### Storage Key Schema

```typescript
// Individual entries (chrome.storage.local)
"vocab_entry_{uuid}": VocabularyEntry

// Index structure (chrome.storage.local)
"vocab_index": {
    allIds: string[];                           // All entry IDs
    byWord: Record<string, string>;             // word → id mapping
    byCategory: Record<string, string[]>;       // category → [ids]
    byTag: Record<string, string[]>;            // tag → [ids]
    dueForReview: string[];                     // IDs due for review
}

// Review sessions (chrome.storage.local)
"vocab_review_session_{uuid}": ReviewSession

// Daily stats (chrome.storage.local)
"vocab_stats_{YYYY-MM-DD}": LearningStats

// Settings (chrome.storage.sync)
"vocab_settings": {
    dailyNewWordsGoal: number;                  // Default: 5
    dailyReviewGoal: number;                    // Default: 15
    enableNotifications: boolean;               // Default: true
    reviewReminderTime: string;                 // Default: "09:00"
    defaultCategory: string | null;
    autoPlayPronunciation: boolean;             // Default: false
}
```

---

## Supabase Schema (PostgreSQL)

### vocabulary_entries Table

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
    source_interaction_id UUID,
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
    client_id VARCHAR(255),

    -- Constraints
    CONSTRAINT unique_user_word UNIQUE (user_id, word)
);

-- Indexes
CREATE INDEX idx_vocab_user_id ON vocabulary_entries(user_id);
CREATE INDEX idx_vocab_word ON vocabulary_entries(word);
CREATE INDEX idx_vocab_next_review ON vocabulary_entries(user_id, next_review_at);
CREATE INDEX idx_vocab_category ON vocabulary_entries(user_id, category);
CREATE INDEX idx_vocab_mastery ON vocabulary_entries(user_id, mastery_level);
CREATE INDEX idx_vocab_tags ON vocabulary_entries USING GIN(tags);

-- Row Level Security
ALTER TABLE vocabulary_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own vocabulary"
    ON vocabulary_entries FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own vocabulary"
    ON vocabulary_entries FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own vocabulary"
    ON vocabulary_entries FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own vocabulary"
    ON vocabulary_entries FOR DELETE USING (auth.uid() = user_id);
```

### review_sessions Table

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

ALTER TABLE review_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own sessions"
    ON review_sessions FOR ALL USING (auth.uid() = user_id);
```

### learning_stats Table

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

ALTER TABLE learning_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own stats"
    ON learning_stats FOR ALL USING (auth.uid() = user_id);
```

---

## Validation Rules

### VocabularyEntry

| Field | Rule | Error Message |
|-------|------|---------------|
| word | Required, non-empty, max 255 chars | "Word is required" |
| word | Unique per user (case-insensitive) | "Word already exists in vocabulary" |
| masteryLevel | 0-4 range | "Invalid mastery level" |
| easeFactor | >= 1.3 | "Ease factor cannot be below 1.3" |
| interval | >= 0 | "Interval cannot be negative" |
| tags | Max 10 tags per entry | "Maximum 10 tags allowed" |
| category | Max 100 chars | "Category name too long" |

### ReviewSession

| Field | Rule | Error Message |
|-------|------|---------------|
| totalWords | > 0 | "Session must have at least one word" |
| reviewMode | One of: flashcard, reverse, context | "Invalid review mode" |
| completedAt | Must be >= startedAt if set | "End time cannot be before start time" |

---

## State Transitions

### Mastery Level Progression

```
New (0) ──[first review correct]──▶ Learning (1)
    │                                    │
    │ [incorrect]                        │ [interval >= 7 days]
    ▼                                    ▼
Learning (1) ◀──────────────────── Reviewing (2)
    │                                    │
    │ [incorrect resets to 1 day]       │ [interval >= 21 days]
    │                                    ▼
    └──────────────────────────── Familiar (3)
                                         │
                                         │ [interval >= 60 days]
                                         ▼
                                    Mastered (4)
                                         │
                                         │ [incorrect answer]
                                         ▼
                                    (back to Learning)
```

### Sync Status Transitions

```
pending ──[sync attempt]──▶ synced
    │                          │
    │ [sync failed]           │ [local update]
    ▼                          ▼
failed ──[retry success]──▶ synced
    │
    │ [local update]
    ▼
pending (reset for retry)
```

---

## Data Size Estimates

| Entity | Avg Size | Expected Count | Total Size |
|--------|----------|----------------|------------|
| VocabularyEntry | ~2 KB | 5,000 | ~10 MB |
| ReviewSession | ~200 B | 1,000 | ~200 KB |
| LearningStats | ~100 B | 365 (1 year) | ~36 KB |
| **Total** | - | - | **~10.2 MB** |

**Chrome Extension Storage**:
- `chrome.storage.local`: 10 MB quota (sufficient)
- `chrome.storage.sync`: 100 KB quota (settings only)

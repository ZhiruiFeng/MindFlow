# Research: Vocabulary Learning Feature

**Feature**: 001-vocabulary-learning
**Date**: 2026-01-09
**Status**: Complete

## Overview

This document captures research findings for implementing the vocabulary learning feature in MindFlow. Key areas investigated: spaced repetition algorithm, AI prompt design for vocabulary explanations, Core Data schema patterns, and Chrome extension storage strategies.

---

## R1: Spaced Repetition Algorithm Selection

### Decision
Implement a **simplified SM-2 algorithm** for spaced repetition scheduling.

### Rationale
- SM-2 is the foundational algorithm used by Anki and other successful spaced repetition systems
- Well-documented with predictable behavior
- Simple enough to implement without external dependencies
- Proven effectiveness for vocabulary learning specifically

### Alternatives Considered

| Algorithm | Pros | Cons | Decision |
|-----------|------|------|----------|
| **SM-2 (chosen)** | Simple, well-documented, proven for vocabulary | Less adaptive than newer variants | ✅ Best balance of simplicity and effectiveness |
| SM-5/SM-17 | More adaptive to individual patterns | Complex, requires more data | ❌ Overkill for MVP |
| Leitner System | Very simple box-based | Less granular intervals | ❌ Less effective long-term |
| FSRS (Free Spaced Repetition Scheduler) | Modern, highly optimized | Complex implementation | ❌ Consider for future iteration |

### Implementation Details

**SM-2 Algorithm (Simplified)**:
```
Parameters:
- EaseFactor (EF): starts at 2.5, min 1.3
- Interval: days until next review
- ResponseQuality (q): 0=forgot, 1=hard, 2=good

Algorithm:
if q >= 2 (correct):
    if interval == 0: interval = 1
    else if interval == 1: interval = 3
    else: interval = round(interval * EF)

    EF = EF + (0.1 - (2 - q) * 0.08)
    EF = max(1.3, EF)
else (incorrect):
    interval = 1
    EF = max(1.3, EF - 0.2)

nextReviewDate = today + interval
```

**Mastery Level Mapping**:
| Level | Name | Criteria |
|-------|------|----------|
| 0 | New | Just added, never reviewed |
| 1 | Learning | Interval < 7 days |
| 2 | Reviewing | 7 ≤ Interval < 21 days |
| 3 | Familiar | 21 ≤ Interval < 60 days |
| 4 | Mastered | Interval ≥ 60 days |

---

## R2: AI Prompt Design for Vocabulary Explanations

### Decision
Use a **single structured JSON prompt** that returns all word information in one API call.

### Rationale
- Single API call minimizes latency (vs. multiple calls for different fields)
- JSON response format ensures consistent parsing
- Comprehensive context in system prompt improves explanation quality for Chinese learners

### Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Single JSON prompt (chosen)** | Fast, consistent | Longer response | ✅ Best UX with <3s target |
| Multiple field-specific prompts | Shorter individual responses | 10x API calls, high latency | ❌ Poor UX |
| Streaming response | Progressive display | Complex parsing, partial states | ❌ Unnecessary complexity |

### Implementation Details

**System Prompt**:
```
You are a vocabulary assistant helping a Chinese speaker learn English.
Provide comprehensive word explanations optimized for second-language learners.
Focus on practical usage, memorable examples, and Chinese-specific learning tips.
Return ONLY valid JSON without markdown code blocks.
```

**User Prompt**:
```
Explain the English word: "{word}"
{context_if_provided}

Return JSON with this exact structure:
{
    "word": "the word as entered",
    "phonetic": "IPA pronunciation, e.g., /ˈwɜːrd/",
    "partOfSpeech": "noun/verb/adjective/adverb/etc",
    "definitionEN": "clear English definition",
    "definitionCN": "中文释义",
    "exampleSentences": [
        {"en": "Example sentence in English.", "cn": "中文翻译。"},
        {"en": "Another example.", "cn": "另一个例子。"}
    ],
    "synonyms": ["word1", "word2"],
    "antonyms": ["word1", "word2"],
    "wordFamily": "related forms: noun, verb, adjective, adverb",
    "usageNotes": "context, register, common collocations",
    "etymology": "brief word origin",
    "memoryTips": "mnemonic device for Chinese speakers"
}
```

**Error Handling**:
1. If word not found/invalid: Return error with suggestion
2. If JSON malformed: Retry once with stricter prompt
3. If API timeout: Allow manual entry fallback

---

## R3: Core Data Schema Design

### Decision
Create **three new Core Data entities** following existing MindFlow patterns: VocabularyEntry, ReviewSession, LearningStats.

### Rationale
- Follows existing LocalInteraction entity pattern
- Separate entities for clear data separation
- Indexed fields for performance (word, nextReviewAt)
- Sync metadata fields for cloud sync compatibility

### Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **3 entities (chosen)** | Clean separation, queryable | More entities to manage | ✅ Best for data modeling |
| Single entity with JSON | Simpler schema | Harder to query, no indexes | ❌ Poor for search/filtering |
| Extend LocalInteraction | Reuse existing | Conflates different concepts | ❌ Violates single responsibility |

### Implementation Details

**VocabularyEntry Entity** (30 attributes):
```
Core:
- id: UUID (primary key, indexed)
- word: String (required, indexed, case-insensitive)
- phonetic: String (optional)
- partOfSpeech: String (optional)
- definitionEN: String (optional)
- definitionCN: String (optional)
- exampleSentences: String (JSON array, optional)
- synonyms: String (comma-separated, optional)
- antonyms: String (comma-separated, optional)
- wordFamily: String (optional)
- usageNotes: String (optional)
- etymology: String (optional)
- memoryTips: String (optional)

Context:
- userContext: String (optional)
- sourceInteractionId: UUID (optional, relationship)
- tags: String (comma-separated, optional)
- category: String (optional)
- isFavorite: Boolean (default: false)
- isArchived: Boolean (default: false)

Spaced Repetition:
- masteryLevel: Int16 (default: 0)
- reviewCount: Int32 (default: 0)
- correctCount: Int32 (default: 0)
- lastReviewedAt: Date (optional)
- nextReviewAt: Date (optional, indexed)
- easeFactor: Double (default: 2.5)
- interval: Int32 (default: 0)

Sync:
- createdAt: Date (required)
- updatedAt: Date (required)
- syncStatus: String (default: "pending")
- backendId: String (optional)
```

**Indexes**:
- word (case-insensitive search)
- nextReviewAt (review queue queries)
- category (filtering)
- masteryLevel (statistics)

---

## R4: Chrome Extension Storage Strategy

### Decision
Use **Chrome Storage local** for vocabulary data with **index structures** for efficient querying.

### Rationale
- Chrome Storage local provides 10MB quota (sufficient for ~5,000 words at ~2KB each)
- JSON-based storage with index keys enables efficient lookups
- Follows existing MindFlow-Extension storage-manager.js patterns

### Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Chrome Storage local (chosen)** | Simple, sufficient quota | No SQL queries | ✅ Follows existing patterns |
| IndexedDB | Full database features | Complex API, overkill | ❌ Unnecessary complexity |
| Chrome Storage sync | Cross-device sync | 100KB limit | ❌ Too small for vocabulary |
| External API only | No local limits | Offline not possible | ❌ Violates local-first |

### Implementation Details

**Storage Key Structure**:
```javascript
// Individual entries (for efficient updates)
"vocab_entry_{uuid}": { ...VocabularyEntry object }

// Indexes (for efficient queries)
"vocab_index": {
    allIds: ["uuid1", "uuid2", ...],
    byWord: { "eloquent": "uuid1", "ubiquitous": "uuid2" },
    byCategory: { "work": ["uuid1"], "daily": ["uuid2"] },
    dueForReview: ["uuid1", "uuid3", ...]
}

// Settings (sync storage for cross-device)
"vocab_settings": {
    dailyNewWordsGoal: 5,
    dailyReviewGoal: 15,
    enableNotifications: true,
    reviewReminderTime: "09:00"
}
```

**Query Patterns**:
- Get all words: Read allIds, batch fetch entries
- Search: In-memory filter (acceptable for <5K entries)
- Due for review: Read dueForReview array, fetch entries
- By category: Read byCategory[cat], fetch entries

---

## R5: Supabase Cloud Sync Schema

### Decision
Create **vocabulary-specific tables** in Supabase following existing MindFlow sync patterns.

### Rationale
- Consistent with existing interactions table pattern
- Row-Level Security (RLS) for multi-user support
- Enables future cross-device sync feature

### Implementation Details

**Tables**:
```sql
-- vocabulary_entries
CREATE TABLE vocabulary_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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
    user_context TEXT,
    source_interaction_id UUID,
    tags TEXT[] DEFAULT '{}',
    category VARCHAR(100),
    is_favorite BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,
    mastery_level SMALLINT DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    last_reviewed_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ,
    ease_factor DECIMAL(3,2) DEFAULT 2.5,
    interval_days INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    client_id VARCHAR(255),
    CONSTRAINT unique_user_word UNIQUE (user_id, word)
);

-- Indexes
CREATE INDEX idx_vocab_user_id ON vocabulary_entries(user_id);
CREATE INDEX idx_vocab_word ON vocabulary_entries(word);
CREATE INDEX idx_vocab_next_review ON vocabulary_entries(user_id, next_review_at);

-- RLS
ALTER TABLE vocabulary_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own vocabulary" ON vocabulary_entries
    FOR ALL USING (auth.uid() = user_id);
```

---

## R6: Keyboard Shortcuts Design

### Decision
Follow **macOS conventions** with customizable shortcuts.

### Rationale
- Consistency with existing MindFlow shortcuts
- macOS modifier key conventions (⌘ for commands)
- Support muscle memory from other vocabulary apps

### Implementation Details

**Default Shortcuts**:
| Shortcut | Action | Context |
|----------|--------|---------|
| ⌘ N | Add new word | Vocabulary tab |
| ⌘ R | Start review | Vocabulary tab |
| ⌘ F | Focus search | Vocabulary tab |
| Space | Show answer | Review mode |
| 1 | Rate: Forgot | Review mode |
| 2 | Rate: Hard | Review mode |
| 3 | Rate: Good | Review mode |
| → | Skip card | Review mode |
| Esc | Exit/Close | Modal/Review |

**Chrome Extension**:
| Shortcut | Action |
|----------|--------|
| Alt + V | Open vocabulary popup |
| Alt + N | Quick add word |

---

## Summary of Decisions

| Area | Decision | Confidence |
|------|----------|------------|
| Spaced Repetition | Simplified SM-2 algorithm | High |
| AI Prompts | Single JSON prompt for all fields | High |
| Core Data | 3 entities (VocabularyEntry, ReviewSession, LearningStats) | High |
| Chrome Storage | local storage with index structures | High |
| Cloud Sync | Supabase tables with RLS | High |
| Keyboard Shortcuts | macOS conventions, customizable | High |

All research items resolved. No NEEDS CLARIFICATION remaining. Ready for Phase 1.

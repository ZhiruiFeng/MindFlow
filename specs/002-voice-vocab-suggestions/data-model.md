# Data Model: Voice-to-Text Vocabulary Suggestions

**Feature**: 002-voice-vocab-suggestions
**Date**: 2026-01-10
**Status**: Complete

## Overview

This feature introduces one new transient model (VocabularySuggestion) and extends the existing OptimizationResult/TranscriptionResult models. No new persistent entities are required as suggestions are converted to existing VocabularyEntry when saved.

## New Models

### VocabularySuggestion

**Purpose**: Represents a vocabulary word suggested for learning from a transcription. This is a transient display model - suggestions are not persisted until explicitly saved.

**Platform**: Both macOS (Swift) and Chrome Extension (JavaScript)

#### Swift Model

```swift
/// A vocabulary word suggested for learning from a transcription
struct VocabularySuggestion: Codable, Identifiable, Equatable {
    /// Unique identifier for SwiftUI list rendering
    var id: String { word.lowercased() }

    /// The suggested word
    let word: String

    /// Part of speech (noun, verb, adjective, etc.)
    let partOfSpeech: String

    /// Brief definition (1-2 sentences)
    let definition: String

    /// Why this word is worth learning
    let reason: String

    /// The sentence from transcription where word appears
    let sourceSentence: String

    /// Whether this word already exists in user's vocabulary
    var isAlreadySaved: Bool = false

    /// Whether the word is currently being added
    var isAdding: Bool = false

    /// Whether the word was just added (for UI feedback)
    var wasJustAdded: Bool = false
}
```

#### JavaScript Model

```javascript
/**
 * @typedef {Object} VocabularySuggestion
 * @property {string} word - The suggested word
 * @property {string} partOfSpeech - Part of speech (noun, verb, adjective, etc.)
 * @property {string} definition - Brief definition (1-2 sentences)
 * @property {string} reason - Why this word is worth learning
 * @property {string} sourceSentence - The sentence from transcription where word appears
 * @property {boolean} isAlreadySaved - Whether this word already exists in user's vocabulary
 * @property {boolean} isAdding - Whether the word is currently being added
 * @property {boolean} wasJustAdded - Whether the word was just added (for UI feedback)
 */
```

### Validation Rules

| Field | Required | Validation |
|-------|----------|------------|
| word | Yes | Non-empty string, max 100 chars |
| partOfSpeech | Yes | One of: noun, verb, adjective, adverb, preposition, conjunction, interjection, phrase |
| definition | Yes | Non-empty string, max 500 chars |
| reason | Yes | Non-empty string, max 300 chars |
| sourceSentence | Yes | Non-empty string, max 1000 chars |

## Extended Models

### OptimizationResult (Swift)

**Change**: Add `vocabularySuggestions` field

```swift
/// Result from text optimization with teacher explanation and vocabulary suggestions
struct OptimizationResult {
    let refinedText: String
    let teacherExplanation: String
    let vocabularySuggestions: [VocabularySuggestion]  // NEW
}
```

### TranscriptionResult (Swift)

**Change**: Add `vocabularySuggestions` field for UI display

```swift
struct TranscriptionResult {
    // ... existing fields ...

    /// Vocabulary words suggested for learning from this transcription
    var vocabularySuggestions: [VocabularySuggestion]?  // NEW
}
```

### LLM Response (JavaScript)

**Change**: Extend parsed result to include suggestions

```javascript
/**
 * @typedef {Object} OptimizationResult
 * @property {string} refinedText - The optimized text
 * @property {string} teacherNotes - Teaching feedback and improvements
 * @property {VocabularySuggestion[]} vocabularySuggestions - Suggested vocabulary to learn
 */
```

## Existing Models (Reused)

### VocabularyEntry (Core Data)

No changes required. When a suggestion is saved:
1. VocabularyLookupService fetches full word details
2. Full WordExplanation is converted to VocabularyEntry
3. `context` field is populated from suggestion's `sourceSentence`

### WordExplanation

No changes required. Used when expanding suggestion details or saving to vocabulary.

## State Transitions

### Suggestion Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    VocabularySuggestion States                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Generated] ──check vocabulary──▶ [Display Ready]              │
│                                         │                       │
│                                    ┌────┴────┐                  │
│                                    │         │                  │
│                              isAlreadySaved  !isAlreadySaved    │
│                                    │         │                  │
│                                    ▼         ▼                  │
│                              [Show View]  [Show Add]            │
│                                    │         │                  │
│                                    │    click Add               │
│                                    │         │                  │
│                                    │         ▼                  │
│                                    │   [isAdding=true]          │
│                                    │         │                  │
│                                    │    save complete           │
│                                    │         │                  │
│                                    │         ▼                  │
│                                    │   [wasJustAdded=true]      │
│                                    │         │                  │
│                                    └────┬────┘                  │
│                                         │                       │
│                                         ▼                       │
│                                   [Session End]                 │
│                                         │                       │
│                                  (discarded)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## LLM Response Format

The LLM response now includes three sections:

```
REFINED_TEXT:
[Optimized transcription text]

TEACHER_NOTE:
Score: [X/10]
Key improvements:
• [improvement 1]
• [improvement 2]
• [improvement 3]

VOCABULARY_SUGGESTIONS:
[
  {
    "word": "eloquent",
    "partOfSpeech": "adjective",
    "definition": "fluent or persuasive in speaking or writing",
    "reason": "More expressive than 'well-spoken', commonly used in professional contexts",
    "sourceSentence": "The speaker gave an eloquent presentation about climate change."
  },
  {
    "word": "concise",
    "partOfSpeech": "adjective",
    "definition": "giving a lot of information clearly in a few words",
    "reason": "Essential vocabulary for professional writing and speaking",
    "sourceSentence": "Keep your answers concise and to the point."
  }
]
```

## Relationships

```
┌─────────────────────────┐
│   TranscriptionResult   │
├─────────────────────────┤
│ - originalText          │
│ - optimizedText         │
│ - teacherExplanation    │
│ - vocabularySuggestions │───────┐
└─────────────────────────┘       │
                                  │ 0..3
                                  ▼
                    ┌─────────────────────────┐
                    │  VocabularySuggestion   │
                    ├─────────────────────────┤
                    │ - word                  │
                    │ - partOfSpeech          │
                    │ - definition            │
                    │ - reason                │
                    │ - sourceSentence        │
                    │ - isAlreadySaved        │
                    └─────────────────────────┘
                              │
                              │ on "Add" click
                              ▼
                    ┌─────────────────────────┐
                    │    WordExplanation      │
                    │    (full AI lookup)     │
                    └─────────────────────────┘
                              │
                              │ persist
                              ▼
                    ┌─────────────────────────┐
                    │    VocabularyEntry      │
                    │    (Core Data)          │
                    └─────────────────────────┘
```

## Storage Considerations

- **VocabularySuggestion**: In-memory only, not persisted
- **VocabularyEntry**: Existing Core Data entity, no schema changes
- **TranscriptionResult**: If persisted to history, vocabularySuggestions field can be nil (suggestions not needed for historical transcriptions)

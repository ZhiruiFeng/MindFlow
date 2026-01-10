# Quickstart: Voice-to-Text Vocabulary Suggestions

**Feature**: 002-voice-vocab-suggestions
**Date**: 2026-01-10

## Overview

This guide provides implementation patterns for adding vocabulary suggestions to the voice-to-text optimization flow. The feature extends existing LLMService prompts and PreviewView UI.

## Prerequisites

Before implementing, ensure you understand:
- [spec.md](./spec.md) - Feature requirements
- [research.md](./research.md) - Design decisions
- [data-model.md](./data-model.md) - Data structures

## Quick Reference

### Files to Modify

| Platform | File | Change |
|----------|------|--------|
| macOS | `Services/LLMService.swift` | Extend prompt, add parser |
| macOS | `Models/TranscriptionResult.swift` | Add suggestions field |
| macOS | `Views/PreviewView.swift` | Add suggestions section |
| macOS | `ViewModels/RecordingViewModel.swift` | Handle add action |
| Extension | `lib/llm-service.js` | Extend prompt, add parser |
| Extension | `popup/popup.js` | Display suggestions |
| Extension | `popup/popup.css` | Suggestion styles |

### Files to Create

| Platform | File | Purpose |
|----------|------|---------|
| macOS | `Models/VocabularySuggestion.swift` | Suggestion model |
| macOS | `Views/VocabularySuggestionView.swift` | Suggestion row component |
| Extension | `components/suggestion-row.js` | Suggestion component |

## Implementation Patterns

### 1. Model Definition (Swift)

```swift
// Models/VocabularySuggestion.swift

import Foundation

/// A vocabulary word suggested for learning from a transcription
struct VocabularySuggestion: Codable, Identifiable, Equatable {
    var id: String { word.lowercased() }

    let word: String
    let partOfSpeech: String
    let definition: String
    let reason: String
    let sourceSentence: String

    // UI state (not from LLM)
    var isAlreadySaved: Bool = false
    var isAdding: Bool = false
    var wasJustAdded: Bool = false

    enum CodingKeys: String, CodingKey {
        case word, partOfSpeech, definition, reason, sourceSentence
    }
}
```

### 2. Prompt Extension (Swift)

```swift
// In LLMService.swift - extend the systemPrompt in optimizeTextWithExplanation()

let systemPrompt = """
// ... existing prompt content ...

VOCABULARY_SUGGESTIONS:
[JSON array of vocabulary suggestions - see format below]

Vocabulary suggestion rules:
- Select 0-3 words from the transcription worth learning
- Prioritize: uncommon useful words, nuanced vocabulary, commonly confused words, eloquent alternatives
- Exclude: top 1000 frequency words, proper nouns (names/places), slang
- For each word provide as JSON:
  - word: the vocabulary word
  - partOfSpeech: noun/verb/adjective/adverb/phrase
  - definition: brief definition (1-2 sentences)
  - reason: why worth learning (max 50 words)
  - sourceSentence: the exact sentence from transcription
- Output as valid JSON array, or empty array [] if no good candidates
"""
```

### 3. Response Parser Extension (Swift)

```swift
// In LLMService.swift

struct OptimizationResult {
    let refinedText: String
    let teacherExplanation: String
    let vocabularySuggestions: [VocabularySuggestion]  // NEW
}

private func parseOptimizationResponse(_ response: String) throws -> OptimizationResult {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

    // Find markers
    guard let refinedRange = trimmed.range(of: "REFINED_TEXT:"),
          let teacherRange = trimmed.range(of: "TEACHER_NOTE:"),
          let vocabRange = trimmed.range(of: "VOCABULARY_SUGGESTIONS:") else {
        // Fallback: return response as refined text, empty suggestions
        return OptimizationResult(
            refinedText: trimmed,
            teacherExplanation: "No explanation provided",
            vocabularySuggestions: []
        )
    }

    // Extract refined text
    let refinedText = String(trimmed[refinedRange.upperBound..<teacherRange.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Extract teacher note
    let teacherExplanation = String(trimmed[teacherRange.upperBound..<vocabRange.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Extract and parse vocabulary suggestions
    let vocabJSON = String(trimmed[vocabRange.upperBound...])
        .trimmingCharacters(in: .whitespacesAndNewlines)

    var suggestions: [VocabularySuggestion] = []
    if let jsonData = vocabJSON.data(using: .utf8) {
        do {
            suggestions = try JSONDecoder().decode([VocabularySuggestion].self, from: jsonData)
        } catch {
            Logger.warning("Failed to parse vocabulary suggestions: \(error)", category: .optimization)
        }
    }

    return OptimizationResult(
        refinedText: refinedText,
        teacherExplanation: teacherExplanation,
        vocabularySuggestions: suggestions
    )
}
```

### 4. UI Component (SwiftUI)

```swift
// Views/VocabularySuggestionView.swift

import SwiftUI

struct VocabularySuggestionView: View {
    let suggestion: VocabularySuggestion
    let onAdd: () -> Void
    let onView: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.word)
                        .font(.headline)
                    Text("(\(suggestion.partOfSpeech))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(suggestion.definition)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Spacer()

            // Action button
            if suggestion.wasJustAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if suggestion.isAdding {
                ProgressView()
                    .scaleEffect(0.8)
            } else if suggestion.isAlreadySaved {
                Button("View") { onView() }
                    .buttonStyle(.bordered)
            } else {
                Button("Add") { onAdd() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }
}
```

### 5. Integration in PreviewView

```swift
// In PreviewView.swift - add after Teacher's Note section

// MARK: - Vocabulary Suggestions Section
if let suggestions = transcriptionResult.vocabularySuggestions,
   !suggestions.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Vocabulary to Learn")
            .font(.headline)

        ForEach(suggestions) { suggestion in
            VocabularySuggestionView(
                suggestion: suggestion,
                onAdd: { addToVocabulary(suggestion) },
                onView: { viewInVocabulary(suggestion) }
            )
            Divider()
        }
    }
    .padding()
    .background(Color.blue.opacity(0.05))
    .cornerRadius(8)
}
```

### 6. Add Action Handler

```swift
// In RecordingViewModel.swift or PreviewView.swift

@MainActor
func addToVocabulary(_ suggestion: VocabularySuggestion) async {
    // Update UI state
    updateSuggestion(suggestion.word) { $0.isAdding = true }

    do {
        // Fetch full word details
        let wordExplanation = try await VocabularyLookupService.shared.lookupWord(
            suggestion.word,
            context: suggestion.sourceSentence
        )

        // Save to vocabulary
        try VocabularyStorage.shared.addWord(from: wordExplanation)

        // Update UI state
        updateSuggestion(suggestion.word) {
            $0.isAdding = false
            $0.wasJustAdded = true
        }
    } catch {
        // Handle error
        updateSuggestion(suggestion.word) { $0.isAdding = false }
        Logger.error("Failed to add vocabulary: \(error)", category: .vocabulary)
    }
}
```

### 7. JavaScript Implementation (Extension)

```javascript
// In lib/llm-service.js - extend buildSystemPrompt()

buildSystemPrompt(level, style, includeTeacherNotes = false) {
    let basePrompt = SYSTEM_PROMPTS[level] || SYSTEM_PROMPTS.medium;

    // ... existing style and teacher notes code ...

    // Add vocabulary suggestions instruction
    basePrompt += `

VOCABULARY_SUGGESTIONS:
[JSON array of vocabulary suggestions]

Vocabulary suggestion rules:
- Select 0-3 words from the transcription worth learning
- Prioritize: uncommon useful words, nuanced vocabulary, commonly confused words
- Exclude: top 1000 frequency words, proper nouns, slang
- For each word: { word, partOfSpeech, definition, reason, sourceSentence }
- Output valid JSON array, or [] if no good candidates`;

    return basePrompt;
}

// Extend parseOptimizationResult()
parseOptimizationResult(response) {
    const trimmed = response.trim();

    const refinedMatch = trimmed.indexOf('REFINED_TEXT:');
    const teacherMatch = trimmed.indexOf('TEACHER_NOTE:');
    const vocabMatch = trimmed.indexOf('VOCABULARY_SUGGESTIONS:');

    // ... existing parsing for refinedText and teacherNotes ...

    // Parse vocabulary suggestions
    let vocabularySuggestions = [];
    if (vocabMatch !== -1) {
        const vocabStart = vocabMatch + 'VOCABULARY_SUGGESTIONS:'.length;
        const vocabJSON = trimmed.substring(vocabStart).trim();
        try {
            vocabularySuggestions = JSON.parse(vocabJSON);
        } catch (e) {
            console.warn('Failed to parse vocabulary suggestions:', e);
        }
    }

    return {
        refinedText,
        teacherNotes,
        vocabularySuggestions
    };
}
```

## Testing Checklist

- [ ] Prompt generates 0-3 relevant suggestions
- [ ] Parser handles all marker combinations gracefully
- [ ] Parser handles malformed JSON gracefully
- [ ] Add button shows loading state during API call
- [ ] Add button shows success state after save
- [ ] Already-saved words show "View" instead of "Add"
- [ ] Empty suggestions show appropriate message
- [ ] Suggestions don't break if teacher notes disabled
- [ ] Extension popup displays suggestions correctly

## Common Pitfalls

1. **JSON parsing in prompt response** - The LLM may add extra text around the JSON. Trim carefully.

2. **Marker order** - Always check markers exist before parsing. Handle missing markers gracefully.

3. **Duplicate vocabulary check** - Perform after suggestions received, not in prompt (would require context the LLM doesn't have).

4. **Loading states** - Don't block UI while adding. Show per-suggestion loading indicators.

5. **Token limits** - Adding vocabulary section increases prompt size. Stay within model limits.

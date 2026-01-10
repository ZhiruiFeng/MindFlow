# Research: Voice-to-Text Vocabulary Suggestions

**Feature**: 002-voice-vocab-suggestions
**Date**: 2026-01-10
**Status**: Complete

## Research Questions

### 1. How to extend the existing prompt without increasing API latency?

**Decision**: Add a `VOCABULARY_SUGGESTIONS:` section to the existing optimization prompt

**Rationale**:
- The current prompt already has a structured output format with `REFINED_TEXT:` and `TEACHER_NOTE:` markers
- Adding a third marker `VOCABULARY_SUGGESTIONS:` keeps the single API call pattern
- Token cost increase is minimal (~100 tokens for 3 brief suggestions)
- Parser already handles marker-based extraction

**Alternatives Considered**:
1. **Separate API call for suggestions** - Rejected because it doubles latency and cost
2. **Include full word details in suggestions** - Rejected because it bloats response size significantly
3. **Make suggestions optional via setting** - Accepted as enhancement; default enabled

### 2. What format should vocabulary suggestions use?

**Decision**: JSON array within the prompt response for reliable parsing

**Rationale**:
- JSON is easily parseable in both Swift and JavaScript
- Structured format ensures consistent data extraction
- LLM can reliably produce JSON when instructed
- Matches the pattern used by VocabularyLookupService for word explanations

**Format Selected**:
```json
[
  {
    "word": "eloquent",
    "partOfSpeech": "adjective",
    "definition": "fluent or persuasive in speaking or writing",
    "reason": "Impressive alternative to 'well-spoken' with stronger connotation",
    "sourceSentence": "The speaker gave an eloquent presentation."
  }
]
```

**Alternatives Considered**:
1. **Bullet point format** - Rejected because parsing is error-prone
2. **Pipe-delimited format** - Rejected because less readable and maintainable
3. **XML format** - Rejected because more verbose than JSON

### 3. How should the feature integrate with existing vocabulary storage?

**Decision**: Reuse existing VocabularyStorage.addWord() with context auto-population

**Rationale**:
- VocabularyStorage already has all CRUD methods needed
- VocabularyLookupService generates full WordExplanation on demand
- One-click flow: save brief suggestion → trigger full AI lookup → store complete entry
- Context field automatically set to source sentence from transcription

**Integration Flow**:
1. User clicks "Add" on suggestion
2. Call VocabularyLookupService.lookupWord(word, context: sourceSentence)
3. Save returned WordExplanation via VocabularyStorage.addWord()
4. Update UI to show "Added" state

**Alternatives Considered**:
1. **Pre-fetch all word details** - Rejected because it significantly increases initial response time
2. **Save only brief info, fetch details later** - Rejected because inconsistent with existing vocabulary entries
3. **Direct save without full lookup** - Rejected because vocabulary entries would have incomplete data

### 4. How to handle cases where no good vocabulary exists?

**Decision**: Allow 0-3 suggestions; display graceful empty state

**Rationale**:
- Not every transcription contains learnable words (e.g., "Hello, how are you?")
- Forcing 3 suggestions would produce low-quality results
- Empty state should not disrupt the transcription viewing experience

**Behavior**:
- If transcription has no notable vocabulary: show "No vocabulary suggestions for this transcription"
- If 1-2 good words exist: show only those, don't pad to 3
- Message should be subtle, not prominent

### 5. How to indicate words already in vocabulary?

**Decision**: Check local storage before displaying suggestions; show "Already saved" status

**Rationale**:
- Prevents duplicate entries in vocabulary
- User can still view existing entry if interested
- Check happens client-side after suggestions received

**Implementation**:
1. After parsing suggestions, query VocabularyStorage.fetchWord(byText:) for each word
2. If exists: show "Already in vocabulary" with "View" action instead of "Add"
3. If not exists: show normal "Add" action

### 6. What criteria should the LLM use to select vocabulary?

**Decision**: Prioritize learning value with specific selection rules in prompt

**Criteria** (in order of priority):
1. **Uncommon but useful**: Words outside top 3000 frequency that appear in professional/academic contexts
2. **Nuanced vocabulary**: Words with subtle meanings that non-native speakers often miss
3. **Common mistakes**: Words frequently confused or misused (affect/effect, comprise/compose)
4. **Phrasal sophistication**: More eloquent alternatives to simple expressions
5. **Domain-specific**: Technical terms relevant to the transcription's context

**Exclusions**:
- Top 1000 frequency words (the, is, have, etc.)
- Pure proper nouns (names, places, brands)
- Slang/informal that wouldn't appear in formal writing
- Words already suggested in recent transcriptions (stateless - rely on vocabulary check)

## Technical Decisions Summary

| Area | Decision | Key Reason |
|------|----------|------------|
| **API Pattern** | Single combined call with extra marker | Zero additional latency |
| **Response Format** | JSON array for suggestions | Reliable parsing |
| **Storage Integration** | Reuse existing VocabularyStorage | Consistency with vocabulary feature |
| **Full Details** | Fetch on-demand when adding | Balanced initial response time |
| **Empty State** | Allow 0-3 suggestions | Quality over quantity |
| **Duplicate Check** | Client-side post-parse | Simple, no prompt complexity |

## Implementation Notes

### Prompt Extension (Swift)
```swift
// Add after existing TEACHER_NOTE section in LLMService.swift
"""
VOCABULARY_SUGGESTIONS:
[JSON array of 0-3 vocabulary suggestions]

For vocabulary suggestions:
- Select 0-3 words worth learning from the transcription
- Prioritize: uncommon but useful words, nuanced vocabulary, common mistakes, eloquent alternatives
- Exclude: top 1000 frequency words, proper nouns, slang
- For each word provide: word, partOfSpeech, definition (brief, 1 sentence), reason (why learn), sourceSentence (from transcription)
- Output as valid JSON array
- If no good candidates, output empty array: []
"""
```

### Parser Extension
Both Swift and JavaScript parsers need to extract `VOCABULARY_SUGGESTIONS:` section and JSON.parse/decode the array.

### Model Extension
```swift
struct VocabularySuggestion: Codable {
    let word: String
    let partOfSpeech: String
    let definition: String
    let reason: String
    let sourceSentence: String
}
```

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| VocabularyStorage | ✅ Exists | Used for saving words |
| VocabularyLookupService | ✅ Exists | Used for full word details |
| VocabularyEntry (Core Data) | ✅ Exists | Storage entity |
| LLMService | ✅ Exists | Extend prompt |
| PreviewView | ✅ Exists | Extend UI |

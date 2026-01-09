# Vocabulary Learning Feature - Overview

## Introduction

The Vocabulary Learning feature is designed to help non-native English speakers (primarily Chinese speakers) improve their English vocabulary through their daily work. This feature integrates seamlessly with MindFlow's existing voice-to-text workflow, allowing users to capture, learn, and review new English words encountered during their productive activities.

## Problem Statement

As a Chinese speaker working with English content daily, there are several challenges:

1. **Context Loss**: Encountering new words but forgetting them quickly without proper documentation
2. **Fragmented Learning**: Using multiple apps/tools for vocabulary learning disrupts workflow
3. **Lack of Personalization**: Generic vocabulary apps don't focus on work-relevant terminology
4. **No Integration**: Existing tools don't connect vocabulary learning with actual usage context
5. **Review Inefficiency**: Without spaced repetition, learned words are easily forgotten

## Solution Overview

MindFlow Vocabulary Learning provides an integrated solution that:

- Captures English words directly within the MindFlow workflow
- Generates comprehensive explanations using AI (definitions, pronunciation, examples, Chinese translations)
- Stores vocabulary locally with optional cloud sync
- Supports spaced repetition for effective long-term retention
- Tracks learning progress and statistics

## Target Users

- **Primary**: Chinese speakers working with English content (developers, researchers, business professionals)
- **Secondary**: Any non-native English speaker using MindFlow for productivity

## Core Features

### 1. Word Input & Capture

- **Manual Input**: Type or paste English words directly
- **Voice Input**: Speak the word using MindFlow's existing voice recording
- **Context Capture**: Optionally save the context/sentence where the word was encountered
- **Quick Add**: Keyboard shortcut for rapid word capture without interrupting workflow

### 2. AI-Powered Word Explanation

Using OpenAI's GPT model (existing LLM service), generate comprehensive word information:

| Field | Description | Example |
|-------|-------------|---------|
| **Word** | The English word | "eloquent" |
| **Phonetic** | IPA pronunciation | /ˈeləkwənt/ |
| **Part of Speech** | Grammatical category | adjective |
| **Definition (EN)** | English definition | "fluent or persuasive in speaking or writing" |
| **Definition (CN)** | Chinese translation | "雄辩的，有口才的" |
| **Example Sentences** | 2-3 contextual examples | "She gave an eloquent speech at the conference." |
| **Synonyms** | Related words | "articulate, fluent, expressive" |
| **Antonyms** | Opposite words | "inarticulate, tongue-tied" |
| **Word Family** | Related forms | "eloquence (n.), eloquently (adv.)" |
| **Usage Notes** | Context/register info | "Formal, often used in academic or professional contexts" |
| **Etymology** | Word origin (optional) | "From Latin 'eloquens', present participle of 'eloqui' (to speak out)" |
| **Memory Tips** | Mnemonic hints | "Think of 'e-' (out) + 'loqu' (speak) = speaking out fluently" |

### 3. Vocabulary Storage

- **Local-First**: All words stored locally using Core Data (macOS) / Chrome Storage (extension)
- **Cloud Sync**: Optional sync to Supabase/ZephyrOS for cross-device access
- **Organization**: Support for tags, categories, and custom word lists
- **Search**: Full-text search across all vocabulary entries

### 4. Learning & Review System

#### Spaced Repetition Algorithm (SM-2 based)

Implement a simplified spaced repetition system for effective long-term retention:

```
Review Intervals:
- New word: Review in 1 day
- First review (correct): Review in 3 days
- Second review (correct): Review in 7 days
- Third review (correct): Review in 14 days
- Subsequent reviews: interval × 2 (max 60 days)
- Incorrect answer: Reset to 1 day
```

#### Review Modes

1. **Flashcard Mode**: Show word, recall meaning
2. **Reverse Mode**: Show Chinese definition, recall English word
3. **Context Mode**: Fill-in-the-blank with example sentences
4. **Listening Mode**: Hear pronunciation, type the word

### 5. Progress Tracking

- **Learning Statistics**: Words learned, review accuracy, streak days
- **Mastery Levels**: New → Learning → Reviewing → Mastered
- **Daily Goals**: Configurable daily new words and review targets
- **Progress Visualization**: Charts showing learning progress over time

## Integration with Existing MindFlow Features

### Voice Recording Integration

When transcribing voice, users can:
- Long-press a word in the transcription to look it up
- Save unfamiliar words from transcriptions directly to vocabulary
- Voice input for adding new words

### Teacher Explanation Feature

The existing "Teacher Explanation" feature can be extended to:
- Identify potentially unfamiliar words in transcriptions
- Suggest adding them to vocabulary
- Provide contextual explanations

### History Integration

- View vocabulary entries alongside interaction history
- Link words to the transcription where they were encountered
- Search across both transcriptions and vocabulary

## User Workflow Examples

### Workflow 1: Quick Word Lookup

```
1. User encounters unknown word "ubiquitous" in document
2. Opens MindFlow, switches to Vocabulary tab
3. Types or speaks "ubiquitous"
4. AI generates comprehensive explanation
5. User saves to vocabulary with one click
6. Word appears in next review session
```

### Workflow 2: Transcription Integration

```
1. User records voice memo with technical content
2. Transcription shows text with unfamiliar term "idempotent"
3. User long-presses the word
4. Quick action shows "Add to Vocabulary"
5. AI explanation appears, user confirms save
6. Context from transcription saved with word
```

### Workflow 3: Daily Review

```
1. User opens MindFlow in the morning
2. Notification shows "15 words ready for review"
3. User enters Flashcard Review mode
4. Reviews words, marking correct/incorrect
5. Progress tracked, intervals adjusted
6. Daily streak updated
```

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Words Added (weekly) | 20+ | Count of new entries |
| Review Completion | 80%+ | Reviews done / Reviews due |
| Retention Rate | 85%+ | Correct reviews / Total reviews |
| Feature Usage | 3+ sessions/week | Active usage tracking |

## Technical Requirements

### Platform Support

| Platform | Storage | Sync | Review Notifications |
|----------|---------|------|---------------------|
| macOS App | Core Data | Supabase/ZephyrOS | Native notifications |
| Chrome Extension | Chrome Storage | Same backend | Browser notifications |

### API Dependencies

- **OpenAI GPT API**: Word explanation generation (existing LLM service)
- **Text-to-Speech API**: Optional pronunciation audio (future enhancement)

### Performance Requirements

- Word lookup: < 3 seconds (including AI generation)
- Local search: < 100ms
- Sync latency: < 5 seconds
- Offline capability: Full functionality without internet (except AI lookup)

## Privacy Considerations

- Vocabulary data follows MindFlow's privacy-first approach
- Local storage by default, cloud sync is opt-in
- No vocabulary data shared without explicit consent
- API calls for word lookup follow existing privacy practices

## Future Enhancements (Out of Scope for MVP)

1. **Text-to-Speech**: Native pronunciation audio playback
2. **Import/Export**: CSV, Anki deck format support
3. **Gamification**: Achievements, leaderboards, challenges
4. **Social Features**: Share word lists, collaborative learning
5. **Browser Integration**: Highlight unknown words on any webpage
6. **Intelligent Suggestions**: AI suggests related words to learn
7. **Custom Prompts**: Let users customize explanation format

## Conclusion

The Vocabulary Learning feature extends MindFlow's productivity capabilities by integrating seamless vocabulary building into the user's daily workflow. By leveraging existing AI services and following the local-first architecture, this feature helps Chinese speakers and other non-native English users improve their English vocabulary efficiently without disrupting their work.

---

**Related Documents:**
- [Database Design](./database-design.md)
- [UI/UX Design](./ui-design.md)
- [Implementation Plan](./implementation-plan.md)

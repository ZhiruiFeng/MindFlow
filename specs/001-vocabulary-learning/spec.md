# Feature Specification: Vocabulary Learning

**Feature Branch**: `001-vocabulary-learning`
**Created**: 2026-01-09
**Status**: Draft
**Input**: User description: "Vocabulary Learning Feature for non-native English speakers - implementation based on docs/vocabulary"

## Overview

The Vocabulary Learning feature helps non-native English speakers (primarily Chinese speakers) improve their English vocabulary through their daily work. It integrates with MindFlow's existing voice-to-text workflow, allowing users to capture, learn, and review new English words encountered during productive activities.

### Problem Statement

- **Context Loss**: Users encounter new words but forget them quickly without proper documentation
- **Fragmented Learning**: Using multiple apps disrupts workflow
- **Lack of Personalization**: Generic vocabulary apps don't focus on work-relevant terminology
- **No Integration**: Existing tools don't connect vocabulary learning with actual usage context
- **Review Inefficiency**: Without spaced repetition, learned words are easily forgotten

### Target Users

- **Primary**: Chinese speakers working with English content (developers, researchers, business professionals)
- **Secondary**: Any non-native English speaker using MindFlow for productivity

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quick Word Lookup and Save (Priority: P1)

A user encounters an unfamiliar English word while working. They want to quickly look up the word's meaning, pronunciation, and Chinese translation, then save it for future review - all without significantly disrupting their workflow.

**Why this priority**: This is the core value proposition. Without the ability to add and understand words, no other feature matters. It addresses the primary pain points of context loss and fragmented learning.

**Independent Test**: Can be fully tested by typing a word, viewing the AI-generated explanation, and saving it to the vocabulary list. Delivers immediate value by providing comprehensive word information and persistent storage.

**Acceptance Scenarios**:

1. **Given** a user is on the Vocabulary tab, **When** they enter an English word and request a lookup, **Then** the system displays comprehensive word information including pronunciation, definitions (English and Chinese), example sentences, synonyms, and memory tips within 3 seconds.

2. **Given** the AI has generated a word explanation, **When** the user confirms to save the word, **Then** the word is persisted locally and appears in their vocabulary list immediately.

3. **Given** a user wants to add context, **When** they enter optional context about where they encountered the word before saving, **Then** this context is stored with the vocabulary entry.

4. **Given** a user is offline, **When** they try to look up a word, **Then** they see a clear error message explaining that lookup requires internet, with an option to manually enter word details.

---

### User Story 2 - Vocabulary Review with Spaced Repetition (Priority: P1)

A user wants to effectively memorize their saved vocabulary using scientifically-proven spaced repetition techniques. They review words through flashcards and the system automatically schedules future reviews based on their performance.

**Why this priority**: Learning vocabulary without review leads to forgetting. Spaced repetition is essential for long-term retention, making this equally critical to the add word feature for delivering the core learning value.

**Independent Test**: Can be fully tested by completing a review session with multiple words, rating recall quality for each, and verifying that review intervals are adjusted accordingly. Delivers value by enabling effective memorization.

**Acceptance Scenarios**:

1. **Given** a user has words due for review, **When** they open the vocabulary section, **Then** they see a notification indicating how many words are ready for review.

2. **Given** a user starts a review session, **When** a flashcard is shown, **Then** they see the word and pronunciation, and can reveal the full definition by pressing a button or spacebar.

3. **Given** a user is viewing a revealed flashcard, **When** they rate their recall (forgot/hard/good), **Then** the system calculates the next review date based on their response and updates the word's review schedule.

4. **Given** a user marks a word as "forgot," **When** the review interval is recalculated, **Then** the word is scheduled for review the next day and the ease factor is decreased.

5. **Given** a user completes a review session, **When** viewing the summary, **Then** they see their accuracy rate, number of words reviewed, and updated streak information.

---

### User Story 3 - Browse and Manage Vocabulary (Priority: P2)

A user wants to browse their saved vocabulary, search for specific words, organize words by categories or tags, and manage their word collection.

**Why this priority**: Organization and retrieval become important as the vocabulary list grows. While not needed for initial use, it becomes essential for ongoing engagement and efficient learning.

**Independent Test**: Can be fully tested by viewing a vocabulary list, searching for a word, filtering by category, and editing/deleting entries. Delivers value by enabling efficient vocabulary management.

**Acceptance Scenarios**:

1. **Given** a user is on the vocabulary list view, **When** they type in the search box, **Then** the list filters to show only words matching the search query (across word, definitions, and tags).

2. **Given** a user selects a category filter, **When** the filter is applied, **Then** only words in that category are displayed.

3. **Given** a user selects a word from the list, **When** viewing the detail view, **Then** they see all word information including definitions, examples, synonyms, antonyms, etymology, memory tips, and review history.

4. **Given** a user is viewing a word detail, **When** they edit the category, tags, or add notes, **Then** the changes are saved and reflected immediately.

5. **Given** a user wants to remove a word, **When** they delete it, **Then** the word is removed from their vocabulary and no longer appears in review sessions.

---

### User Story 4 - Track Learning Progress (Priority: P2)

A user wants to see their learning progress over time, including words learned, review accuracy, and learning streaks, to stay motivated and understand their vocabulary growth.

**Why this priority**: Progress tracking provides motivation and accountability. It helps users maintain consistency in their learning habit, which is crucial for long-term success.

**Independent Test**: Can be fully tested by viewing the statistics view after adding words and completing reviews. Delivers value by providing insight into learning progress and maintaining motivation.

**Acceptance Scenarios**:

1. **Given** a user opens the statistics view, **When** the view loads, **Then** they see their total word count broken down by mastery level (new, learning, reviewing, mastered).

2. **Given** a user has been using the feature regularly, **When** viewing statistics, **Then** they see their current learning streak (consecutive days with at least one review).

3. **Given** a user views weekly statistics, **When** the data loads, **Then** they see a visual representation of words added and reviewed per day.

4. **Given** a user has completed reviews, **When** viewing statistics, **Then** they see their overall review accuracy percentage.

---

### User Story 5 - Quick Add from Web Pages (Priority: P3)

A user is reading web content and encounters an unfamiliar word. They want to quickly look it up and add it to their vocabulary without leaving the page (Chrome extension).

**Why this priority**: This enhances convenience but requires the Chrome extension platform. The core value can be delivered through the main app first.

**Independent Test**: Can be fully tested by selecting text on a webpage, using the context menu to look up the word, and saving it. Delivers value by reducing friction in the word capture process.

**Acceptance Scenarios**:

1. **Given** a user selects text on a webpage, **When** they right-click and select the MindFlow lookup option, **Then** an inline popup appears with the word explanation.

2. **Given** the inline popup is showing, **When** the user clicks "Add to Vocabulary," **Then** the word is saved and the user receives confirmation without navigating away from the page.

3. **Given** the user is using the extension popup, **When** they enter a word and look it up, **Then** they receive the same comprehensive explanation as in the main app.

---

### User Story 6 - Add Words from Transcriptions (Priority: P3)

A user completes a voice recording and sees unfamiliar words in the transcription. They want to quickly add those words to their vocabulary with the original context preserved.

**Why this priority**: This integrates vocabulary learning with MindFlow's existing voice transcription feature, providing contextual learning. Depends on having core vocabulary features working first.

**Independent Test**: Can be fully tested by recording audio, identifying an unfamiliar word in the transcription, and adding it to vocabulary with context. Delivers value by capturing words in their natural usage context.

**Acceptance Scenarios**:

1. **Given** a user is viewing a transcription, **When** they long-press or right-click on a word, **Then** they see an option to add it to vocabulary.

2. **Given** a user selects "Add to Vocabulary" from a transcription, **When** the word is looked up, **Then** the sentence context from the transcription is automatically included.

3. **Given** a word is saved with transcription context, **When** viewing the word detail, **Then** the user can see where and when they originally encountered the word.

---

### User Story 7 - Cross-Device Sync (Priority: P3)

A user wants their vocabulary to sync across their macOS app and Chrome extension so they can review words on any device.

**Why this priority**: Sync is valuable for users with multiple devices but adds complexity. The core learning experience works without it.

**Independent Test**: Can be fully tested by adding a word on one device and verifying it appears on another after sync. Delivers value by enabling flexible learning across devices.

**Acceptance Scenarios**:

1. **Given** a user has enabled cloud sync, **When** they add a word on one device, **Then** the word appears on their other devices after a short sync delay (under 5 seconds on good connection).

2. **Given** a user completes a review on one device, **When** they open the app on another device, **Then** the review progress is reflected and the word is not due for review again.

3. **Given** sync is enabled but the user is offline, **When** they make changes, **Then** the changes are queued locally and synced when connectivity is restored.

---

### Edge Cases

- What happens when a user enters a misspelled word? The AI attempts to identify the intended word and may suggest corrections, otherwise treats it as the entered text.
- What happens when a user enters a word that already exists in their vocabulary? The system notifies them and offers to update the existing entry or view it.
- How does the system handle multi-word phrases or idioms? The system accepts phrases up to 5 words and generates appropriate explanations.
- What happens if the AI fails to generate an explanation? The user sees an error message with options to retry or manually enter the word details.
- How does the system handle words with multiple meanings? The AI provides the most common meanings with context notes about different usages.
- What happens when a user has hundreds of words due for review? Reviews are capped at the user's daily goal setting, prioritizing overdue words first.

## Requirements *(mandatory)*

### Functional Requirements

**Word Input & Capture**
- **FR-001**: System MUST allow users to input English words via text entry
- **FR-002**: System MUST allow users to input words via voice using existing voice recording capability
- **FR-003**: System MUST allow users to optionally provide context about where they encountered the word
- **FR-004**: System MUST support adding custom tags and categories to vocabulary entries
- **FR-005**: System MUST prevent duplicate word entries, notifying users when a word already exists

**AI-Powered Word Explanation**
- **FR-006**: System MUST generate comprehensive word explanations including: phonetic pronunciation (IPA), part of speech, English definition, Chinese translation, example sentences with translations, synonyms, antonyms, word family, usage notes, etymology, and memory tips
- **FR-007**: System MUST complete word lookups within 3 seconds under normal conditions
- **FR-008**: System MUST gracefully handle lookup failures with clear error messages and fallback options

**Vocabulary Storage**
- **FR-009**: System MUST persist all vocabulary entries locally on the user's device
- **FR-010**: System MUST support full-text search across words, definitions, and tags
- **FR-011**: System MUST support filtering vocabulary by category, tags, mastery level, and favorite status
- **FR-012**: System MUST support editing and deleting vocabulary entries
- **FR-013**: System MUST maintain offline functionality for browsing and reviewing locally stored vocabulary

**Spaced Repetition System**
- **FR-014**: System MUST implement spaced repetition scheduling based on user performance (SM-2 algorithm variant)
- **FR-015**: System MUST track mastery levels: New, Learning, Reviewing, Familiar, Mastered
- **FR-016**: System MUST recalculate review intervals after each review based on recall quality rating
- **FR-017**: System MUST reset review interval to 1 day when a user marks a word as "forgot"
- **FR-018**: System MUST progressively increase intervals for correctly recalled words (1 → 3 → 7 → 14 → 28+ days)

**Review Interface**
- **FR-019**: System MUST provide flashcard-style review showing word first, then revealing full explanation
- **FR-020**: System MUST allow users to rate their recall (forgot, hard, good) after each card
- **FR-021**: System MUST support keyboard shortcuts for efficient review (spacebar to reveal, 1/2/3 for ratings)
- **FR-022**: System MUST display review progress during a session (current/total, accuracy)
- **FR-023**: System MUST show session summary upon completion with stats and streak update

**Progress Tracking**
- **FR-024**: System MUST track and display total word count by mastery level
- **FR-025**: System MUST track and display consecutive days of learning activity (streak)
- **FR-026**: System MUST track and display review accuracy rate
- **FR-027**: System MUST allow users to set daily goals for new words and reviews

**Platform Support**
- **FR-028**: System MUST function on macOS through the native MindFlow app
- **FR-029**: System MUST function in Chrome browser through the MindFlow extension
- **FR-030**: System MUST support optional cloud sync between platforms

**Settings & Configuration**
- **FR-031**: System MUST allow users to configure daily learning goals (new words and reviews)
- **FR-032**: System MUST allow users to enable/disable review reminder notifications
- **FR-033**: System MUST allow users to set preferred review reminder time

### Key Entities

- **Vocabulary Entry**: Represents a single word in the user's vocabulary. Contains the word itself, phonetic pronunciation, part of speech, English and Chinese definitions, example sentences, synonyms, antonyms, word family relationships, usage notes, etymology, memory tips, user-provided context, tags, category, mastery level, review scheduling data (interval, ease factor, next review date), and favorite/archived status.

- **Review Session**: Represents a single review study session. Contains session timing (start, end, duration), number of words reviewed, correct/incorrect/skipped counts, review mode used, and overall accuracy.

- **Learning Statistics**: Represents aggregated daily learning activity. Contains date, words added count, words reviewed count, correct/incorrect review counts, total study time, and current streak day count.

## Assumptions

- Users have access to the internet for initial word lookups (AI generation requires API calls)
- The existing MindFlow LLM service is available and can be used for word explanations
- Users are primarily learning English as a second language with Chinese as their first language
- The SM-2 algorithm variant with simplified intervals is sufficient for effective spaced repetition
- Chrome extension has sufficient storage quota (10MB local storage) for vocabulary data
- Users will primarily use the feature for single words, though short phrases are supported

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete the full word lookup and save flow in under 10 seconds (excluding AI generation time)
- **SC-002**: Users can complete a 15-word review session in under 5 minutes
- **SC-003**: Word search returns relevant results in under 100 milliseconds for vocabularies up to 5,000 words
- **SC-004**: 85% or higher long-term retention rate (words answered correctly after reaching "mastered" level)
- **SC-005**: Users add at least 20 new words per week on average (engagement metric)
- **SC-006**: Users complete at least 80% of due reviews (review completion rate)
- **SC-007**: Users maintain learning streaks of 7+ days (habit formation metric)
- **SC-008**: System supports offline browsing and review with full functionality when internet is unavailable

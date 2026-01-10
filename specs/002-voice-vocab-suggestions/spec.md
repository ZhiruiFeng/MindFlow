# Feature Specification: Voice-to-Text Vocabulary Suggestions

**Feature Branch**: `002-voice-vocab-suggestions`
**Created**: 2026-01-10
**Status**: Draft
**Input**: User description: "for the main feature of voice to text, we can refine the improvement prompt to ask it suggest 3 suggestions of words to learn. Then we can support one click to add the word into our vocabulary."

## Overview

This feature enhances MindFlow's existing voice-to-text improvement prompt to automatically suggest 3 vocabulary words worth learning from the transcribed content. Users can then add any suggested word to their vocabulary collection with a single click, seamlessly integrating vocabulary learning into the transcription workflow.

### Problem Statement

- **Missed Learning Opportunities**: Users transcribe content containing unfamiliar words but don't have a convenient way to capture them for learning
- **Manual Discovery**: Currently, users must manually identify and look up words from transcriptions
- **Workflow Interruption**: Adding words to vocabulary requires switching context from the transcription view

### Target Users

- **Primary**: MindFlow users who use voice-to-text features and want to expand their English vocabulary
- **Secondary**: Non-native English speakers using MindFlow for productivity with transcriptions

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Receive Vocabulary Suggestions After Transcription (Priority: P1)

A user completes a voice recording and receives the improved transcription. Along with the improved text, they see 3 suggested words from the transcription that would be valuable to learn, each with a brief explanation of why it's suggested.

**Why this priority**: This is the core feature that surfaces learning opportunities from transcriptions. Without vocabulary suggestions appearing, users cannot benefit from the one-click add feature.

**Independent Test**: Can be fully tested by completing a voice recording with moderately complex vocabulary, viewing the improved transcription, and verifying that 3 relevant vocabulary suggestions appear with clear explanations.

**Acceptance Scenarios**:

1. **Given** a user has completed a voice recording, **When** the improvement prompt processes the transcription, **Then** the system displays 3 vocabulary word suggestions alongside the improved text.

2. **Given** a transcription contains advanced or less common words, **When** suggestions are generated, **Then** each suggestion includes the word, its definition, and a brief reason why it's worth learning.

3. **Given** a transcription contains only common words, **When** suggestions are generated, **Then** the system still provides 3 suggestions focusing on words that have nuanced usage or are commonly misused.

4. **Given** a transcription is very short (under 10 words), **When** suggestions are generated, **Then** the system provides as many relevant suggestions as possible (1-3) or indicates no suggestions available if appropriate.

---

### User Story 2 - One-Click Add Word to Vocabulary (Priority: P1)

A user sees a suggested vocabulary word they want to learn and adds it to their vocabulary collection with a single click, without leaving the transcription view.

**Why this priority**: This completes the core value loop. Suggestions without an easy way to save them provide minimal value. One-click add removes friction from vocabulary capture.

**Independent Test**: Can be fully tested by clicking the add button on a suggested word and verifying it appears in the vocabulary collection with AI-generated details.

**Acceptance Scenarios**:

1. **Given** a user views vocabulary suggestions, **When** they click the "Add" button on a suggested word, **Then** the word is immediately added to their vocabulary collection.

2. **Given** a user adds a suggested word, **When** the add action completes, **Then** they see visual confirmation (button state change) without navigating away from the transcription.

3. **Given** a user adds a suggested word, **When** the word is saved, **Then** the original transcription context is automatically included as the word's context.

4. **Given** a user tries to add a word that already exists in their vocabulary, **When** they click Add, **Then** they see a notification that the word already exists with an option to view it.

---

### User Story 3 - View Full Word Details Before Adding (Priority: P2)

A user wants to see more details about a suggested word before deciding whether to add it to their vocabulary.

**Why this priority**: While not essential for the core flow, this helps users make informed decisions about which words to save, improving the quality of their vocabulary collection.

**Independent Test**: Can be fully tested by clicking on a suggested word to expand details and viewing the full AI-generated explanation.

**Acceptance Scenarios**:

1. **Given** a user views vocabulary suggestions, **When** they click/tap on a word to expand it, **Then** they see the full AI-generated word details (pronunciation, definitions, examples, etc.).

2. **Given** a user is viewing expanded word details, **When** they click "Add to Vocabulary," **Then** the word is saved with all the displayed details.

3. **Given** a user is viewing expanded word details, **When** they click outside or press a collapse button, **Then** the details collapse back to the summary view.

---

### Edge Cases

- What happens when the AI cannot identify any learnable words? The system displays a message indicating no vocabulary suggestions for this transcription.
- What happens if the same word appears multiple times in a transcription? The word is suggested only once, with context from its most relevant usage.
- How does the system handle proper nouns or technical jargon? The system may suggest domain-specific terms if they have general learning value, but excludes pure proper nouns (names, places) from suggestions.
- What happens if the user has already added all suggested words? Each suggestion shows "Already in vocabulary" status with option to view instead of add.
- What happens if vocabulary storage is full (extension storage limits)? User is prompted to sync to cloud or remove some words before adding new ones.

## Requirements *(mandatory)*

### Functional Requirements

**Vocabulary Suggestion Generation**
- **FR-001**: System MUST generate exactly 3 vocabulary suggestions from each improved transcription
- **FR-002**: System MUST include for each suggestion: the word, part of speech, brief definition, and reason for suggestion
- **FR-003**: System MUST prioritize suggestions based on learning value (uncommon words, nuanced usage, frequently confused words)
- **FR-004**: System MUST exclude from suggestions: very common words (top 1000 frequency), pure proper nouns, and words already in user's vocabulary
- **FR-005**: System MUST generate suggestions within the same request as the transcription improvement (no additional latency for suggestions)

**One-Click Add Functionality**
- **FR-006**: System MUST provide a visible "Add" action for each suggested word
- **FR-007**: System MUST add the word to vocabulary with a single user action (one click/tap)
- **FR-008**: System MUST automatically include the transcription sentence as word context when adding
- **FR-009**: System MUST trigger full AI word detail generation when a word is added (reusing existing vocabulary lookup)
- **FR-010**: System MUST show immediate visual feedback when a word is added (button state change, confirmation indicator)

**User Interface Integration**
- **FR-011**: System MUST display vocabulary suggestions in a dedicated section below or alongside the improved transcription
- **FR-012**: System MUST allow users to expand a suggestion to see full word details before adding
- **FR-013**: System MUST indicate when a suggested word already exists in the user's vocabulary
- **FR-014**: System MUST not disrupt the primary transcription viewing experience (suggestions are supplementary)

**Prompt Refinement**
- **FR-015**: System MUST modify the existing improvement prompt to request vocabulary suggestions as structured output
- **FR-016**: System MUST maintain existing transcription improvement quality while adding suggestion capability

### Key Entities

- **Vocabulary Suggestion**: A word suggested for learning from a transcription. Contains the word, part of speech, brief definition (1-2 sentences), reason for suggestion, source sentence from transcription, and suggestion timestamp. Exists only temporarily until user decides to add or dismiss.

- **Transcription Context**: The sentence or surrounding text from which a suggested word was extracted. Automatically captured and associated with vocabulary entries added via suggestion.

## Assumptions

- The existing transcription improvement prompt can be extended to return vocabulary suggestions without significantly increasing response time
- Users have the vocabulary learning feature enabled and available
- The LLM can reliably identify learning-worthy vocabulary from transcription content
- 3 suggestions per transcription provides good balance between value and noise
- Users prefer contextual vocabulary capture over manual word entry when the context is readily available

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can view vocabulary suggestions within the same response as the improved transcription (no additional wait time beyond current improvement latency)
- **SC-002**: Users can add a suggested word to their vocabulary in under 2 seconds (from click to confirmation)
- **SC-003**: At least 70% of suggestions are relevant and learnable words (measured by user add rate)
- **SC-004**: Users who enable this feature add at least 30% more words to their vocabulary compared to manual-only entry
- **SC-005**: 90% of users who try the feature continue using it (feature retention)
- **SC-006**: Transcription improvement quality remains consistent (no degradation from prompt changes)

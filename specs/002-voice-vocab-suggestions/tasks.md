# Tasks: Voice-to-Text Vocabulary Suggestions

**Input**: Design documents from `/specs/002-voice-vocab-suggestions/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in spec - test tasks omitted.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1, US2, US3)
- All file paths are relative to repository root

## Path Conventions

This is a multi-platform project:
- **macOS App**: `MindFlow/MindFlow/`
- **Chrome Extension**: `MindFlow-Extension/src/`

---

## Phase 1: Setup

**Purpose**: Create new model files needed across stories

- [X] T001 [P] Create VocabularySuggestion model in MindFlow/MindFlow/Models/VocabularySuggestion.swift
- [X] T002 [P] Add vocabularySuggestions field to OptimizationResult struct in MindFlow/MindFlow/Services/LLMService.swift
- [X] T003 [P] Add vocabularySuggestions field to TranscriptionResult in MindFlow/MindFlow/Models/TranscriptionResult.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend LLM prompts and parsers - MUST complete before UI work

**⚠️ CRITICAL**: User stories depend on suggestions being generated and parsed

### macOS App

- [X] T004 Extend system prompt in LLMService.optimizeTextWithExplanation() to request VOCABULARY_SUGGESTIONS section in MindFlow/MindFlow/Services/LLMService.swift
- [X] T005 Implement parseVocabularySuggestions() to extract JSON from VOCABULARY_SUGGESTIONS marker in MindFlow/MindFlow/Services/LLMService.swift
- [X] T006 Update parseOptimizationResponse() to call parseVocabularySuggestions() and populate OptimizationResult in MindFlow/MindFlow/Services/LLMService.swift

### Chrome Extension

- [X] T007 [P] Extend buildSystemPrompt() to include VOCABULARY_SUGGESTIONS instructions in MindFlow-Extension/src/lib/llm-service.js
- [X] T008 Update parseOptimizationResult() to extract vocabularySuggestions JSON array in MindFlow-Extension/src/lib/llm-service.js

**Checkpoint**: Suggestions are now generated and parsed on both platforms

---

## Phase 3: User Story 1 - Receive Vocabulary Suggestions (Priority: P1) 🎯 MVP

**Goal**: Display 3 vocabulary suggestions alongside improved transcription

**Independent Test**: Complete a voice recording, view improved transcription, verify 3 relevant vocabulary suggestions appear with word, definition, and reason

### macOS Implementation

- [X] T009 [P] [US1] Create VocabularySuggestionRowView component displaying word, partOfSpeech, definition, reason in MindFlow/MindFlow/Views/VocabularySuggestionView.swift
- [X] T010 [US1] Add vocabulary suggestions section to PreviewView below teacher notes in MindFlow/MindFlow/Views/PreviewView.swift
- [X] T011 [US1] Pass vocabularySuggestions from RecordingViewModel to PreviewView in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T012 [US1] Handle empty suggestions state with "No vocabulary suggestions" message in MindFlow/MindFlow/Views/PreviewView.swift

### Chrome Extension Implementation

- [X] T013 [P] [US1] Create renderSuggestionRow() function for suggestion display in MindFlow-Extension/src/popup/popup.js
- [X] T014 [US1] Add vocabulary suggestions container to popup results area in MindFlow-Extension/src/popup/popup.js
- [X] T015 [P] [US1] Add CSS styles for suggestion rows (word, definition, reason layout) in MindFlow-Extension/src/popup/popup.css
- [X] T016 [US1] Handle empty suggestions with subtle message in MindFlow-Extension/src/popup/popup.js

**Checkpoint**: User Story 1 complete - suggestions display on both platforms

---

## Phase 4: User Story 2 - One-Click Add to Vocabulary (Priority: P1)

**Goal**: Add suggested word to vocabulary with single click, show visual feedback

**Independent Test**: Click Add button on suggestion, verify word appears in vocabulary with context from transcription

### macOS Implementation

- [X] T017 [US1→US2] Add "Add" button to VocabularySuggestionRowView with loading/success states in MindFlow/MindFlow/Views/VocabularySuggestionView.swift
- [X] T018 [US2] Implement addSuggestionToVocabulary() method calling VocabularyLookupService then VocabularyStorage in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T019 [US2] Update suggestion state to isAdding=true during API call, wasJustAdded=true on success in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T020 [US2] Check if word already exists via VocabularyStorage.fetchWord(byText:) and set isAlreadySaved in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T021 [US2] Show "Already in vocabulary" status with "View" action instead of "Add" in MindFlow/MindFlow/Views/VocabularySuggestionView.swift

### Chrome Extension Implementation

- [X] T022 [P] [US2] Add click handler for Add button calling vocabulary-storage.js in MindFlow-Extension/src/popup/popup.js
- [X] T023 [US2] Implement addSuggestionToVocabulary() calling vocabulary-lookup then storage in MindFlow-Extension/src/popup/popup.js
- [X] T024 [US2] Update button state to show spinner during add, checkmark on success in MindFlow-Extension/src/popup/popup.js
- [X] T025 [P] [US2] Add CSS for button states (default, loading, success, already-saved) in MindFlow-Extension/src/popup/popup.css
- [X] T026 [US2] Check existing vocabulary and show "Already saved" status in MindFlow-Extension/src/popup/popup.js

**Checkpoint**: User Stories 1 & 2 complete - suggestions display and can be added

---

## Phase 5: User Story 3 - View Full Details Before Adding (Priority: P2)

**Goal**: Expand suggestion to see full AI-generated word details before adding

**Independent Test**: Click suggestion to expand, verify full details (pronunciation, examples, etc.) appear, add from expanded view

### macOS Implementation

- [X] T027 [P] [US3] Create SuggestionDetailView showing full WordExplanation fields in MindFlow/MindFlow/Views/VocabularySuggestionView.swift
- [X] T028 [US3] Add expand/collapse interaction to VocabularySuggestionRowView in MindFlow/MindFlow/Views/VocabularySuggestionView.swift
- [X] T029 [US3] Implement fetchFullDetails() calling VocabularyLookupService on expand in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T030 [US3] Cache fetched details to avoid re-fetching on expand/collapse in MindFlow/MindFlow/ViewModels/RecordingViewModel.swift
- [X] T031 [US3] Add "Add to Vocabulary" button in SuggestionDetailView in MindFlow/MindFlow/Views/VocabularySuggestionView.swift

### Chrome Extension Implementation

- [X] T032 [P] [US3] Create expandable suggestion component with detail section in MindFlow-Extension/src/popup/popup.js
- [X] T033 [US3] Implement fetchFullDetails() on suggestion click in MindFlow-Extension/src/popup/popup.js
- [X] T034 [P] [US3] Add CSS for expanded view (pronunciation, examples, synonyms layout) in MindFlow-Extension/src/popup/popup.css
- [X] T035 [US3] Add "Add to Vocabulary" button in expanded detail view in MindFlow-Extension/src/popup/popup.js

**Checkpoint**: All user stories complete - full suggestion workflow functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, edge cases, refinements

- [X] T036 [P] Add graceful error handling if vocabulary suggestion parsing fails in MindFlow/MindFlow/Services/LLMService.swift
- [X] T037 [P] Add graceful error handling if vocabulary suggestion parsing fails in MindFlow-Extension/src/lib/llm-service.js
- [X] T038 Handle storage full edge case in Chrome extension with user prompt in MindFlow-Extension/src/popup/popup.js
- [X] T039 [P] Add loading indicator while full details are being fetched in MindFlow/MindFlow/Views/VocabularySuggestionView.swift
- [X] T040 [P] Add loading indicator for detail fetch in extension in MindFlow-Extension/src/popup/popup.css
- [X] T041 Verify existing transcription improvement quality not degraded by prompt changes
- [X] T042 Run quickstart.md validation scenarios

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on T001-T003 - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion
- **User Story 2 (Phase 4)**: Depends on Phase 3 (US1 must display before Add works)
- **User Story 3 (Phase 5)**: Depends on Phase 2, integrates with US1/US2 UI
- **Polish (Phase 6)**: After all user stories

### User Story Dependencies

- **US1 (P1)**: Foundation only - can start after Phase 2
- **US2 (P1)**: Depends on US1 - Add button is part of suggestion row
- **US3 (P2)**: Depends on US1 for display - expand/collapse on suggestion row

### Platform Independence

macOS and Chrome Extension implementations can proceed in parallel:
- T004-T006 (macOS prompt) || T007-T008 (Extension prompt)
- T009-T012 (macOS US1) || T013-T016 (Extension US1)
- T017-T021 (macOS US2) || T022-T026 (Extension US2)
- T027-T031 (macOS US3) || T032-T035 (Extension US3)

### Parallel Opportunities Within Phases

```bash
# Phase 1 - All parallel (different files):
T001 || T002 || T003

# Phase 2 - Platform parallel:
(T004 → T005 → T006) || (T007 → T008)

# Phase 3 US1 - Parallel by platform:
macOS: T009 || others sequential
Extension: T013 || T015, then T014 → T016

# Phase 4 US2 - Parallel by platform:
macOS: sequential (state management)
Extension: T022 || T025, then T023 → T024 → T026

# Phase 5 US3 - Parallel by platform:
macOS: T027 parallel, then T028 → T029 → T030 → T031
Extension: T032 || T034, then T033 → T035
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T008)
3. Complete Phase 3: User Story 1 (T009-T016)
4. Complete Phase 4: User Story 2 (T017-T026)
5. **STOP and VALIDATE**: Test end-to-end suggestion and add flow
6. Deploy MVP - core value delivered

### Incremental Delivery

1. Setup + Foundational → Parsing works
2. Add US1 → Test: Suggestions display ✓
3. Add US2 → Test: One-click add works ✓ (MVP!)
4. Add US3 → Test: Detail expand works ✓
5. Polish → Production ready

### Parallel Team Strategy

With two developers:
- **Dev A**: macOS tasks (T004-T006, T009-T012, T017-T021, T027-T031)
- **Dev B**: Extension tasks (T007-T008, T013-T016, T022-T026, T032-T035)

Both can work simultaneously after Phase 1 is complete.

---

## Notes

- [P] tasks = different files, no dependencies within that phase
- US1 and US2 are both P1 priority but US2 depends on US1 UI
- VocabularyLookupService and VocabularyStorage are reused (no new code needed)
- TranscriptionResult change is additive (optional field)
- Parser fallback ensures graceful degradation if LLM doesn't return suggestions

# Tasks: Vocabulary Learning

**Input**: Design documents from `/specs/001-vocabulary-learning/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/vocabulary-api.yaml

**Tests**: Not explicitly requested - test tasks omitted. Tests can be added later.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

---

## Implementation Progress Summary

| Phase | Description | Tasks | Status |
|-------|-------------|-------|--------|
| Phase 1 | Setup - Core Data & Models | T001-T009 | ✅ Complete |
| Phase 2 | Foundational - Storage & Services | T010-T017 | ✅ Complete |
| Phase 3 | US1 - Quick Word Lookup & Save | T018-T025 | ✅ Complete |
| Phase 4 | US2 - Spaced Repetition Review | T026-T036 | ✅ Complete |
| Phase 5 | US3 - Browse & Manage Vocabulary | T037-T047 | ✅ Complete |
| Phase 6 | US4 - Track Learning Progress | T048-T056 | ✅ Complete |
| Phase 7 | US5 - Quick Add from Web Pages | T057-T068 | ✅ Complete |
| Phase 8 | US6 - Add Words from Transcriptions | T069-T073 | ✅ Complete |
| Phase 9 | US7 - Cross-Device Sync | T074-T082 | ✅ Complete |
| Phase 10 | Polish & Cross-Cutting | T083-T090 | 🔶 87% (7/8 tasks) |

**Overall Progress**: 87/90 tasks complete (97%)

**Remaining Tasks** (Manual QA):
- T088: Add accessibility labels to all vocabulary views
- T089: Verify offline functionality for browse and review
- T090: Run quickstart.md validation scenarios

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **macOS App**: `MindFlow/MindFlow/` (Swift/SwiftUI)
- **Chrome Extension**: `MindFlow-Extension/src/` (Vanilla JavaScript)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Core Data schema and shared model/service infrastructure

- [X] T001 Create new Core Data model version MindFlow 2.xcdatamodel in MindFlow/MindFlow/Models/MindFlow.xcdatamodeld/
- [X] T002 Add VocabularyEntry entity with all 30 attributes per data-model.md in MindFlow 2.xcdatamodel
- [X] T003 Add ReviewSession entity with all attributes per data-model.md in MindFlow 2.xcdatamodel
- [X] T004 Add LearningStats entity with all attributes per data-model.md in MindFlow 2.xcdatamodel
- [X] T005 [P] Create VocabularyEntry+CoreData.swift in MindFlow/MindFlow/Models/
- [X] T006 [P] Create ReviewSession+CoreData.swift in MindFlow/MindFlow/Models/
- [X] T007 [P] Create LearningStats+CoreData.swift in MindFlow/MindFlow/Models/
- [X] T008 [P] Create WordExplanation.swift model for AI response parsing in MindFlow/MindFlow/Models/
- [X] T009 Add vocabulary settings properties to Settings.swift in MindFlow/MindFlow/Models/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Storage and services that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T010 Create VocabularyStorage.swift with CRUD operations in MindFlow/MindFlow/Storage/
- [X] T011 [P] Create VocabularyLookupService.swift with AI prompt logic in MindFlow/MindFlow/Services/
- [X] T012 [P] Create SpacedRepetitionService.swift with SM-2 algorithm in MindFlow/MindFlow/Services/
- [X] T013 Add lookupVocabulary method to LLMService.swift in MindFlow/MindFlow/Services/
- [X] T014 [P] Create VocabularyViewModel.swift for list state management in MindFlow/MindFlow/ViewModels/
- [X] T015 [P] Create ReviewViewModel.swift for review session state in MindFlow/MindFlow/ViewModels/
- [X] T016 Add Vocabulary tab enum case and navigation to MainView.swift in MindFlow/MindFlow/Views/
- [X] T017 Create VocabularyTabView.swift container view in MindFlow/MindFlow/Views/

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - Quick Word Lookup and Save (Priority: P1)

**Goal**: Users can enter a word, get AI-generated explanation, and save to vocabulary

**Independent Test**: Type a word → View explanation → Save → Confirm in list

### Implementation for User Story 1

- [X] T018 [P] [US1] Create AddWordView.swift modal with text input and lookup button in MindFlow/MindFlow/Views/
- [X] T019 [P] [US1] Create WordDetailView.swift to display full word information in MindFlow/MindFlow/Views/
- [X] T020 [US1] Implement lookupWord() async method in VocabularyViewModel.swift
- [X] T021 [US1] Implement addWord() method to save VocabularyEntry via VocabularyStorage in VocabularyViewModel.swift
- [X] T022 [US1] Add context input field to AddWordView.swift for user-provided context
- [X] T023 [US1] Add duplicate word detection with alert in VocabularyViewModel.swift
- [X] T024 [US1] Add offline error handling with manual entry fallback in AddWordView.swift
- [X] T025 [US1] Add keyboard shortcut ⌘N to open AddWordView in VocabularyTabView.swift

**Checkpoint**: User Story 1 complete - can add words with AI explanations

---

## Phase 4: User Story 2 - Vocabulary Review with Spaced Repetition (Priority: P1)

**Goal**: Users can review vocabulary with flashcards and SM-2 scheduling

**Independent Test**: Start review → See flashcard → Rate recall → Verify next review date updated

### Implementation for User Story 2

- [X] T026 [P] [US2] Create FlashcardView.swift component showing word/pronunciation in MindFlow/MindFlow/Views/
- [X] T027 [P] [US2] Create ReviewSessionView.swift container for review flow in MindFlow/MindFlow/Views/
- [X] T028 [P] [US2] Create ReviewSummaryView.swift for session results in MindFlow/MindFlow/Views/
- [X] T029 [US2] Implement getWordsDueForReview() in VocabularyStorage.swift
- [X] T030 [US2] Implement startReviewSession() in ReviewViewModel.swift
- [X] T031 [US2] Implement rateRecall(quality:) using SpacedRepetitionService in ReviewViewModel.swift
- [X] T032 [US2] Implement completeSession() to save ReviewSession entity in ReviewViewModel.swift
- [X] T033 [US2] Add reveal answer animation to FlashcardView.swift
- [X] T034 [US2] Add keyboard shortcuts (Space/1/2/3) for review in ReviewSessionView.swift
- [X] T035 [US2] Add "due for review" badge count to VocabularySidebarView.swift
- [X] T036 [US2] Add keyboard shortcut ⌘R to start review in VocabularyTabView.swift

**Checkpoint**: User Story 2 complete - spaced repetition review works

---

## Phase 5: User Story 3 - Browse and Manage Vocabulary (Priority: P2)

**Goal**: Users can browse, search, filter, edit, and delete vocabulary entries

**Independent Test**: View list → Search → Filter by category → Edit entry → Delete entry

### Implementation for User Story 3

- [X] T037 [P] [US3] Create VocabularyListView.swift with search bar in MindFlow/MindFlow/Views/
- [X] T038 [P] [US3] Create VocabularyRowView.swift for list item display in MindFlow/MindFlow/Views/
- [X] T039 [P] [US3] Create VocabularySidebarView.swift with categories and filters in MindFlow/MindFlow/Views/
- [X] T040 [US3] Implement searchWords(query:) in VocabularyStorage.swift
- [X] T041 [US3] Implement getWordsByCategory(category:) in VocabularyStorage.swift
- [X] T042 [US3] Implement filterByMasteryLevel(level:) in VocabularyStorage.swift
- [X] T043 [US3] Add search binding and filtering logic to VocabularyViewModel.swift
- [X] T044 [US3] Add edit mode to WordDetailView.swift for updating category/tags/notes
- [X] T045 [US3] Implement updateWord() in VocabularyStorage.swift
- [X] T046 [US3] Implement deleteWord() with confirmation in VocabularyViewModel.swift
- [X] T047 [US3] Add keyboard shortcut ⌘F to focus search in VocabularyListView.swift

**Checkpoint**: User Story 3 complete - full vocabulary management works

---

## Phase 6: User Story 4 - Track Learning Progress (Priority: P2)

**Goal**: Users can view statistics including word counts, streaks, and accuracy

**Independent Test**: Add words → Complete reviews → View stats → Verify counts match

### Implementation for User Story 4

- [X] T048 [P] [US4] Create VocabularyStatsView.swift with stats display in MindFlow/MindFlow/Views/
- [X] T049 [US4] Implement getWordCountByMasteryLevel() in VocabularyStorage.swift
- [X] T050 [US4] Implement getOrCreateTodayStats() in VocabularyStorage.swift
- [X] T051 [US4] Implement updateDailyStats() after each add/review in VocabularyStorage.swift
- [X] T052 [US4] Implement calculateStreak() based on consecutive activity days in VocabularyStorage.swift
- [X] T053 [US4] Add mastery level breakdown chart to VocabularyStatsView.swift
- [X] T054 [US4] Add weekly activity chart (words added/reviewed per day) to VocabularyStatsView.swift
- [X] T055 [US4] Add streak display and accuracy percentage to VocabularyStatsView.swift
- [X] T056 [US4] Add stats summary to VocabularySidebarView.swift

**Checkpoint**: User Story 4 complete - learning progress tracking works

---

## Phase 7: User Story 5 - Quick Add from Web Pages (Priority: P3)

**Goal**: Chrome extension users can look up and add words from any webpage

**Independent Test**: Select text on page → Right-click → Lookup → Save → Verify in extension storage

### Implementation for User Story 5

- [X] T057 [P] [US5] Create vocabulary-storage.js with Chrome Storage operations in MindFlow-Extension/src/lib/
- [X] T058 [P] [US5] Create vocabulary-lookup.js with OpenAI API call in MindFlow-Extension/src/lib/
- [X] T059 [P] [US5] Create spaced-repetition.js with SM-2 algorithm in MindFlow-Extension/src/lib/
- [X] T060 [US5] Add vocabulary storage methods to storage-manager.js in MindFlow-Extension/src/lib/
- [X] T061 [US5] Add context menu "Look up word" option in content-script.js
- [X] T062 [US5] Add vocabulary lookup message handler in service-worker.js
- [X] T063 [P] [US5] Create vocabulary section HTML/CSS/JS in popup.html/popup.js/popup.css
- [X] T064 [US5] Create inline popup for word explanation display in content-script.js
- [X] T065 [US5] Add "Add to Vocabulary" button to inline popup in content-script.js
- [X] T066 [P] [US5] Create vocabulary.html full page for extension in MindFlow-Extension/src/vocabulary/
- [X] T067 [P] [US5] Create vocabulary.js with list/search functionality in MindFlow-Extension/src/vocabulary/
- [X] T068 [P] [US5] Create vocabulary.css styles in MindFlow-Extension/src/vocabulary/

**Checkpoint**: User Story 5 complete - extension word lookup and save works

---

## Phase 8: User Story 6 - Add Words from Transcriptions (Priority: P3)

**Goal**: Users can add words from transcriptions with context preserved

**Independent Test**: View transcription → Long-press word → Add to vocab → Verify context saved

### Implementation for User Story 6

- [X] T069 [US6] Add word selection gesture handler to transcription text in RecordingTabView or relevant view
- [X] T070 [US6] Create context menu "Add to Vocabulary" for transcription words
- [X] T071 [US6] Pass transcription sentence as userContext when saving word
- [X] T072 [US6] Store sourceInteractionId linking to LocalInteraction
- [X] T073 [US6] Display source context in WordDetailView.swift when available

**Checkpoint**: User Story 6 complete - transcription integration works

---

## Phase 9: User Story 7 - Cross-Device Sync (Priority: P3)

**Goal**: Vocabulary syncs between macOS app and Chrome extension via Supabase

**Independent Test**: Add word on macOS → Wait → Verify appears in extension (and vice versa)

### Implementation for User Story 7

- [X] T074 [P] [US7] Create VocabularySyncService.swift for Supabase sync in MindFlow/MindFlow/Services/
- [X] T075 [P] [US7] Create vocabulary-sync.js for extension Supabase sync in MindFlow-Extension/src/lib/
- [X] T076 [US7] Implement syncToBackend() in VocabularySyncService.swift
- [X] T077 [US7] Implement syncFromBackend() with conflict resolution in VocabularySyncService.swift
- [X] T078 [US7] Add sync toggle to vocabulary settings in Settings.swift
- [X] T079 [US7] Implement offline queue for pending sync in VocabularyStorage.swift
- [X] T080 [US7] Add sync status indicator to VocabularySidebarView.swift
- [X] T081 [US7] Implement extension sync with Supabase in vocabulary-sync.js
- [X] T082 [US7] Add sync settings UI to extension settings page

**Checkpoint**: User Story 7 complete - cross-device sync works

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T083 [P] Add review reminder notification support in AppDelegate.swift
- [X] T084 [P] Add vocabulary settings section to SettingsTabView.swift
- [X] T085 Code cleanup and refactoring across vocabulary files
- [X] T086 Performance optimization for search with 5,000+ entries
- [X] T087 [P] Create review.html/js/css for extension review UI in MindFlow-Extension/src/review/
- [ ] T088 Add accessibility labels to all vocabulary views
- [ ] T089 Verify offline functionality for browse and review
- [ ] T090 Run quickstart.md validation scenarios

**Note**: T088-T090 are manual testing/verification tasks to be completed during QA.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ─────────────▶ Phase 2 (Foundational) ─────────────────────────┐
                                         │                                      │
                                         ▼                                      │
                              ┌──────────────────────┐                         │
                              │  CHECKPOINT: Ready   │                         │
                              │  for User Stories    │                         │
                              └──────────────────────┘                         │
                                         │                                      │
            ┌────────────────┬───────────┼───────────┬────────────────┐        │
            ▼                ▼           ▼           ▼                ▼        │
     Phase 3 (US1)    Phase 4 (US2)  Phase 5    Phase 6           Phase 7      │
     P1: Add Word     P1: Review     (US3)      (US4)             (US5-7)      │
            │                │        P2:Browse  P2:Stats          P3:Ext      │
            │                │           │          │                 │        │
            └────────────────┴───────────┴──────────┴─────────────────┘        │
                                         │                                      │
                                         ▼                                      │
                              Phase 10 (Polish) ◀───────────────────────────────┘
```

### User Story Dependencies

| Story | Priority | Dependencies | Can Start After |
|-------|----------|--------------|-----------------|
| US1: Add Word | P1 | None | Phase 2 complete |
| US2: Review | P1 | None (shares models with US1) | Phase 2 complete |
| US3: Browse | P2 | US1 (needs words to browse) | US1 complete |
| US4: Stats | P2 | US1, US2 (needs data) | US1 & US2 complete |
| US5: Extension | P3 | None (separate platform) | Phase 2 complete |
| US6: Transcription | P3 | US1 (uses add word flow) | US1 complete |
| US7: Sync | P3 | US1, US5 (needs both platforms) | US1 & US5 complete |

### Parallel Opportunities

**Phase 1 (Setup)**: T005, T006, T007, T008 can run in parallel after T001-T004

**Phase 2 (Foundational)**: T011, T012 can run in parallel; T014, T015 can run in parallel

**Phase 3-4 (P1 Stories)**: US1 and US2 can be worked in parallel by different developers

**Phase 5-7 (P2-P3 Stories)**: US3, US4, US5 can all start in parallel after dependencies met

---

## Parallel Example: Phase 2 Foundation

```bash
# These can run in parallel (different files):
Task: "Create VocabularyLookupService.swift in MindFlow/MindFlow/Services/"
Task: "Create SpacedRepetitionService.swift in MindFlow/MindFlow/Services/"
Task: "Create VocabularyViewModel.swift in MindFlow/MindFlow/ViewModels/"
Task: "Create ReviewViewModel.swift in MindFlow/MindFlow/ViewModels/"
```

## Parallel Example: User Story 1

```bash
# These can run in parallel (different files):
Task: "Create AddWordView.swift in MindFlow/MindFlow/Views/"
Task: "Create WordDetailView.swift in MindFlow/MindFlow/Views/"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001-T009)
2. Complete Phase 2: Foundational (T010-T017)
3. Complete Phase 3: User Story 1 - Add Word (T018-T025)
4. Complete Phase 4: User Story 2 - Review (T026-T036)
5. **STOP and VALIDATE**: Test add word + review flow end-to-end
6. Deploy/demo if ready - users can now add and review vocabulary!

### Incremental Delivery

1. **MVP**: Setup + Foundation + US1 + US2 → Core learning loop works
2. **+Browse**: Add US3 → Users can manage their vocabulary
3. **+Stats**: Add US4 → Users can track progress
4. **+Extension**: Add US5 → Web lookup convenience
5. **+Transcription**: Add US6 → Integrated context capture
6. **+Sync**: Add US7 → Cross-device experience

### Suggested MVP Scope

**Minimum**: Phase 1-4 (T001-T036) = 36 tasks
- Delivers: Add words with AI explanation + Spaced repetition review
- Value: Complete learning loop for vocabulary acquisition

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- macOS app is primary platform; Chrome extension (US5, US7) can be deferred

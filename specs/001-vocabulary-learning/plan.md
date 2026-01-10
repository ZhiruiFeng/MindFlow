# Implementation Plan: Vocabulary Learning

**Branch**: `001-vocabulary-learning` | **Date**: 2026-01-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-vocabulary-learning/spec.md`

## Summary

Vocabulary Learning helps non-native English speakers (primarily Chinese speakers) build vocabulary through their daily work. The feature provides AI-powered word explanations, local-first storage with optional cloud sync, and spaced repetition review. Implementation follows MindFlow's existing patterns: Core Data for macOS storage, Chrome Storage API for extension, singleton services, MVVM architecture, and optional Supabase sync.

## Technical Context

**Language/Version**: Swift 5.0 (macOS), Vanilla JavaScript (Chrome Extension)
**Primary Dependencies**: SwiftUI, Core Data, AVFoundation (macOS); Chrome Storage API, Chrome Tabs API (Extension)
**Storage**: Core Data (macOS), Chrome Storage local/sync (Extension), Supabase PostgreSQL (optional cloud sync)
**Testing**: XCTest (macOS), Jest (Extension - to be configured)
**Target Platform**: macOS 12+ (menu bar app), Chrome Browser (Manifest v3 extension)
**Project Type**: Multi-platform (native macOS app + browser extension)
**Performance Goals**: Word lookup < 3s (AI generation), local search < 100ms, 15-word review < 5 minutes
**Constraints**: Offline-capable for browse/review, < 10MB Chrome Storage local quota, API calls only to user-configured endpoints
**Scale/Scope**: Up to 5,000 vocabulary entries per user, single-user local-first architecture

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Compliance | Notes |
|-----------|-------------|------------|-------|
| **I. Privacy-First Design** | API keys in Keychain; local storage by default; no telemetry; cloud sync opt-in | PASS | Vocabulary data follows existing local-first pattern. AI lookups use user's own API key via existing LLMService. Cloud sync is opt-in per existing Settings.autoSyncToBackend. |
| **II. Native macOS Experience** | SwiftUI + HIG; native frameworks | PASS | Uses existing SwiftUI patterns (Views/, ViewModels/). Core Data for storage. Keyboard shortcuts follow macOS conventions (⌘N, ⌘R). |
| **III. Local-First Storage** | Core Data primary; offline-capable; sync additive; export available | PASS | Core Data stores VocabularyEntry locally. Browse/review works offline. Only AI lookup requires internet. Sync follows existing pattern (local-first, remote-additive). |
| **IV. Simplicity & User Focus** | Core workflow < 5 sec interaction; sensible defaults; no complexity increase to main flow | PASS | Vocabulary is separate tab; doesn't affect record→transcribe→paste workflow. Default settings (no config required). 3-tap word save flow. |
| **V. API Integration Standards** | Timeouts/retry; user API keys; graceful errors; cost transparency | PASS | Reuses LLMService with existing timeout/retry logic. Uses user's configured OpenAI key. Graceful fallback to manual entry on API failure. |

**Gate Status**: ✅ PASS - All principles satisfied. Proceeding to Phase 0.

### Post-Design Re-Check (Phase 1 Complete)

| Principle | Design Impact | Status |
|-----------|---------------|--------|
| **I. Privacy-First** | VocabularyEntry stores only on device by default; API keys remain in Keychain; no new telemetry | ✅ PASS |
| **II. Native macOS** | SwiftUI views follow HIG; Core Data entities use standard patterns; keyboard shortcuts use ⌘ modifiers | ✅ PASS |
| **III. Local-First** | VocabularyStorage writes to Core Data first; offline review fully functional; sync is additive only | ✅ PASS |
| **IV. Simplicity** | Separate tab doesn't change core workflow; SM-2 is industry-standard (not custom); single JSON prompt | ✅ PASS |
| **V. API Standards** | Reuses LLMService (inherits timeout/retry); graceful JSON parse fallback; user provides own key | ✅ PASS |

**Post-Design Gate**: ✅ PASS - Design adheres to all constitution principles.

## Project Structure

### Documentation (this feature)

```text
specs/001-vocabulary-learning/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── vocabulary-api.yaml
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
MindFlow/MindFlow/
├── App/
│   ├── MindFlowApp.swift              # [MODIFY] Add Vocabulary tab
│   └── AppDelegate.swift
├── Views/
│   ├── MainView.swift                 # [MODIFY] Add Vocabulary tab navigation
│   ├── VocabularyTabView.swift        # [NEW] Main vocabulary container
│   ├── VocabularySidebarView.swift    # [NEW] Categories, filters, stats
│   ├── VocabularyListView.swift       # [NEW] Word list with search
│   ├── VocabularyRowView.swift        # [NEW] Single word row component
│   ├── AddWordView.swift              # [NEW] Add word modal
│   ├── WordDetailView.swift           # [NEW] Full word information
│   ├── ReviewSessionView.swift        # [NEW] Flashcard review
│   ├── FlashcardView.swift            # [NEW] Single flashcard component
│   ├── ReviewSummaryView.swift        # [NEW] Review session results
│   └── VocabularyStatsView.swift      # [NEW] Learning statistics
├── ViewModels/
│   ├── VocabularyViewModel.swift      # [NEW] Vocabulary list state
│   └── ReviewViewModel.swift          # [NEW] Review session state
├── Services/
│   ├── LLMService.swift               # [MODIFY] Add vocabulary prompt
│   ├── VocabularyLookupService.swift  # [NEW] AI word explanation
│   └── SpacedRepetitionService.swift  # [NEW] SM-2 algorithm
├── Managers/
│   └── CoreDataManager.swift          # [EXISTING] Manages vocabulary entities
├── Models/
│   ├── MindFlow.xcdatamodeld/
│   │   └── MindFlow 2.xcdatamodel     # [NEW] Add vocabulary entities
│   ├── VocabularyEntry+CoreData.swift # [NEW] Core Data class
│   ├── ReviewSession+CoreData.swift   # [NEW] Core Data class
│   ├── LearningStats+CoreData.swift   # [NEW] Core Data class
│   ├── WordExplanation.swift          # [NEW] AI response model
│   └── Settings.swift                 # [MODIFY] Add vocabulary settings
└── Storage/
    ├── LocalInteractionStorage.swift  # [EXISTING] Pattern reference
    └── VocabularyStorage.swift        # [NEW] Vocabulary CRUD operations

MindFlow-Extension/src/
├── popup/
│   ├── popup.html                     # [MODIFY] Add vocabulary section
│   ├── popup.js                       # [MODIFY] Add vocabulary logic
│   └── popup.css                      # [MODIFY] Add vocabulary styles
├── vocabulary/
│   ├── vocabulary.html                # [NEW] Full vocabulary page
│   ├── vocabulary.js                  # [NEW] Vocabulary page logic
│   └── vocabulary.css                 # [NEW] Vocabulary styles
├── review/
│   ├── review.html                    # [NEW] Review interface
│   ├── review.js                      # [NEW] Review logic
│   └── review.css                     # [NEW] Review styles
├── lib/
│   ├── storage-manager.js             # [MODIFY] Add vocabulary storage
│   ├── vocabulary-storage.js          # [NEW] Vocabulary Chrome storage
│   └── vocabulary-lookup.js           # [NEW] AI lookup for extension
├── content/
│   └── content-script.js              # [MODIFY] Add context menu lookup
└── background/
    └── service-worker.js              # [MODIFY] Handle vocabulary messages
```

**Structure Decision**: Multi-platform project extending existing macOS app and Chrome extension. No new top-level directories needed; vocabulary feature integrates into existing View/Service/Model organization following established MVVM patterns.

## Complexity Tracking

> No Constitution violations requiring justification. Feature follows established patterns.

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| Separate VocabularyStorage service | Follows LocalInteractionStorage pattern; separation of concerns | Extending LocalInteractionStorage - rejected because vocabulary has different entity, different sync rules |
| SM-2 algorithm simplified | Proven spaced repetition method; simpler than Anki/SuperMemo variants | Custom algorithm - rejected because SM-2 is well-tested and sufficient for this use case |
| Single vocabulary prompt (not per-field) | Faster response; single API call vs multiple | Separate prompts for definition/examples/etymology - rejected because it would increase latency 10x |

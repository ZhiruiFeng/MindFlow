# Implementation Plan: Voice-to-Text Vocabulary Suggestions

**Branch**: `002-voice-vocab-suggestions` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-voice-vocab-suggestions/spec.md`

## Summary

Voice-to-Text Vocabulary Suggestions enhances the existing transcription improvement prompt to automatically suggest 3 vocabulary words worth learning from each transcription. Users can add suggested words to their vocabulary with one click, seamlessly integrating vocabulary capture into the transcription workflow. Implementation extends existing LLMService prompts and PreviewView UI while reusing VocabularyStorage and VocabularyLookupService from the vocabulary learning feature.

## Technical Context

**Language/Version**: Swift 5.0 (macOS), Vanilla JavaScript (Chrome Extension)
**Primary Dependencies**: SwiftUI, Core Data, AVFoundation (macOS); Chrome Storage API, Chrome Tabs API (Extension)
**Storage**: Core Data (macOS), Chrome Storage local/sync (Extension) - reuses existing VocabularyEntry entity
**Testing**: XCTest (macOS), Jest (Extension)
**Target Platform**: macOS 12+ (menu bar app), Chrome Browser (Manifest v3 extension)
**Project Type**: Multi-platform (native macOS app + browser extension)
**Performance Goals**: Vocabulary suggestions within same API response (no additional latency); one-click add < 2 seconds
**Constraints**: Suggestions generated in same LLM call as optimization; offline-capable for vocabulary storage; no increase to API cost per transcription
**Scale/Scope**: 3 suggestions per transcription; integration with existing vocabulary system (up to 5,000 entries)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Compliance | Notes |
|-----------|-------------|------------|-------|
| **I. Privacy-First Design** | API keys in Keychain; local storage by default; no telemetry; cloud sync opt-in | PASS | Suggestions generated via existing user API key. Vocabulary stored locally in Core Data. No new data collection. |
| **II. Native macOS Experience** | SwiftUI + HIG; native frameworks | PASS | Extends existing PreviewView with SwiftUI components. Follows established UI patterns. |
| **III. Local-First Storage** | Core Data primary; offline-capable; sync additive | PASS | One-click add saves directly to Core Data via existing VocabularyStorage. Works offline after suggestion generated. |
| **IV. Simplicity & User Focus** | Core workflow < 5 sec interaction; sensible defaults; no complexity increase to main flow | PASS | Suggestions displayed alongside existing teacher notes. Single-click save. Core record→transcribe→paste flow unchanged. |
| **V. API Integration Standards** | Timeouts/retry; user API keys; graceful errors; cost transparency | PASS | Reuses LLMService with existing timeout/retry. Same API call (no additional cost). Graceful handling if parsing fails. |

**Gate Status**: ✅ PASS - All principles satisfied. Proceeding to Phase 0.

### Post-Design Re-Check (Phase 1 Complete)

| Principle | Design Impact | Status |
|-----------|---------------|--------|
| **I. Privacy-First** | VocabularySuggestion is transient (in-memory only until saved). No new data collection. Uses existing user API key. | ✅ PASS |
| **II. Native macOS** | VocabularySuggestionView follows SwiftUI/HIG patterns. Extends existing PreviewView. | ✅ PASS |
| **III. Local-First** | One-click add saves directly to Core Data. Suggestions work offline after initial generation. | ✅ PASS |
| **IV. Simplicity** | Single combined prompt (no extra API calls). Extends existing UI without new complexity. Core workflow unchanged. | ✅ PASS |
| **V. API Standards** | Reuses LLMService (inherits timeout/retry). Graceful JSON parse fallback. Same API cost as before. | ✅ PASS |

**Post-Design Gate**: ✅ PASS - Design adheres to all constitution principles.

## Project Structure

### Documentation (this feature)

```text
specs/002-voice-vocab-suggestions/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── vocabulary-suggestions-schema.yaml
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
MindFlow/MindFlow/
├── Services/
│   ├── LLMService.swift               # [MODIFY] Extend prompt to include vocabulary suggestions
│   └── VocabularyLookupService.swift  # [EXISTING] Reuse for full word lookup on add
├── Models/
│   ├── TranscriptionResult.swift      # [MODIFY] Add vocabularySuggestions field
│   ├── VocabularySuggestion.swift     # [NEW] Suggestion model for display
│   └── WordExplanation.swift          # [EXISTING] Reuse for full word details
├── Views/
│   ├── PreviewView.swift              # [MODIFY] Add vocabulary suggestions section
│   ├── VocabularySuggestionView.swift # [NEW] Single suggestion row with add button
│   └── SuggestionDetailView.swift     # [NEW] Expanded word details before add
├── ViewModels/
│   └── RecordingViewModel.swift       # [MODIFY] Handle suggestion add action
└── Storage/
    └── VocabularyStorage.swift        # [EXISTING] Reuse addWord() for one-click save

MindFlow-Extension/src/
├── lib/
│   ├── llm-service.js                 # [MODIFY] Extend prompt for suggestions
│   └── vocabulary-storage.js          # [EXISTING] Reuse for one-click save
├── popup/
│   ├── popup.js                       # [MODIFY] Parse and display suggestions
│   └── popup.css                      # [MODIFY] Add suggestion styles
└── components/
    └── suggestion-row.js              # [NEW] Suggestion component for extension
```

**Structure Decision**: Feature extends existing files rather than creating new modules. Vocabulary suggestions are a lightweight addition to the transcription result flow, reusing vocabulary learning infrastructure. No new directories required.

## Complexity Tracking

> No Constitution violations requiring justification. Feature follows established patterns.

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| Single combined prompt | No additional API latency; cost-neutral | Separate suggestion API call - rejected because it doubles latency and cost |
| Brief suggestion format | Inline display with transcription; full details loaded on expand | Full word details in initial response - rejected because it bloats response size |
| Reuse VocabularyLookupService | Consistent word detail format; existing AI prompt quality | Custom suggestion-to-vocabulary converter - rejected because it duplicates logic |

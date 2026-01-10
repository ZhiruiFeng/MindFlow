<!--
  Sync Impact Report
  ====================
  Version change: N/A → 1.0.0 (initial adoption)

  Modified principles: N/A (initial version)

  Added sections:
    - Core Principles (5 principles)
    - Development Workflow
    - Quality Standards
    - Governance

  Removed sections: N/A

  Templates requiring updates:
    - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section exists)
    - .specify/templates/spec-template.md: ✅ Compatible (requirements align with principles)
    - .specify/templates/tasks-template.md: ✅ Compatible (phase structure supports principles)

  Follow-up TODOs: None
-->

# MindFlow Constitution

## Core Principles

### I. Privacy-First Design

All user data MUST be protected with security as the default, not an option.

- API keys MUST be stored exclusively in macOS Keychain; plain-text storage is prohibited
- Audio recordings and transcriptions MUST be stored locally by default
- The application MUST NOT collect telemetry, analytics, or usage data without explicit user consent
- Network requests MUST only be made to user-configured API endpoints (OpenAI, ElevenLabs, ZephyrOS)
- Cloud sync MUST be opt-in and disabled by default

**Rationale**: Users trust MindFlow with voice recordings containing potentially sensitive information. Privacy breaches would fundamentally undermine the product's value proposition.

### II. Native macOS Experience

MindFlow MUST feel like a first-class macOS citizen, not a cross-platform port.

- UI MUST be built with SwiftUI following Apple Human Interface Guidelines
- System integrations MUST use native frameworks: AVFoundation (audio), Carbon (hotkeys), CGEvent (auto-paste), Core Data (storage)
- The application MUST respect system preferences (appearance, accessibility settings)
- Menu bar presence MUST follow macOS conventions for background utilities
- Keyboard shortcuts MUST be customizable and follow macOS modifier key conventions

**Rationale**: A native experience builds user trust and ensures reliability across macOS versions. Cross-platform abstractions introduce unnecessary complexity and degrade UX.

### III. Local-First Storage

All user data MUST be persisted locally before any network operations.

- Core Data MUST be the primary storage mechanism for all user-generated content
- The application MUST function fully offline (excluding API-dependent transcription/optimization)
- Sync to ZephyrOS MUST be additive; local data MUST never be deleted based on remote state
- Sync failures MUST NOT block local operations or cause data loss
- Users MUST be able to export all their data in a portable format

**Rationale**: Local-first ensures users maintain ownership of their data and the app remains functional regardless of network conditions or third-party service availability.

### IV. Simplicity & User Focus

Features MUST prioritize user workflow efficiency over technical sophistication.

- The primary use case (record → transcribe → optimize → paste) MUST complete in under 5 seconds of user interaction
- Configuration MUST have sensible defaults; zero-config should work for 80% of users
- Error messages MUST be actionable and user-friendly, not technical stack traces
- New features MUST NOT increase complexity of the core workflow
- YAGNI (You Aren't Gonna Need It): defer features until proven necessary

**Rationale**: MindFlow exists to reduce friction in text input. Adding complexity contradicts the core value proposition.

### V. API Integration Standards

External API integrations MUST be resilient, configurable, and cost-transparent.

- API calls MUST include appropriate timeouts and retry logic with exponential backoff
- Users MUST be able to configure their own API keys; hardcoded keys are prohibited
- API errors MUST be handled gracefully with clear user feedback
- Cost-incurring operations SHOULD display estimated costs before execution (where feasible)
- API provider changes (OpenAI, ElevenLabs) MUST be abstracted behind service interfaces to enable future alternatives

**Rationale**: Users bear the direct cost of API calls. Transparent, reliable integrations build trust and prevent unexpected charges.

## Development Workflow

### Code Organization

- **macOS App**: Swift + SwiftUI in `MindFlow/` directory
- **Chrome Extension**: Vanilla JavaScript in `MindFlow-Extension/` directory
- **Documentation**: Markdown in `docs/` directory with clear hierarchy

### Testing Guidelines

Testing is RECOMMENDED but not mandatory for all changes.

- Unit tests SHOULD cover business logic and data transformations
- Integration tests SHOULD verify API client behavior with mocked responses
- UI tests SHOULD cover critical user flows (recording, settings, history)
- Test coverage metrics are informational, not gatekeeping requirements

### Code Review Standards

- All changes MUST be reviewed before merging to main
- Reviews SHOULD verify compliance with Core Principles
- Reviewers SHOULD prioritize user impact over code aesthetics

## Quality Standards

### Performance Expectations

- App launch to ready state: < 2 seconds
- Recording start latency: < 100ms after hotkey press
- UI MUST remain responsive during API calls (async operations required)

### Reliability Requirements

- Core Data operations MUST NOT lose user data under any circumstance
- App crashes MUST be logged with sufficient context for debugging
- Background operations MUST gracefully handle app termination

## Governance

### Amendment Process

1. Proposed changes MUST be documented with rationale
2. Changes to Core Principles require explicit approval from project maintainers
3. All amendments MUST update the version number and Last Amended date

### Versioning Policy

- **MAJOR**: Removal or fundamental redefinition of a Core Principle
- **MINOR**: Addition of new principles, sections, or material guidance expansion
- **PATCH**: Clarifications, typo fixes, non-semantic refinements

### Compliance

- All PRs SHOULD reference relevant principles when applicable
- Constitution violations MUST be justified in PR descriptions
- Complexity additions MUST document why simpler alternatives were rejected

**Version**: 1.0.0 | **Ratified**: 2026-01-09 | **Last Amended**: 2026-01-09

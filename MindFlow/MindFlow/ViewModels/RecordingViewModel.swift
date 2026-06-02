//
//  RecordingViewModel.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import SwiftUI

// MARK: - Recording ViewModel

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var state: TranscriptionState = .idle {
        didSet { AppStatus.shared.update(from: state) }
    }
    @Published var duration: TimeInterval = 0
    @Published var pulseAnimation = false
    @Published var isPaused = false
    @Published var result: TranscriptionResult?

    private let audioRecorder = AudioRecorder.shared
    private let sttService = STTService.shared
    private let llmService = LLMService.shared
    private let permissionManager = PermissionManager.shared
    private let storageService = InteractionStorageService.shared
    private let settings = Settings.shared

    private var timer: Timer?

    /// In-flight transcription/optimization task, cancelled on reset/cancel.
    private var processingTask: Task<Void, Never>?

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        setupNotificationObservers()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Use weak self and automatically remove on dealloc
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartRecordingShortcutObjC),
            name: .startRecordingShortcut,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecordingShortcutObjC),
            name: .stopRecordingShortcut,
            object: nil
        )
    }

    @objc private func handleStartRecordingShortcutObjC() {
        handleStartRecordingShortcut()
    }

    @objc private func handleStopRecordingShortcutObjC() {
        handleStopRecordingShortcut()
    }

    private func handleStartRecordingShortcut() {
        // Start a new recording session
        // If already completed or in error state, reset first
        switch state {
        case .idle:
            startRecording()
        case .completed, .error:
            // Reset to idle and start fresh recording
            reset()
            startRecording()
        case .recording, .processing, .transcribing, .optimizing:
            // Already in progress, ignore
            print("⚠️ Recording already in progress, ignoring shortcut")
        }
    }

    private func handleStopRecordingShortcut() {
        // Only stop recording if we're currently recording
        if case .recording = state {
            stopRecording()
        }
    }

    func checkPermissions() {
        if !permissionManager.isMicrophonePermissionGranted {
            state = .error("error.microphone_required".localized)
        }
    }

    func startRecording() {
        // Prevent a double-start: only begin from idle (matches the shortcut handler).
        guard case .idle = state else { return }

        guard permissionManager.isMicrophonePermissionGranted else {
            state = .error("error.microphone_needed".localized)
            return
        }

        state = .recording
        duration = 0
        isPaused = false

        // Invalidate any existing timer before assigning a new one.
        timer?.invalidate()
        timer = nil

        // Start recording
        audioRecorder.startRecording { [weak self] success in
            guard let self = self else { return }
            if success {
                // Start the duration timer only on the success path so a failed
                // start never leaves a running timer.
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self, !self.isPaused else { return }
                        self.duration += 0.1
                    }
                }
            } else {
                self.state = .error("error.recording_failed".localized)
            }
        }
    }

    func pauseRecording() {
        guard case .recording = state else { return }

        isPaused.toggle()
        if isPaused {
            audioRecorder.pauseRecording()
        } else {
            audioRecorder.resumeRecording()
        }
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        pulseAnimation = false

        state = .processing

        // Stop recording
        audioRecorder.stopRecording { [weak self] audioURL in
            guard let self = self, let url = audioURL else {
                self?.state = .error("error.invalid_audio".localized)
                return
            }

            // Transcribe
            self.transcribe(audioURL: url)
        }
    }

    private func transcribe(audioURL: URL) {
        state = .transcribing

        processingTask = Task {
            do {
                // Use new method that returns metadata
                let metadata = try await sttService.transcribeWithMetadata(audioURL: audioURL)
                guard !Task.isCancelled else { return }
                self.optimize(
                    originalText: metadata.text,
                    audioURL: audioURL,
                    transcriptionProvider: metadata.provider,
                    transcriptionModel: metadata.model
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .error(String(format: "error.transcription_failed".localized, error.localizedDescription))
            }
        }
    }

    private func optimize(
        originalText: String,
        audioURL: URL,
        transcriptionProvider: String,
        transcriptionModel: String
    ) {
        state = .optimizing

        // Snapshot the duration before any awaits so the value persisted to
        // storage matches the recording that just finished.
        let recordingDuration = duration

        processingTask = Task {
            do {
                let refinedText: String
                let teacherExplanation: String?
                var vocabularySuggestions: [VocabularySuggestion]?

                // Always generate vocabulary suggestions so users get word
                // recommendations regardless of the Teacher Notes setting. The
                // toggle only controls whether the teacher explanation is shown.
                let optimizationResult = try await llmService.optimizeTextWithExplanation(originalText)
                refinedText = optimizationResult.refinedText
                teacherExplanation = settings.enableTeacherNotes ? optimizationResult.teacherExplanation : nil

                // Flag suggestions that already exist in the user's vocabulary.
                vocabularySuggestions = await checkExistingVocabulary(suggestions: optimizationResult.vocabularySuggestions)

                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: refinedText,
                    duration: recordingDuration,
                    audioFilePath: audioURL.path,
                    transcriptionProvider: transcriptionProvider,
                    transcriptionModel: transcriptionModel,
                    optimizationModel: settings.llmModel.rawValue,
                    optimizationLevel: settings.optimizationLevel.rawValue,
                    outputStyle: settings.outputStyle.rawValue,
                    teacherExplanation: teacherExplanation,
                    vocabularySuggestions: vocabularySuggestions
                )

                // Always store the recording locally (don't block UI if this fails).
                // InteractionStorageService persists every recording to local storage
                // and only syncs to the remote when authenticated and the duration
                // exceeds the auto-sync threshold (default 30s).
                let explanationToPersist = teacherExplanation
                let suggestionsToPersist = vocabularySuggestions
                let hasSuggestions = !(suggestionsToPersist?.isEmpty ?? true)
                if explanationToPersist != nil || hasSuggestions {
                    // Persist via the explanation path whenever we have a teacher
                    // note OR vocabulary suggestions, so recommendations survive on
                    // the record detail page even when Teacher Notes is disabled.
                    Task {
                        do {
                            _ = try await self.storageService.saveInteractionWithExplanation(
                                transcription: originalText,
                                refinedText: refinedText,
                                teacherExplanation: explanationToPersist ?? "",
                                audioDuration: recordingDuration,
                                vocabularySuggestions: suggestionsToPersist
                            )
                        } catch {
                            Logger.error("Local save failed", category: .storage, error: error)
                        }
                    }
                } else {
                    Task {
                        do {
                            _ = try await self.storageService.saveInteraction(
                                transcription: originalText,
                                refinedText: refinedText,
                                audioDuration: recordingDuration
                            )
                        } catch {
                            Logger.error("Local save failed", category: .storage, error: error)
                        }
                    }
                }

                guard !Task.isCancelled else { return }
                self.result = result
                self.state = .completed
            } catch {
                // If optimization fails, save transcription only
                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: nil,
                    duration: recordingDuration,
                    audioFilePath: audioURL.path,
                    transcriptionProvider: transcriptionProvider,
                    transcriptionModel: transcriptionModel
                )

                // Always store the transcription-only recording locally.
                // Remote sync is handled conditionally inside the storage service.
                Task {
                    do {
                        _ = try await self.storageService.saveInteraction(
                            transcription: originalText,
                            refinedText: nil,
                            audioDuration: recordingDuration
                        )
                    } catch {
                        Logger.error("Local save failed", category: .storage, error: error)
                    }
                }

                guard !Task.isCancelled else { return }
                self.result = result
                self.state = .completed
            }
        }
    }

    func reset() {
        // Cancel any in-flight transcription/optimization so it can't overwrite
        // state after a reset.
        processingTask?.cancel()
        processingTask = nil

        timer?.invalidate()
        timer = nil

        state = .idle
        duration = 0
        pulseAnimation = false
        isPaused = false
        result = nil
    }

    // MARK: - Helper Methods

    /// Check which suggested words already exist in the user's vocabulary
    /// - Parameter suggestions: Array of vocabulary suggestions from LLM
    /// - Returns: Suggestions with isAlreadySaved flag updated
    private func checkExistingVocabulary(suggestions: [VocabularySuggestion]) async -> [VocabularySuggestion] {
        var updatedSuggestions = suggestions
        for index in updatedSuggestions.indices {
            let word = updatedSuggestions[index].word
            if VocabularyStorage.shared.wordExists(word) {
                updatedSuggestions[index].isAlreadySaved = true
            }
        }
        return updatedSuggestions
    }

    // MARK: - Vocabulary Suggestion Actions

    /// Add a vocabulary suggestion to the user's vocabulary
    /// - Parameter suggestion: The suggestion to add
    func addSuggestionToVocabulary(_ suggestion: VocabularySuggestion) async {
        guard var currentResult = result,
              var suggestions = currentResult.vocabularySuggestions,
              let index = suggestions.firstIndex(where: { $0.word.lowercased() == suggestion.word.lowercased() }) else {
            return
        }

        // Update state to show loading
        suggestions[index].isAdding = true
        currentResult.vocabularySuggestions = suggestions
        result = currentResult

        do {
            // Fetch full word details using VocabularyLookupService
            let wordExplanation = try await VocabularyLookupService.shared.lookupWord(
                suggestion.word,
                context: suggestion.sourceSentence
            )

            // Save to vocabulary storage
            VocabularyStorage.shared.addWord(
                from: wordExplanation,
                userContext: suggestion.sourceSentence
            )

            // Update state to show success
            suggestions[index].isAdding = false
            suggestions[index].wasJustAdded = true
            suggestions[index].isAlreadySaved = true
            currentResult.vocabularySuggestions = suggestions
            result = currentResult

            Logger.info("Added vocabulary suggestion: \(suggestion.word)", category: .vocabulary)
        } catch {
            // Reset loading state on error
            suggestions[index].isAdding = false
            currentResult.vocabularySuggestions = suggestions
            result = currentResult

            Logger.error("Failed to add vocabulary suggestion: \(suggestion.word)", category: .vocabulary, error: error)
        }
    }

    /// Update a suggestion in the current result
    /// - Parameters:
    ///   - word: The word to update
    ///   - update: Closure to perform the update
    func updateSuggestion(_ word: String, update: (inout VocabularySuggestion) -> Void) {
        guard var currentResult = result,
              var suggestions = currentResult.vocabularySuggestions,
              let index = suggestions.firstIndex(where: { $0.word.lowercased() == word.lowercased() }) else {
            return
        }

        update(&suggestions[index])
        currentResult.vocabularySuggestions = suggestions
        result = currentResult
    }
}

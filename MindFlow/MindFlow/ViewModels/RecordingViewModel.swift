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
    @Published var state: TranscriptionState = .idle
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
        guard permissionManager.isMicrophonePermissionGranted else {
            state = .error("error.microphone_needed".localized)
            return
        }

        state = .recording
        duration = 0
        isPaused = false

        // Start recording
        audioRecorder.startRecording { [weak self] success in
            if !success {
                self?.state = .error("error.recording_failed".localized)
            }
        }

        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isPaused else { return }
                self.duration += 0.1
            }
        }
    }

    func pauseRecording() {
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

        Task {
            do {
                // Use new method that returns metadata
                let metadata = try await sttService.transcribeWithMetadata(audioURL: audioURL)
                await MainActor.run {
                    self.optimize(
                        originalText: metadata.text,
                        audioURL: audioURL,
                        transcriptionProvider: metadata.provider,
                        transcriptionModel: metadata.model
                    )
                }
            } catch {
                await MainActor.run {
                    self.state = .error(String(format: "error.transcription_failed".localized, error.localizedDescription))
                }
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

        Task {
            do {
                let refinedText: String
                let teacherExplanation: String?
                var vocabularySuggestions: [VocabularySuggestion]?

                // Check if teacher notes are enabled
                if settings.enableTeacherNotes {
                    // Use combined optimization method to get refined text, teacher explanation, and vocabulary suggestions
                    let optimizationResult = try await llmService.optimizeTextWithExplanation(originalText)
                    refinedText = optimizationResult.refinedText
                    teacherExplanation = optimizationResult.teacherExplanation
                    vocabularySuggestions = optimizationResult.vocabularySuggestions

                    // Check which words are already in vocabulary
                    vocabularySuggestions = await checkExistingVocabulary(suggestions: optimizationResult.vocabularySuggestions)
                } else {
                    // Only optimize text, no teacher explanation or vocabulary suggestions
                    refinedText = try await llmService.optimizeText(originalText)
                    teacherExplanation = nil
                    vocabularySuggestions = nil
                }

                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: refinedText,
                    duration: duration,
                    audioFilePath: audioURL.path,
                    transcriptionProvider: transcriptionProvider,
                    transcriptionModel: transcriptionModel,
                    optimizationModel: settings.llmModel.rawValue,
                    optimizationLevel: settings.optimizationLevel.rawValue,
                    outputStyle: settings.outputStyle.rawValue,
                    teacherExplanation: teacherExplanation,
                    vocabularySuggestions: vocabularySuggestions
                )

                // Save to server (don't block UI if this fails)
                // Only save if user is authenticated
                if self.isUserAuthenticated() {
                    if let explanation = teacherExplanation {
                        Task.detached(priority: .background) {
                            do {
                                _ = try await self.storageService.saveInteractionWithExplanation(
                                    transcription: originalText,
                                    refinedText: refinedText,
                                    teacherExplanation: explanation,
                                    audioDuration: self.duration
                                )
                            } catch {
                                Logger.error("Sync failed", category: .storage, error: error)
                            }
                        }
                    } else {
                        Task.detached(priority: .background) {
                            do {
                                _ = try await self.storageService.saveInteraction(
                                    transcription: originalText,
                                    refinedText: refinedText,
                                    audioDuration: self.duration
                                )
                            } catch {
                                Logger.error("Sync failed", category: .storage, error: error)
                            }
                        }
                    }
                }

                await MainActor.run {
                    self.result = result
                    self.state = .completed
                }
            } catch {
                // If optimization fails, save transcription only
                let result = TranscriptionResult(
                    originalText: originalText,
                    optimizedText: nil,
                    duration: duration,
                    audioFilePath: audioURL.path,
                    transcriptionProvider: transcriptionProvider,
                    transcriptionModel: transcriptionModel
                )

                // Save transcription-only to server
                // Only save if user is authenticated
                if self.isUserAuthenticated() {
                    Task.detached(priority: .background) {
                        do {
                            _ = try await self.storageService.saveInteraction(
                                transcription: originalText,
                                refinedText: nil,
                                audioDuration: self.duration
                            )
                        } catch {
                            Logger.error("Sync failed", category: .storage, error: error)
                        }
                    }
                }

                await MainActor.run {
                    self.result = result
                    self.state = .completed
                }
            }
        }
    }

    func reset() {
        state = .idle
        duration = 0
        pulseAnimation = false
        isPaused = false
        result = nil
    }

    // MARK: - Helper Methods

    private func isUserAuthenticated() -> Bool {
        return UserDefaults.standard.string(forKey: "supabase_access_token") != nil
    }

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

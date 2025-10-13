//
//  InteractionStorageService.swift
//  MindFlow
//
//  Service to manage storage of STT interactions
//

import Foundation

/// Coordinates the storage of MindFlow interactions
class InteractionStorageService {
    static let shared = InteractionStorageService()

    private let apiClient: MindFlowAPIClient
    private var settings: Settings {
        return Settings.shared
    }

    private init() {
        self.apiClient = MindFlowAPIClient.shared
    }

    // MARK: - Public Methods

    /// Save a complete interaction to the server
    /// - Parameters:
    ///   - transcription: Original transcription text
    ///   - refinedText: Optimized/refined text (optional)
    ///   - audioDuration: Duration of the audio in seconds
    /// - Returns: The created interaction record
    @discardableResult
    func saveInteraction(
        transcription: String,
        refinedText: String?,
        audioDuration: Double?
    ) async throws -> InteractionRecord {
        print("💾 [StorageService] Saving interaction (transcription only)")
        print("   📝 Transcription length: \(transcription.count) chars")
        print("   🎤 STT Provider: \(settings.sttProvider.rawValue)")
        print("   ⏱️ Duration: \(audioDuration?.rounded() ?? 0)s")

        let request = CreateInteractionRequest(
            originalTranscription: transcription,
            transcriptionApi: settings.sttProvider.rawValue,
            transcriptionModel: getTranscriptionModel(),
            refinedText: refinedText,
            optimizationModel: refinedText != nil ? settings.llmModel.rawValue : nil,
            optimizationLevel: refinedText != nil ? settings.optimizationLevel.rawValue : nil,
            outputStyle: refinedText != nil ? settings.outputStyle.rawValue : nil,
            teacherExplanation: nil, // Will be generated separately if needed
            audioDuration: audioDuration,
            audioFileUrl: nil
        )

        let record = try await apiClient.createInteraction(request)
        print("✅ [StorageService] Interaction saved successfully")
        return record
    }

    /// Save interaction with teacher explanation
    /// - Parameters:
    ///   - transcription: Original transcription text
    ///   - refinedText: Optimized/refined text
    ///   - teacherExplanation: Educational explanation of improvements
    ///   - audioDuration: Duration of the audio in seconds
    /// - Returns: The created interaction record
    @discardableResult
    func saveInteractionWithExplanation(
        transcription: String,
        refinedText: String,
        teacherExplanation: String,
        audioDuration: Double?
    ) async throws -> InteractionRecord {
        print("💾 [StorageService] Saving interaction (with optimization & teacher explanation)")
        print("   📝 Transcription length: \(transcription.count) chars")
        print("   ✨ Refined text length: \(refinedText.count) chars")
        print("   👨‍🏫 Teacher explanation length: \(teacherExplanation.count) chars")
        print("   🎤 STT Provider: \(settings.sttProvider.rawValue)")
        print("   🤖 LLM Model: \(settings.llmModel.rawValue)")
        print("   📊 Optimization Level: \(settings.optimizationLevel.rawValue)")
        print("   🎨 Output Style: \(settings.outputStyle.rawValue)")
        print("   ⏱️ Duration: \(audioDuration?.rounded() ?? 0)s")

        let request = CreateInteractionRequest(
            originalTranscription: transcription,
            transcriptionApi: settings.sttProvider.rawValue,
            transcriptionModel: getTranscriptionModel(),
            refinedText: refinedText,
            optimizationModel: settings.llmModel.rawValue,
            optimizationLevel: settings.optimizationLevel.rawValue,
            outputStyle: settings.outputStyle.rawValue,
            teacherExplanation: teacherExplanation,
            audioDuration: audioDuration,
            audioFileUrl: nil
        )

        let record = try await apiClient.createInteraction(request)
        print("✅ [StorageService] Interaction with explanation saved successfully")
        return record
    }

    /// Fetch all interactions for the current user
    func fetchInteractions(
        limit: Int? = 50,
        offset: Int? = nil
    ) async throws -> [InteractionRecord] {
        print("📖 [StorageService] Fetching interactions - Limit: \(limit ?? 0), Offset: \(offset ?? 0)")
        let interactions = try await apiClient.getInteractions(
            transcriptionApi: nil,
            optimizationLevel: nil,
            limit: limit,
            offset: offset
        )
        print("✅ [StorageService] Successfully fetched \(interactions.count) interactions")
        return interactions
    }

    /// Fetch interactions filtered by parameters
    func fetchFilteredInteractions(
        transcriptionApi: String? = nil,
        optimizationLevel: String? = nil,
        limit: Int? = 50,
        offset: Int? = nil
    ) async throws -> [InteractionRecord] {
        print("📖 [StorageService] Fetching filtered interactions")
        print("   🔍 Filters - API: \(transcriptionApi ?? "All"), Level: \(optimizationLevel ?? "All")")
        print("   📄 Pagination - Limit: \(limit ?? 0), Offset: \(offset ?? 0)")

        let interactions = try await apiClient.getInteractions(
            transcriptionApi: transcriptionApi,
            optimizationLevel: optimizationLevel,
            limit: limit,
            offset: offset
        )
        print("✅ [StorageService] Successfully fetched \(interactions.count) filtered interactions")
        return interactions
    }

    /// Delete an interaction by ID
    func deleteInteraction(_ id: UUID) async throws {
        print("🗑️ [StorageService] Deleting interaction - ID: \(id.uuidString)")
        try await apiClient.deleteInteraction(id)
        print("✅ [StorageService] Interaction deleted successfully")
    }

    // MARK: - Helper Methods

    private func getTranscriptionModel() -> String {
        switch settings.sttProvider {
        case .openAI:
            return "whisper-1"
        case .elevenLabs:
            return "scribe_v1"
        }
    }
}

//
//  InteractionStorageService.swift
//  MindFlow
//
//  Service to manage storage of STT interactions with local-first approach
//

import Foundation

/// Coordinates the storage of MindFlow interactions
/// Implements local-first storage with conditional backend sync
class InteractionStorageService {
    static let shared = InteractionStorageService()

    private let apiClient: MindFlowAPIClient
    private let localStorage: LocalInteractionStorage

    private var settings: Settings {
        return Settings.shared
    }

    private var isAuthenticated: Bool {
        // Check if user has valid Supabase session (stored in UserDefaults)
        return UserDefaults.standard.string(forKey: "supabase_access_token") != nil
    }

    private init() {
        self.apiClient = MindFlowAPIClient.shared
        self.localStorage = LocalInteractionStorage.shared
    }

    // MARK: - Public Methods

    /// Save interaction with local-first approach and conditional backend sync
    /// - Parameters:
    ///   - transcription: Original transcription text
    ///   - refinedText: Optimized/refined text (optional)
    ///   - audioDuration: Duration of the audio in seconds
    /// - Returns: The local interaction record (may or may not be synced)
    @discardableResult
    func saveInteraction(
        transcription: String,
        refinedText: String?,
        audioDuration: Double?
    ) async throws -> LocalInteraction {
        // Always save locally first
        let metadata = InteractionMetadata(
            transcriptionApi: settings.sttProvider.rawValue,
            transcriptionModel: getTranscriptionModel(),
            optimizationModel: refinedText != nil ? settings.llmModel.rawValue : nil,
            optimizationLevel: refinedText != nil ? settings.optimizationLevel.rawValue : nil,
            outputStyle: refinedText != nil ? settings.outputStyle.rawValue : nil
        )

        let localInteraction = localStorage.saveInteraction(
            transcription: transcription,
            refinedText: refinedText,
            teacherExplanation: nil,
            audioDuration: audioDuration,
            metadata: metadata
        )

        // Conditionally sync to backend
        await attemptBackendSync(interaction: localInteraction)

        return localInteraction
    }

    /// Save interaction with teacher explanation (local-first approach)
    /// - Parameters:
    ///   - transcription: Original transcription text
    ///   - refinedText: Optimized/refined text
    ///   - teacherExplanation: Educational explanation of improvements
    ///   - audioDuration: Duration of the audio in seconds
    /// - Returns: The local interaction record (may or may not be synced)
    @discardableResult
    func saveInteractionWithExplanation(
        transcription: String,
        refinedText: String,
        teacherExplanation: String,
        audioDuration: Double?
    ) async throws -> LocalInteraction {
        // Always save locally first
        let metadata = InteractionMetadata(
            transcriptionApi: settings.sttProvider.rawValue,
            transcriptionModel: getTranscriptionModel(),
            optimizationModel: settings.llmModel.rawValue,
            optimizationLevel: settings.optimizationLevel.rawValue,
            outputStyle: settings.outputStyle.rawValue
        )

        let localInteraction = localStorage.saveInteraction(
            transcription: transcription,
            refinedText: refinedText,
            teacherExplanation: teacherExplanation,
            audioDuration: audioDuration,
            metadata: metadata
        )

        // Conditionally sync to backend
        await attemptBackendSync(interaction: localInteraction)

        return localInteraction
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

    // MARK: - Manual Sync Methods

    /// Manually sync a specific local interaction to backend
    /// - Parameter interaction: The local interaction to sync
    /// - Returns: True if sync succeeded, false otherwise
    @discardableResult
    func manualSyncToBackend(interaction: LocalInteraction) async -> Bool {
        guard isAuthenticated else {
            print("⚠️ [StorageService] Not authenticated, cannot sync")
            return false
        }

        return await syncInteractionToBackend(interaction: interaction)
    }

    /// Sync all pending local interactions to backend
    /// - Returns: Number of successfully synced interactions
    @discardableResult
    func syncAllPending() async -> Int {
        guard isAuthenticated else {
            return 0
        }

        let pendingInteractions = localStorage.fetchPendingSyncInteractions()

        var successCount = 0
        for interaction in pendingInteractions {
            if await syncInteractionToBackend(interaction: interaction) {
                successCount += 1
            }
        }

        return successCount
    }

    // MARK: - Private Helper Methods

    /// Attempt to sync interaction to backend based on settings
    private func attemptBackendSync(interaction: LocalInteraction) async {
        // Check if auto-sync is enabled
        guard settings.autoSyncToBackend else {
            return
        }

        // Check authentication
        guard isAuthenticated else {
            return
        }

        // Check duration threshold
        let duration = interaction.audioDuration
        let threshold = settings.autoSyncThreshold

        if duration < threshold {
            return
        }

        // All conditions met, sync to backend
        await syncInteractionToBackend(interaction: interaction)
    }

    /// Sync a specific interaction to backend
    /// - Parameter interaction: The interaction to sync
    /// - Returns: True if successful, false otherwise
    @discardableResult
    private func syncInteractionToBackend(interaction: LocalInteraction) async -> Bool {
        do {
            let request = CreateInteractionRequest(
                originalTranscription: interaction.originalTranscription,
                transcriptionApi: interaction.transcriptionApi,
                transcriptionModel: interaction.transcriptionModel,
                refinedText: interaction.refinedText,
                optimizationModel: interaction.optimizationModel,
                optimizationLevel: interaction.optimizationLevel,
                outputStyle: interaction.outputStyle,
                teacherExplanation: interaction.teacherExplanation,
                audioDuration: interaction.audioDuration > 0 ? interaction.audioDuration : nil,
                audioFileUrl: interaction.audioFileUrl
            )

            let record = try await apiClient.createInteraction(request)

            // Mark as synced if we got an ID back
            guard let backendId = record.id else {
                print("⚠️ [StorageService] Backend returned no ID")
                localStorage.markSyncFailed(interaction: interaction, error: "Backend returned no ID")
                return false
            }

            localStorage.markAsSynced(interaction: interaction, backendId: backendId)
            return true

        } catch {
            print("❌ [StorageService] Failed to sync: \(error.localizedDescription)")
            localStorage.markSyncFailed(interaction: interaction, error: error.localizedDescription)
            return false
        }
    }

    private func getTranscriptionModel() -> String {
        switch settings.sttProvider {
        case .openAI:
            return "whisper-1"
        case .elevenLabs:
            return "scribe_v1"
        }
    }
}

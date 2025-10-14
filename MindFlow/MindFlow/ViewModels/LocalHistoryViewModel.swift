//
//  LocalHistoryViewModel.swift
//  MindFlow
//
//  ViewModel for local interaction history
//

import Foundation
import Combine

@MainActor
class LocalHistoryViewModel: ObservableObject {
    @Published var interactions: [LocalInteraction] = []
    @Published var isSyncing = false

    private let localStorage = LocalInteractionStorage.shared
    private let storageService = InteractionStorageService.shared

    var hasPendingSync: Bool {
        interactions.contains { $0.needsSync }
    }

    // MARK: - Public Methods

    func loadInteractions() {
        interactions = localStorage.fetchAllInteractions()
    }

    func syncInteraction(_ interaction: LocalInteraction) async {
        isSyncing = true
        await storageService.manualSyncToBackend(interaction: interaction)
        loadInteractions()
        isSyncing = false
    }

    func syncAllPending() async {
        isSyncing = true
        await storageService.syncAllPending()
        loadInteractions()
        isSyncing = false
    }
}

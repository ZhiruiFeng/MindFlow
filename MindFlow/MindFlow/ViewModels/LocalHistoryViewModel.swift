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
        defer { isSyncing = false }
        await storageService.manualSyncToBackend(interaction: interaction)
        loadInteractions()
    }

    func syncAllPending() async {
        isSyncing = true
        defer { isSyncing = false }
        await storageService.syncAllPending()
        loadInteractions()
    }
}

//
//  InteractionHistoryViewModel.swift
//  MindFlow
//
//  ViewModel for managing interaction history with pagination
//

import Foundation
import SwiftUI

@MainActor
class InteractionHistoryViewModel: ObservableObject {
    @Published var interactions: [InteractionRecord] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var hasMore: Bool = true

    private let storageService = InteractionStorageService.shared
    private let pageSize = 20
    private var currentOffset = 0

    init() {
        print("🔧 [HistoryViewModel] Initializing history view model")
        Task {
            await loadInitial()
        }
    }

    // MARK: - Public Methods

    /// Load initial page of interactions
    func loadInitial() async {
        guard !isLoading else {
            print("⚠️ [HistoryViewModel] Already loading, skipping initial load")
            return
        }

        print("📋 [HistoryViewModel] Loading initial page (size: \(pageSize))")
        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let fetchedInteractions = try await storageService.fetchInteractions(
                limit: pageSize,
                offset: 0
            )

            interactions = fetchedInteractions
            hasMore = fetchedInteractions.count >= pageSize
            currentOffset = fetchedInteractions.count

            print("✅ [HistoryViewModel] Initial load complete - \(fetchedInteractions.count) interactions loaded")
            print("   📄 Has more: \(hasMore), Current offset: \(currentOffset)")

        } catch {
            print("❌ [HistoryViewModel] Initial load failed: \(error.localizedDescription)")
            handleError(error)
        }

        isLoading = false
    }

    /// Load next page of interactions
    func loadMore() async {
        guard !isLoadingMore && hasMore else {
            print("⚠️ [HistoryViewModel] Cannot load more - Loading: \(isLoadingMore), HasMore: \(hasMore)")
            return
        }

        print("📋 [HistoryViewModel] Loading more interactions - Offset: \(currentOffset)")
        isLoadingMore = true
        errorMessage = nil

        do {
            let fetchedInteractions = try await storageService.fetchInteractions(
                limit: pageSize,
                offset: currentOffset
            )

            // Append new interactions
            interactions.append(contentsOf: fetchedInteractions)
            hasMore = fetchedInteractions.count >= pageSize
            currentOffset += fetchedInteractions.count

            print("✅ [HistoryViewModel] Load more complete - \(fetchedInteractions.count) new interactions")
            print("   📄 Total: \(interactions.count), Has more: \(hasMore), New offset: \(currentOffset)")

        } catch {
            print("❌ [HistoryViewModel] Load more failed: \(error.localizedDescription)")
            handleError(error)
        }

        isLoadingMore = false
    }

    /// Refresh the entire list
    func refresh() async {
        print("🔄 [HistoryViewModel] Refreshing interactions list")
        await loadInitial()
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        print("❌ [HistoryViewModel] Handling error: \(error)")

        if let apiError = error as? MindFlowAPIError {
            switch apiError {
            case .notAuthenticated:
                errorMessage = "Please sign in to view your history"
                print("   🔐 Authentication required")
            case .httpError(let statusCode, let message):
                if statusCode == 401 || statusCode == 403 {
                    errorMessage = "Authentication expired. Please sign in again."
                    print("   🔐 Authentication expired - HTTP \(statusCode)")
                } else {
                    errorMessage = "Server error: \(message)"
                    print("   🌐 Server error - HTTP \(statusCode): \(message)")
                }
            default:
                errorMessage = apiError.localizedDescription
                print("   ⚠️ API error: \(apiError.localizedDescription)")
            }
        } else {
            errorMessage = error.localizedDescription
            print("   ⚠️ General error: \(error.localizedDescription)")
        }
    }
}

//
//  VocabularySyncService.swift
//  MindFlow
//
//  Service for syncing vocabulary with Supabase backend
//

import Foundation
import CoreData

/// Service for vocabulary synchronization with backend
class VocabularySyncService {
    static let shared = VocabularySyncService()

    private let storage = VocabularyStorage.shared
    private let coreData = CoreDataManager.shared
    private let settings = Settings.shared

    // Sync state
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    // Supabase configuration
    private var supabaseURL: String?
    private var supabaseKey: String?

    private init() {
        print("🔧 [VocabularySyncService] Service initialized")
    }

    // MARK: - Configuration

    /// Configure Supabase connection
    /// - Parameters:
    ///   - url: Supabase project URL
    ///   - key: Supabase anon key
    func configure(url: String, key: String) {
        supabaseURL = url
        supabaseKey = key
        print("✅ [VocabularySyncService] Configured with URL: \(url)")
    }

    /// Check if sync is configured and enabled
    var isEnabled: Bool {
        return settings.vocabularySyncEnabled && supabaseURL != nil && supabaseKey != nil
    }

    /// Check if sync is configured (regardless of enabled setting)
    var isConfigured: Bool {
        return supabaseURL != nil && supabaseKey != nil
    }

    // MARK: - Sync Operations

    /// Sync result structure
    struct SyncResult {
        let pushed: Int
        let pulled: Int
    }

    /// Sync vocabulary to backend
    /// - Returns: Number of entries pushed
    /// - Throws: SyncError if sync fails
    func syncToBackend() async throws -> Int {
        guard isEnabled else {
            throw SyncError.notConfigured
        }

        guard !isSyncing else {
            throw SyncError.alreadySyncing
        }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 [VocabularySyncService] Starting sync to backend...")

        // Get pending entries
        let pendingEntries = fetchPendingEntries()
        print("📤 [VocabularySyncService] Found \(pendingEntries.count) entries to sync")

        guard !pendingEntries.isEmpty else {
            print("✅ [VocabularySyncService] No entries to sync")
            lastSyncDate = Date()
            return 0
        }

        var syncedCount = 0

        // Sync each entry
        for entry in pendingEntries {
            do {
                try await syncEntry(entry)
                syncedCount += 1
            } catch {
                print("❌ [VocabularySyncService] Failed to sync entry \(entry.word): \(error)")
                // Continue with other entries
            }
        }

        lastSyncDate = Date()
        print("✅ [VocabularySyncService] Sync completed: \(syncedCount) entries")
        return syncedCount
    }

    /// Sync from backend - fetch new/updated entries
    /// - Returns: Number of entries pulled
    /// - Throws: SyncError if sync fails
    func syncFromBackend() async throws -> Int {
        guard isEnabled else {
            throw SyncError.notConfigured
        }

        guard !isSyncing else {
            throw SyncError.alreadySyncing
        }

        isSyncing = true
        defer { isSyncing = false }

        print("🔄 [VocabularySyncService] Starting sync from backend...")

        // Fetch entries from backend
        let remoteEntries = try await fetchRemoteEntries()
        print("📥 [VocabularySyncService] Fetched \(remoteEntries.count) remote entries")

        var processedCount = 0

        // Process each remote entry
        for remoteEntry in remoteEntries {
            do {
                try await processRemoteEntry(remoteEntry)
                processedCount += 1
            } catch {
                print("❌ [VocabularySyncService] Failed to process remote entry: \(error)")
            }
        }

        lastSyncDate = Date()
        print("✅ [VocabularySyncService] Sync from backend completed: \(processedCount) entries")
        return processedCount
    }

    /// Full bidirectional sync
    /// - Returns: SyncResult with pushed and pulled counts
    /// - Throws: SyncError if sync fails
    func fullSync() async throws -> SyncResult {
        // First push local changes
        let pushed = try await syncToBackend()

        // Then pull remote changes
        let pulled = try await syncFromBackend()

        return SyncResult(pushed: pushed, pulled: pulled)
    }

    // MARK: - Private Methods

    private func fetchPendingEntries() -> [VocabularyEntry] {
        let request: NSFetchRequest<VocabularyEntry> = VocabularyEntry.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", VocabularyEntry.SyncStatus.pending.rawValue)

        do {
            return try coreData.viewContext.fetch(request)
        } catch {
            print("❌ [VocabularySyncService] Failed to fetch pending entries: \(error)")
            return []
        }
    }

    private func syncEntry(_ entry: VocabularyEntry) async throws {
        guard let url = supabaseURL, let key = supabaseKey else {
            throw SyncError.notConfigured
        }

        let endpoint = "\(url)/rest/v1/vocabulary"

        // Prepare entry data
        let entryData = createSyncPayload(from: entry)

        // Create request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = entry.backendId == nil ? "POST" : "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        request.httpBody = try JSONSerialization.data(withJSONObject: entryData)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }

        // Parse response to get backend ID
        if let responseArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstItem = responseArray.first,
           let backendId = firstItem["id"] as? String {

            // Update local entry
            await MainActor.run {
                entry.backendId = backendId
                entry.syncStatus = VocabularyEntry.SyncStatus.synced.rawValue
                coreData.saveContext()
            }

            print("✅ [VocabularySyncService] Synced entry: \(entry.word) -> \(backendId)")
        }
    }

    private func createSyncPayload(from entry: VocabularyEntry) -> [String: Any] {
        var payload: [String: Any] = [
            "word": entry.word,
            "mastery_level": entry.masteryLevel,
            "ease_factor": entry.easeFactor,
            "interval": entry.interval,
            "review_count": entry.reviewCount,
            "correct_count": entry.correctCount,
            "is_favorite": entry.isFavorite,
            "is_archived": entry.isArchived,
            "created_at": ISO8601DateFormatter().string(from: entry.createdAt),
            "updated_at": ISO8601DateFormatter().string(from: entry.updatedAt)
        ]

        // Add optional fields
        if let phonetic = entry.phonetic { payload["phonetic"] = phonetic }
        if let pos = entry.partOfSpeech { payload["part_of_speech"] = pos }
        if let defEN = entry.definitionEN { payload["definition_en"] = defEN }
        if let defCN = entry.definitionCN { payload["definition_cn"] = defCN }
        if let examples = entry.exampleSentences { payload["example_sentences"] = examples }
        if let synonyms = entry.synonyms { payload["synonyms"] = synonyms }
        if let antonyms = entry.antonyms { payload["antonyms"] = antonyms }
        if let context = entry.userContext { payload["user_context"] = context }
        if let category = entry.category { payload["category"] = category }
        if let tags = entry.tags { payload["tags"] = tags }
        // notes field removed - not in VocabularyEntry model
        if let lastReviewed = entry.lastReviewedAt {
            payload["last_reviewed_at"] = ISO8601DateFormatter().string(from: lastReviewed)
        }
        if let nextReview = entry.nextReviewAt {
            payload["next_review_at"] = ISO8601DateFormatter().string(from: nextReview)
        }

        // Include local ID for reference
        payload["local_id"] = entry.id.uuidString

        return payload
    }

    private func fetchRemoteEntries() async throws -> [[String: Any]] {
        guard let url = supabaseURL, let key = supabaseKey else {
            throw SyncError.notConfigured
        }

        // Fetch entries updated after last sync
        var endpoint = "\(url)/rest/v1/vocabulary?select=*"
        if let lastSync = lastSyncDate {
            let isoDate = ISO8601DateFormatter().string(from: lastSync)
            endpoint += "&updated_at=gt.\(isoDate)"
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }

        guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return entries
    }

    private func processRemoteEntry(_ remoteEntry: [String: Any]) async throws {
        guard let word = remoteEntry["word"] as? String,
              let backendId = remoteEntry["id"] as? String else {
            return
        }

        // Check if entry exists locally
        let existingEntry = storage.fetchWord(byText: word)

        if let existing = existingEntry {
            // Conflict resolution: compare updated_at timestamps
            if let remoteUpdatedStr = remoteEntry["updated_at"] as? String,
               let remoteUpdated = ISO8601DateFormatter().date(from: remoteUpdatedStr) {

                if remoteUpdated > existing.updatedAt {
                    // Remote is newer - update local
                    await MainActor.run {
                        updateLocalEntry(existing, from: remoteEntry)
                    }
                }
                // Otherwise keep local version (it will be pushed on next sync)
            }
        } else {
            // New entry from remote - create locally
            await MainActor.run {
                createLocalEntry(from: remoteEntry)
            }
        }
    }

    private func updateLocalEntry(_ entry: VocabularyEntry, from remote: [String: Any]) {
        if let phonetic = remote["phonetic"] as? String { entry.phonetic = phonetic }
        if let pos = remote["part_of_speech"] as? String { entry.partOfSpeech = pos }
        if let defEN = remote["definition_en"] as? String { entry.definitionEN = defEN }
        if let defCN = remote["definition_cn"] as? String { entry.definitionCN = defCN }
        if let examples = remote["example_sentences"] as? String { entry.exampleSentences = examples }
        if let synonyms = remote["synonyms"] as? String { entry.synonyms = synonyms }
        if let antonyms = remote["antonyms"] as? String { entry.antonyms = antonyms }
        if let context = remote["user_context"] as? String { entry.userContext = context }
        if let category = remote["category"] as? String { entry.category = category }
        if let tags = remote["tags"] as? String { entry.tags = tags }
        // notes field removed - not in VocabularyEntry model

        // Learning progress
        if let masteryLevel = remote["mastery_level"] as? Int16 { entry.masteryLevel = masteryLevel }
        if let easeFactor = remote["ease_factor"] as? Double { entry.easeFactor = easeFactor }
        if let interval = remote["interval"] as? Int32 { entry.interval = interval }
        if let reviewCount = remote["review_count"] as? Int32 { entry.reviewCount = reviewCount }
        if let correctCount = remote["correct_count"] as? Int32 { entry.correctCount = correctCount }

        if let isFavorite = remote["is_favorite"] as? Bool { entry.isFavorite = isFavorite }
        if let isArchived = remote["is_archived"] as? Bool { entry.isArchived = isArchived }

        if let lastReviewedStr = remote["last_reviewed_at"] as? String {
            entry.lastReviewedAt = ISO8601DateFormatter().date(from: lastReviewedStr)
        }
        if let nextReviewStr = remote["next_review_at"] as? String {
            entry.nextReviewAt = ISO8601DateFormatter().date(from: nextReviewStr)
        }
        if let updatedStr = remote["updated_at"] as? String {
            entry.updatedAt = ISO8601DateFormatter().date(from: updatedStr) ?? Date()
        }

        entry.backendId = remote["id"] as? String
        entry.syncStatus = VocabularyEntry.SyncStatus.synced.rawValue

        coreData.saveContext()
        print("📥 [VocabularySyncService] Updated local entry: \(entry.word)")
    }

    private func createLocalEntry(from remote: [String: Any]) {
        guard let word = remote["word"] as? String else { return }

        let context = coreData.viewContext
        let entry = VocabularyEntry(context: context)

        entry.id = UUID()
        entry.word = word

        // Copy all fields from remote
        updateLocalEntry(entry, from: remote)

        // Override created_at
        if let createdStr = remote["created_at"] as? String {
            entry.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? Date()
        } else {
            entry.createdAt = Date()
        }

        coreData.saveContext()
        print("📥 [VocabularySyncService] Created local entry from remote: \(entry.word)")
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case notConfigured
    case alreadySyncing
    case serverError
    case networkError
    case conflictError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sync is not configured. Please set up your account in settings."
        case .alreadySyncing:
            return "Sync is already in progress."
        case .serverError:
            return "Server error occurred. Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        case .conflictError:
            return "Sync conflict detected."
        }
    }
}

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

    // Supabase connection (set via configure(url:key:))
    private var supabaseURL: String?
    private var supabaseKey: String?

    // Sync state
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    // Guards mutation/inspection of `isSyncing` so two concurrent syncs can't
    // both pass the guard (TOCTOU). The check-and-set is performed atomically.
    private let syncLock = NSLock()

    // Cached ISO8601 formatters. JSONSerialization/Postgres timestamps may or may
    // not include fractional seconds, so we keep one of each and try both on parse.
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parse an ISO8601 string, tolerating timestamps with or without fractional seconds.
    private static func parseISODate(_ string: String) -> Date? {
        return iso8601WithFractional.date(from: string) ?? iso8601Plain.date(from: string)
    }

    /// Serialize a date to ISO8601 with fractional seconds.
    private static func formatISODate(_ date: Date) -> String {
        return iso8601WithFractional.string(from: date)
    }

    /// Atomically attempt to begin a sync. Returns false if one is already running.
    private func beginSyncIfPossible() -> Bool {
        syncLock.lock()
        defer { syncLock.unlock() }
        guard !isSyncing else { return false }
        isSyncing = true
        return true
    }

    /// Atomically clear the syncing flag.
    private func endSync() {
        syncLock.lock()
        isSyncing = false
        syncLock.unlock()
    }

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

        guard beginSyncIfPossible() else {
            throw SyncError.alreadySyncing
        }
        defer { endSync() }

        print("🔄 [VocabularySyncService] Starting sync to backend...")

        // Get pending entries (Core Data access must run on the main actor)
        let pendingEntries = await MainActor.run { fetchPendingEntries() }
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

        guard beginSyncIfPossible() else {
            throw SyncError.alreadySyncing
        }
        defer { endSync() }

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

        guard let requestURL = URL(string: endpoint) else {
            throw SyncError.notConfigured
        }

        // Prepare entry data and read managed-object state on the main actor
        let (entryData, httpMethod, word) = await MainActor.run {
            (createSyncPayload(from: entry),
             entry.backendId == nil ? "POST" : "PATCH",
             entry.word)
        }

        // Create request
        var request = URLRequest(url: requestURL)
        request.httpMethod = httpMethod
        request.timeoutInterval = 30.0
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

            print("✅ [VocabularySyncService] Synced entry: \(word) -> \(backendId)")
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
            "created_at": Self.formatISODate(entry.createdAt),
            "updated_at": Self.formatISODate(entry.updatedAt)
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
            payload["last_reviewed_at"] = Self.formatISODate(lastReviewed)
        }
        if let nextReview = entry.nextReviewAt {
            payload["next_review_at"] = Self.formatISODate(nextReview)
        }

        // Include local ID for reference
        payload["local_id"] = entry.id.uuidString

        return payload
    }

    private func fetchRemoteEntries() async throws -> [[String: Any]] {
        guard let url = supabaseURL, let key = supabaseKey else {
            throw SyncError.notConfigured
        }

        // Fetch entries updated after last sync. Build the query with URLComponents
        // so date/values are properly percent-encoded.
        guard var components = URLComponents(string: "\(url)/rest/v1/vocabulary") else {
            throw SyncError.notConfigured
        }
        var queryItems = [URLQueryItem(name: "select", value: "*")]
        if let lastSync = lastSyncDate {
            let isoDate = Self.formatISODate(lastSync)
            queryItems.append(URLQueryItem(name: "updated_at", value: "gt.\(isoDate)"))
        }
        components.queryItems = queryItems

        guard let requestURL = components.url else {
            throw SyncError.notConfigured
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
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

        // All Core Data access (fetch, comparison, mutation) runs on the main actor.
        await MainActor.run {
            // Check if entry exists locally
            let existingEntry = storage.fetchWord(byText: word)

            if let existing = existingEntry {
                // Conflict resolution: compare updated_at timestamps
                if let remoteUpdatedStr = remoteEntry["updated_at"] as? String,
                   let remoteUpdated = Self.parseISODate(remoteUpdatedStr) {

                    if remoteUpdated > existing.updatedAt {
                        // Remote is newer - update local
                        updateLocalEntry(existing, from: remoteEntry)
                    }
                    // Otherwise keep local version (it will be pushed on next sync)
                }
            } else {
                // New entry from remote - create locally
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
        // JSONSerialization yields NSNumber for numeric fields, never the exact
        // CoreData width (Int16/Int32), so cast to NSNumber and convert.
        if let masteryLevel = remote["mastery_level"] as? NSNumber { entry.masteryLevel = masteryLevel.int16Value }
        if let easeFactor = remote["ease_factor"] as? NSNumber { entry.easeFactor = easeFactor.doubleValue }
        if let interval = remote["interval"] as? NSNumber { entry.interval = interval.int32Value }
        if let reviewCount = remote["review_count"] as? NSNumber { entry.reviewCount = reviewCount.int32Value }
        if let correctCount = remote["correct_count"] as? NSNumber { entry.correctCount = correctCount.int32Value }

        if let isFavorite = remote["is_favorite"] as? Bool { entry.isFavorite = isFavorite }
        if let isArchived = remote["is_archived"] as? Bool { entry.isArchived = isArchived }

        if let lastReviewedStr = remote["last_reviewed_at"] as? String {
            entry.lastReviewedAt = Self.parseISODate(lastReviewedStr)
        }
        if let nextReviewStr = remote["next_review_at"] as? String {
            entry.nextReviewAt = Self.parseISODate(nextReviewStr)
        }
        if let updatedStr = remote["updated_at"] as? String {
            entry.updatedAt = Self.parseISODate(updatedStr) ?? Date()
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
            entry.createdAt = Self.parseISODate(createdStr) ?? Date()
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

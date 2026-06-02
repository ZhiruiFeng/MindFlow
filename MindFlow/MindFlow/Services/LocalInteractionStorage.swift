//
//  LocalInteractionStorage.swift
//  MindFlow
//
//  Service for managing local interaction storage with Core Data
//

import Foundation
import CoreData

/// Service for local interaction storage and retrieval
///
/// `CoreDataManager.viewContext` is a main-queue context, so all access to it
/// and to its managed objects must occur on the main actor.
@MainActor
class LocalInteractionStorage {
    static let shared = LocalInteractionStorage()

    private let coreData = CoreDataManager.shared

    private init() {
        print("🔧 [LocalStorage] Service initialized")
    }

    // MARK: - Create

    /// Save a new interaction to local storage
    /// - Parameters:
    ///   - transcription: Original transcription text
    ///   - refinedText: Optimized text (optional)
    ///   - teacherExplanation: Educational feedback (optional)
    ///   - audioDuration: Duration in seconds
    ///   - metadata: STT and optimization metadata
    /// - Returns: The created LocalInteraction object
    @discardableResult
    func saveInteraction(
        transcription: String,
        refinedText: String?,
        teacherExplanation: String?,
        audioDuration: Double?,
        metadata: InteractionMetadata,
        vocabularySuggestions: [VocabularySuggestion]? = nil
    ) -> LocalInteraction {
        let context = coreData.viewContext
        let interaction = LocalInteraction(context: context)

        // Identity
        interaction.id = UUID()
        interaction.createdAt = Date()
        interaction.updatedAt = Date()

        // Content
        interaction.originalTranscription = transcription
        interaction.refinedText = refinedText
        interaction.teacherExplanation = teacherExplanation
        if let suggestions = vocabularySuggestions {
            interaction.vocabularySuggestionsArray = suggestions
        }

        // Metadata
        interaction.transcriptionApi = metadata.transcriptionApi
        interaction.transcriptionModel = metadata.transcriptionModel
        interaction.optimizationModel = metadata.optimizationModel
        interaction.optimizationLevel = metadata.optimizationLevel
        interaction.outputStyle = metadata.outputStyle
        interaction.audioDuration = audioDuration ?? 0
        interaction.audioFileUrl = nil

        // Sync status - default to pending
        interaction.syncStatusEnum = .pending
        interaction.backendId = nil
        interaction.lastSyncAttempt = nil
        interaction.syncErrorMessage = nil
        interaction.syncRetryCount = 0

        coreData.saveContext()

        print("💾 [LocalStorage] Interaction saved locally")
        print("   📝 ID: \(interaction.id)")
        print("   ⏱️ Duration: \(interaction.audioDuration)s")
        print("   🔄 Sync status: \(interaction.syncStatusEnum.rawValue)")

        return interaction
    }

    // MARK: - Read

    /// Fetch all interactions sorted by creation date (newest first)
    /// - Returns: Array of LocalInteraction objects
    func fetchAllInteractions() -> [LocalInteraction] {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let interactions = try coreData.viewContext.fetch(request)
            print("📋 [LocalStorage] Fetched \(interactions.count) interactions")
            return interactions
        } catch {
            print("❌ [LocalStorage] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch interactions with pagination
    /// - Parameters:
    ///   - limit: Maximum number of interactions to fetch
    ///   - offset: Number of interactions to skip
    /// - Returns: Array of LocalInteraction objects
    func fetchInteractions(limit: Int, offset: Int) -> [LocalInteraction] {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        request.fetchOffset = offset

        do {
            let interactions = try coreData.viewContext.fetch(request)
            print("📋 [LocalStorage] Fetched \(interactions.count) interactions (limit: \(limit), offset: \(offset))")
            return interactions
        } catch {
            print("❌ [LocalStorage] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch interactions that need to be synced
    /// - Returns: Array of LocalInteraction objects with pending sync status
    func fetchPendingSyncInteractions() -> [LocalInteraction] {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", LocalInteraction.SyncStatus.pending.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)] // Oldest first

        do {
            let interactions = try coreData.viewContext.fetch(request)
            print("🔄 [LocalStorage] Found \(interactions.count) interactions pending sync")
            return interactions
        } catch {
            print("❌ [LocalStorage] Fetch pending error: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single interaction by ID
    /// - Parameter id: The UUID of the interaction
    /// - Returns: LocalInteraction if found, nil otherwise
    func fetchInteraction(by id: UUID) -> LocalInteraction? {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let interactions = try coreData.viewContext.fetch(request)
            return interactions.first
        } catch {
            print("❌ [LocalStorage] Fetch by ID error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Update

    /// Mark an interaction as successfully synced
    /// - Parameters:
    ///   - interaction: The interaction to update
    ///   - backendId: The UUID from the backend
    func markAsSynced(interaction: LocalInteraction, backendId: UUID) {
        interaction.syncStatusEnum = .synced
        interaction.backendId = backendId
        interaction.lastSyncAttempt = Date()
        interaction.syncErrorMessage = nil
        interaction.updatedAt = Date()

        coreData.saveContext()

        print("✅ [LocalStorage] Marked as synced")
        print("   📝 Local ID: \(interaction.id)")
        print("   🌐 Backend ID: \(backendId)")
    }

    /// Mark an interaction as failed to sync
    /// - Parameters:
    ///   - interaction: The interaction to update
    ///   - error: The error message
    func markSyncFailed(interaction: LocalInteraction, error: String) {
        interaction.syncStatusEnum = .failed
        interaction.syncErrorMessage = error
        interaction.lastSyncAttempt = Date()
        interaction.syncRetryCount += 1
        interaction.updatedAt = Date()

        coreData.saveContext()

        print("❌ [LocalStorage] Sync failed")
        print("   📝 ID: \(interaction.id)")
        print("   ⚠️ Error: \(error)")
        print("   🔁 Retry count: \(interaction.syncRetryCount)")
    }

    /// Reset sync status to pending (for retry)
    /// - Parameter interaction: The interaction to reset
    func resetSyncStatus(interaction: LocalInteraction) {
        interaction.syncStatusEnum = .pending
        interaction.syncErrorMessage = nil
        interaction.updatedAt = Date()

        coreData.saveContext()

        print("🔄 [LocalStorage] Sync status reset to pending: \(interaction.id)")
    }

    // MARK: - Delete

    /// Delete a single interaction
    /// - Parameter interaction: The interaction to delete
    func deleteInteraction(_ interaction: LocalInteraction) {
        let id = interaction.id
        coreData.viewContext.delete(interaction)
        coreData.saveContext()

        print("🗑️ [LocalStorage] Interaction deleted: \(id)")
    }

    /// Delete all interactions (use with caution!)
    func deleteAllInteractions() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LocalInteraction.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let context = coreData.viewContext
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let deletedObjectIDs = result?.result as? [NSManagedObjectID] ?? []
            // Batch deletes bypass the context, so merge the deletions into the
            // main-queue viewContext to keep in-memory objects consistent.
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
                into: [context]
            )
            print("🗑️ [LocalStorage] All interactions deleted (\(deletedObjectIDs.count))")
        } catch {
            print("❌ [LocalStorage] Delete all error: \(error.localizedDescription)")
        }
    }

    /// Delete synced interactions older than a certain date
    /// - Parameter date: Delete interactions synced before this date
    func deleteSyncedInteractionsOlderThan(date: Date) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = LocalInteraction.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "syncStatus == %@ AND lastSyncAttempt < %@",
            LocalInteraction.SyncStatus.synced.rawValue,
            date as CVarArg
        )

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let context = coreData.viewContext
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let deletedObjectIDs = result?.result as? [NSManagedObjectID] ?? []
            // Batch deletes bypass the context, so merge the deletions into the
            // main-queue viewContext to keep in-memory objects consistent.
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
                into: [context]
            )
            print("🗑️ [LocalStorage] Deleted \(deletedObjectIDs.count) old synced interactions")
        } catch {
            print("❌ [LocalStorage] Delete old synced error: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    /// Get count of interactions by sync status
    /// - Returns: Dictionary with counts for each status
    func getCountsBySyncStatus() -> [String: Int] {
        var counts: [String: Int] = [:]

        for status in [LocalInteraction.SyncStatus.pending, .synced, .failed] {
            let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
            request.predicate = NSPredicate(format: "syncStatus == %@", status.rawValue)

            do {
                let count = try coreData.viewContext.count(for: request)
                counts[status.rawValue] = count
            } catch {
                print("❌ [LocalStorage] Count error for \(status.rawValue): \(error)")
                counts[status.rawValue] = 0
            }
        }

        print("📊 [LocalStorage] Sync status counts: \(counts)")
        return counts
    }
}

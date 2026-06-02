//
//  CoreDataManager.swift
//  MindFlow
//
//  Core Data stack manager for local persistence
//

import Foundation
import CoreData

/// Manages the Core Data stack for local interaction storage
class CoreDataManager {
    static let shared = CoreDataManager()

    private init() {
        print("🔧 [CoreData] Initializing Core Data stack")
    }

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        return Self.makePersistentContainer()
    }()

    /// Build and fully configure a persistent container.
    ///
    /// Centralizes all container setup (UI-test in-memory store, store loading,
    /// merge behavior) so that both the lazy initializer and `resetPersistentStore()`
    /// produce an identically configured stack.
    private static func makePersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "MindFlow")

        // Under UI-test automation, use a throwaway in-memory store so tests can
        // create/delete data freely without ever touching the user's real
        // vocabulary, and start from a clean, deterministic state every run.
        if LaunchMode.isUITesting {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // Do not crash on launch: log the failure and continue so the app
                // can still start (in a degraded, store-less state) rather than
                // taking down the whole process.
                Logger.error(
                    "Unable to load persistent stores",
                    category: .storage,
                    error: error
                )
                return
            }
            Logger.info("Persistent store loaded: \(description)", category: .storage)
        }

        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        Logger.info("Persistent container ready", category: .storage)
        return container
    }

    /// Main view context (use on main thread)
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    /// Create a background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Save Context

    /// Save changes in the view context
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
                Logger.debug("Context saved successfully", category: .storage)
            } catch {
                // Roll back the unsaved changes and log the error instead of
                // crashing the app on a save failure.
                context.rollback()
                Logger.error("Save error, rolled back changes", category: .storage, error: error)
            }
        }
    }

    /// Save changes in a background context
    func saveBackgroundContext(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                    print("💾 [CoreData] Background context saved")
                } catch {
                    let nsError = error as NSError
                    print("❌ [CoreData] Background save error: \(nsError)")
                }
            }
        }
    }

    // MARK: - Utilities

    /// Delete all data from an entity (useful for testing)
    func deleteAllData(for entityName: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            // Merge the deletions into the view context so in-memory objects and
            // fetched results controllers stay consistent (batch deletes bypass
            // the context).
            if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [viewContext]
                )
            }
            Logger.info("Deleted all data for \(entityName)", category: .storage)
        } catch {
            Logger.error("Delete error for \(entityName)", category: .storage, error: error)
        }
    }

    /// Reset the entire persistent store (use with caution!)
    func resetPersistentStore() {
        let coordinator = persistentContainer.persistentStoreCoordinator

        for store in coordinator.persistentStores {
            guard let storeURL = store.url else { continue }

            do {
                try coordinator.destroyPersistentStore(
                    at: storeURL,
                    ofType: store.type,
                    options: nil
                )
                Logger.info("Destroyed persistent store", category: .storage)
            } catch {
                Logger.error("Destroy error", category: .storage, error: error)
            }
        }

        // Recreate using the shared configuration so the reset stack matches the
        // original lazily-initialized one (merge policies, UI-test in-memory
        // store, automatic merging, error logging on reload).
        persistentContainer = Self.makePersistentContainer()
    }
}

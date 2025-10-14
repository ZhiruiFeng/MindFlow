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
        let container = NSPersistentContainer(name: "MindFlow")

        container.loadPersistentStores { description, error in
            if let error = error {
                // In production, handle this more gracefully
                fatalError("❌ [CoreData] Unable to load persistent stores: \(error)")
            }
            print("✅ [CoreData] Persistent store loaded: \(description)")
        }

        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        print("✅ [CoreData] Persistent container ready")
        return container
    }()

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
                print("💾 [CoreData] Context saved successfully")
            } catch {
                let nsError = error as NSError
                print("❌ [CoreData] Save error: \(nsError), \(nsError.userInfo)")
                // In production, handle this more gracefully
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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

        do {
            try viewContext.execute(deleteRequest)
            saveContext()
            print("🗑️ [CoreData] Deleted all data for \(entityName)")
        } catch {
            print("❌ [CoreData] Delete error: \(error)")
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
                print("🗑️ [CoreData] Destroyed persistent store")
            } catch {
                print("❌ [CoreData] Destroy error: \(error)")
            }
        }

        // Recreate
        persistentContainer = NSPersistentContainer(name: "MindFlow")
        persistentContainer.loadPersistentStores { _, _ in }
    }
}

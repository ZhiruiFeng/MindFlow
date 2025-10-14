//
//  LocalInteraction+CoreDataClass.swift
//  MindFlow
//
//  Created on 2025-10-14.
//

import Foundation
import CoreData

@objc(LocalInteraction)
public class LocalInteraction: NSManagedObject {

    // MARK: - Sync Status Enum

    enum SyncStatus: String {
        case pending = "pending"
        case synced = "synced"
        case failed = "failed"
    }

    // MARK: - Computed Properties

    /// Check if this interaction needs to be synced
    var needsSync: Bool {
        return syncStatus == SyncStatus.pending.rawValue && backendId == nil
    }

    /// Check if this interaction is already synced
    var isSynced: Bool {
        return syncStatus == SyncStatus.synced.rawValue && backendId != nil
    }

    /// Check if sync failed and can be retried
    var canRetrySync: Bool {
        return syncStatus == SyncStatus.failed.rawValue && syncRetryCount < 3
    }

    // MARK: - Helper Methods

    /// Typed sync status setter
    var syncStatusEnum: SyncStatus {
        get {
            return SyncStatus(rawValue: syncStatus ?? "pending") ?? .pending
        }
        set {
            syncStatus = newValue.rawValue
        }
    }
}

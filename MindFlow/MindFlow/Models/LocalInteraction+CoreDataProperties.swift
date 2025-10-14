//
//  LocalInteraction+CoreDataProperties.swift
//  MindFlow
//
//  Created on 2025-10-14.
//

import Foundation
import CoreData

extension LocalInteraction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalInteraction> {
        return NSFetchRequest<LocalInteraction>(entityName: "LocalInteraction")
    }

    // MARK: - Identity

    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // MARK: - Content

    @NSManaged public var originalTranscription: String
    @NSManaged public var refinedText: String?
    @NSManaged public var teacherExplanation: String?

    // MARK: - Metadata

    @NSManaged public var transcriptionApi: String
    @NSManaged public var transcriptionModel: String?
    @NSManaged public var optimizationModel: String?
    @NSManaged public var optimizationLevel: String?
    @NSManaged public var outputStyle: String?
    @NSManaged public var userLanguage: String?
    @NSManaged public var audioDuration: Double
    @NSManaged public var audioFileUrl: String?

    // MARK: - Sync Status

    @NSManaged public var syncStatus: String?
    @NSManaged public var backendId: UUID?
    @NSManaged public var lastSyncAttempt: Date?
    @NSManaged public var syncRetryCount: Int16
    @NSManaged public var syncErrorMessage: String?
}

// MARK: - Generated accessors

extension LocalInteraction: Identifiable {
}

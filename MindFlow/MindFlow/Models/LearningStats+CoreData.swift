//
//  LearningStats+CoreData.swift
//  MindFlow
//
//  Core Data model for daily learning statistics
//

import Foundation
import CoreData

@objc(LearningStats)
public class LearningStats: NSManagedObject {

    // MARK: - Computed Properties

    /// Review accuracy percentage for the day
    var accuracy: Double {
        let totalReviews = correctReviews + incorrectReviews
        guard totalReviews > 0 else { return 0.0 }
        return Double(correctReviews) / Double(totalReviews) * 100.0
    }

    /// Formatted study time string
    var formattedStudyTime: String {
        let hours = studyTimeSeconds / 3600
        let minutes = (studyTimeSeconds % 3600) / 60
        let seconds = studyTimeSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Total activities (words added + words reviewed)
    var totalActivities: Int32 {
        return wordsAdded + wordsReviewed
    }

    /// Whether there was any activity on this day
    var hasActivity: Bool {
        return wordsAdded > 0 || wordsReviewed > 0
    }
}

// MARK: - Fetch Request

extension LearningStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LearningStats> {
        return NSFetchRequest<LearningStats>(entityName: "LearningStats")
    }

    // MARK: - Identity

    @NSManaged public var id: UUID
    @NSManaged public var date: Date

    // MARK: - Daily Statistics

    @NSManaged public var wordsAdded: Int32
    @NSManaged public var wordsReviewed: Int32
    @NSManaged public var correctReviews: Int32
    @NSManaged public var incorrectReviews: Int32
    @NSManaged public var studyTimeSeconds: Int32
    @NSManaged public var streakDays: Int32
}

// MARK: - Identifiable

extension LearningStats: Identifiable {}

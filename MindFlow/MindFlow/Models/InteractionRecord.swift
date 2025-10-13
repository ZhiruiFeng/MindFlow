//
//  InteractionRecord.swift
//  MindFlow
//
//  Model for MindFlow STT interactions stored in database
//

import Foundation

/// Represents a MindFlow STT interaction record in the database
struct InteractionRecord: Codable, Identifiable {
    let id: UUID?
    let userId: UUID?
    let originalTranscription: String?  // Made optional to handle missing data
    let transcriptionApi: String?       // Made optional to handle missing data
    let transcriptionModel: String?
    let refinedText: String?
    let optimizationModel: String?
    let optimizationLevel: String?
    let outputStyle: String?
    let teacherExplanation: String?
    let audioDuration: Double?
    let audioFileUrl: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case originalTranscription = "original_transcription"
        case transcriptionApi = "transcription_api"
        case transcriptionModel = "transcription_model"
        case refinedText = "refined_text"
        case optimizationModel = "optimization_model"
        case optimizationLevel = "optimization_level"
        case outputStyle = "output_style"
        case teacherExplanation = "teacher_explanation"
        case audioDuration = "audio_duration"
        case audioFileUrl = "audio_file_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID? = nil,
        userId: UUID? = nil,
        originalTranscription: String? = nil,
        transcriptionApi: String? = nil,
        transcriptionModel: String? = nil,
        refinedText: String? = nil,
        optimizationModel: String? = nil,
        optimizationLevel: String? = nil,
        outputStyle: String? = nil,
        teacherExplanation: String? = nil,
        audioDuration: Double? = nil,
        audioFileUrl: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.originalTranscription = originalTranscription
        self.transcriptionApi = transcriptionApi
        self.transcriptionModel = transcriptionModel
        self.refinedText = refinedText
        self.optimizationModel = optimizationModel
        self.optimizationLevel = optimizationLevel
        self.outputStyle = outputStyle
        self.teacherExplanation = teacherExplanation
        self.audioDuration = audioDuration
        self.audioFileUrl = audioFileUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Request payload for creating a new interaction
struct CreateInteractionRequest: Codable {
    let originalTranscription: String
    let transcriptionApi: String
    let transcriptionModel: String?
    let refinedText: String?
    let optimizationModel: String?
    let optimizationLevel: String?
    let outputStyle: String?
    let teacherExplanation: String?
    let audioDuration: Double?
    let audioFileUrl: String?

    enum CodingKeys: String, CodingKey {
        case originalTranscription = "original_transcription"
        case transcriptionApi = "transcription_api"
        case transcriptionModel = "transcription_model"
        case refinedText = "refined_text"
        case optimizationModel = "optimization_model"
        case optimizationLevel = "optimization_level"
        case outputStyle = "output_style"
        case teacherExplanation = "teacher_explanation"
        case audioDuration = "audio_duration"
        case audioFileUrl = "audio_file_url"
    }
}

/// Response wrapper for API responses
struct InteractionResponse: Codable {
    let interaction: InteractionRecord
}

struct InteractionsResponse: Codable {
    let interactions: [InteractionRecord]
}

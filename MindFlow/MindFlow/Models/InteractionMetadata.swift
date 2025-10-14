//
//  InteractionMetadata.swift
//  MindFlow
//
//  Helper struct for interaction metadata
//

import Foundation

/// Metadata for an interaction (STT and optimization info)
struct InteractionMetadata {
    let transcriptionApi: String
    let transcriptionModel: String?
    let optimizationModel: String?
    let optimizationLevel: String?
    let outputStyle: String?

    init(
        transcriptionApi: String,
        transcriptionModel: String? = nil,
        optimizationModel: String? = nil,
        optimizationLevel: String? = nil,
        outputStyle: String? = nil
    ) {
        self.transcriptionApi = transcriptionApi
        self.transcriptionModel = transcriptionModel
        self.optimizationModel = optimizationModel
        self.optimizationLevel = optimizationLevel
        self.outputStyle = outputStyle
    }
}

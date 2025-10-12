//
//  TranscriptionResult.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// Transcription result model
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let optimizedText: String?
    let timestamp: Date
    let duration: TimeInterval
    let audioFilePath: String?
    
    init(id: UUID = UUID(),
         originalText: String,
         optimizedText: String? = nil,
         timestamp: Date = Date(),
         duration: TimeInterval = 0,
         audioFilePath: String? = nil) {
        self.id = id
        self.originalText = originalText
        self.optimizedText = optimizedText
        self.timestamp = timestamp
        self.duration = duration
        self.audioFilePath = audioFilePath
    }
}

/// Transcription state
enum TranscriptionState {
    case idle
    case recording
    case processing
    case transcribing
    case optimizing
    case completed
    case error(String)
    
    var isProcessing: Bool {
        switch self {
        case .recording, .processing, .transcribing, .optimizing:
            return true
        default:
            return false
        }
    }
    
    var displayMessage: String {
        switch self {
        case .idle:
            return "state.ready".localized
        case .recording:
            return "state.recording".localized
        case .processing:
            return "state.processing".localized
        case .transcribing:
            return "state.transcribing".localized
        case .optimizing:
            return "state.optimizing".localized
        case .completed:
            return "state.completed".localized
        case .error(let message):
            return String(format: "state.error".localized, message)
        }
    }
}


//
//  TranscriptionResult.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// 转录结果模型
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

/// 转录状态
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
            return "准备就绪"
        case .recording:
            return "录音中..."
        case .processing:
            return "处理音频..."
        case .transcribing:
            return "转换文字中..."
        case .optimizing:
            return "优化文本中..."
        case .completed:
            return "完成"
        case .error(let message):
            return "错误: \(message)"
        }
    }
}


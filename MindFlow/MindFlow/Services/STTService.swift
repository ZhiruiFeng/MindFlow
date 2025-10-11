//
//  STTService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// 语音转文字服务
class STTService {
    static let shared = STTService()
    
    private let settings = Settings.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 转录音频文件
    func transcribe(audioURL: URL) async throws -> String {
        switch settings.sttProvider {
        case .openAI:
            return try await transcribeWithOpenAI(audioURL: audioURL)
        case .elevenLabs:
            return try await transcribeWithElevenLabs(audioURL: audioURL)
        }
    }
    
    // MARK: - OpenAI Whisper API
    
    private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
        guard !settings.openAIKey.isEmpty else {
            throw STTError.missingAPIKey("OpenAI API Key 未配置")
        }
        
        let endpoint = "https://api.openai.com/v1/audio/transcriptions"
        
        // 创建请求
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        
        // 创建 multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 添加 model 字段
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")
        
        // 添加 language 字段（可选，自动检测）
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("zh\r\n")
        
        // 添加音频文件
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")
        
        // 结束边界
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw STTError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // 解析响应
        struct WhisperResponse: Codable {
            let text: String
        }
        
        let decoder = JSONDecoder()
        let whisperResponse = try decoder.decode(WhisperResponse.self, from: data)
        
        print("✅ 转录成功: \(whisperResponse.text.prefix(50))...")
        return whisperResponse.text
    }
    
    // MARK: - ElevenLabs API
    
    private func transcribeWithElevenLabs(audioURL: URL) async throws -> String {
        guard !settings.elevenLabsKey.isEmpty else {
            throw STTError.missingAPIKey("ElevenLabs API Key 未配置")
        }
        
        // TODO: 实现 ElevenLabs API 集成
        throw STTError.notImplemented("ElevenLabs STT 尚未实现")
    }
}

// MARK: - STT Error

enum STTError: LocalizedError {
    case missingAPIKey(String)
    case invalidAudioFile
    case invalidResponse
    case apiError(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidAudioFile:
            return "无效的音频文件"
        case .invalidResponse:
            return "服务器响应无效"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


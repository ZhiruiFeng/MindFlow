//
//  LLMService.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// LLM 文本优化服务
class LLMService {
    static let shared = LLMService()

    private var settings: Settings {
        return Settings.shared
    }

    private init() {}
    
    // MARK: - Public Methods
    
    /// 优化文本
    func optimizeText(_ text: String, level: OptimizationLevel? = nil) async throws -> String {
        guard !settings.openAIKey.isEmpty else {
            throw LLMError.missingAPIKey("OpenAI API Key 未配置")
        }
        
        let optimizationLevel = level ?? settings.optimizationLevel
        let outputStyle = settings.outputStyle
        
        return try await optimizeWithOpenAI(
            text: text,
            level: optimizationLevel,
            style: outputStyle
        )
    }
    
    // MARK: - OpenAI Chat API
    
    private func optimizeWithOpenAI(
        text: String,
        level: OptimizationLevel,
        style: OutputStyle
    ) async throws -> String {
        let endpoint = "https://api.openai.com/v1/chat/completions"

        // 创建请求
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建 Prompt
        let systemPrompt = """
        \(level.systemPrompt)
        \(style.additionalPrompt)
        
        重要规则：
        1. 直接输出优化后的文本，不要添加任何解释或说明
        2. 保持原文的核心意思和关键信息
        3. 如果原文有多个句子，保持分段
        4. 添加适当的标点符号
        """
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": settings.llmModel.rawValue,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // 解析响应
        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        
        guard let optimizedText = chatResponse.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }
        
        print("✅ 文本优化成功")
        return optimizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - LLM Error

enum LLMError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case apiError(String)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "服务器响应无效"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .emptyResponse:
            return "API 返回空响应"
        }
    }
}


//
//  Settings.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// 应用设置模型
class Settings: ObservableObject {
    static let shared = Settings()
    
    // MARK: - Published Properties
    
    /// OpenAI API Key
    @Published var openAIKey: String = "" {
        didSet {
            KeychainManager.shared.save(key: "openai_api_key", value: openAIKey)
        }
    }
    
    /// ElevenLabs API Key
    @Published var elevenLabsKey: String = "" {
        didSet {
            KeychainManager.shared.save(key: "elevenlabs_api_key", value: elevenLabsKey)
        }
    }
    
    /// 选择的 STT 提供商
    @Published var sttProvider: STTProvider {
        didSet {
            UserDefaults.standard.set(sttProvider.rawValue, forKey: "stt_provider")
        }
    }
    
    /// 选择的 LLM 模型
    @Published var llmModel: LLMModel {
        didSet {
            UserDefaults.standard.set(llmModel.rawValue, forKey: "llm_model")
        }
    }
    
    /// 优化强度
    @Published var optimizationLevel: OptimizationLevel {
        didSet {
            UserDefaults.standard.set(optimizationLevel.rawValue, forKey: "optimization_level")
        }
    }
    
    /// 输出风格
    @Published var outputStyle: OutputStyle {
        didSet {
            UserDefaults.standard.set(outputStyle.rawValue, forKey: "output_style")
        }
    }
    
    /// 自动粘贴开关
    @Published var autoPaste: Bool {
        didSet {
            UserDefaults.standard.set(autoPaste, forKey: "auto_paste")
        }
    }
    
    /// 登录时启动
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launch_at_login")
        }
    }
    
    /// 显示通知
    @Published var showNotifications: Bool {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: "show_notifications")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 从 Keychain 加载 API Keys
        self.openAIKey = KeychainManager.shared.get(key: "openai_api_key") ?? ""
        self.elevenLabsKey = KeychainManager.shared.get(key: "elevenlabs_api_key") ?? ""
        
        // 从 UserDefaults 加载设置
        let sttProviderRaw = UserDefaults.standard.string(forKey: "stt_provider") ?? STTProvider.openAI.rawValue
        self.sttProvider = STTProvider(rawValue: sttProviderRaw) ?? .openAI
        
        let llmModelRaw = UserDefaults.standard.string(forKey: "llm_model") ?? LLMModel.gpt4oMini.rawValue
        self.llmModel = LLMModel(rawValue: llmModelRaw) ?? .gpt4oMini
        
        let optimizationLevelRaw = UserDefaults.standard.string(forKey: "optimization_level") ?? OptimizationLevel.medium.rawValue
        self.optimizationLevel = OptimizationLevel(rawValue: optimizationLevelRaw) ?? .medium
        
        let outputStyleRaw = UserDefaults.standard.string(forKey: "output_style") ?? OutputStyle.conversational.rawValue
        self.outputStyle = OutputStyle(rawValue: outputStyleRaw) ?? .conversational
        
        self.autoPaste = UserDefaults.standard.bool(forKey: "auto_paste")
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launch_at_login")
        self.showNotifications = UserDefaults.standard.bool(forKey: "show_notifications")
    }
    
    // MARK: - Helper Methods
    
    /// 验证 OpenAI API Key 是否有效
    func validateOpenAIKey() async -> Bool {
        guard !openAIKey.isEmpty else { return false }
        // TODO: 实际调用 API 验证
        return true
    }
    
    /// 验证 ElevenLabs API Key 是否有效
    func validateElevenLabsKey() async -> Bool {
        guard !elevenLabsKey.isEmpty else { return false }
        // TODO: 实际调用 API 验证
        return true
    }
}

// MARK: - Enums

/// STT 服务提供商
enum STTProvider: String, CaseIterable {
    case openAI = "OpenAI"
    case elevenLabs = "ElevenLabs"
    
    var displayName: String {
        return self.rawValue
    }
}

/// LLM 模型
enum LLMModel: String, CaseIterable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case gpt4 = "gpt-4"
    
    var displayName: String {
        switch self {
        case .gpt4oMini: return "GPT-4o Mini (推荐)"
        case .gpt4o: return "GPT-4o"
        case .gpt4: return "GPT-4"
        }
    }
}

/// 优化强度
enum OptimizationLevel: String, CaseIterable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    
    var displayName: String {
        switch self {
        case .light: return "轻度"
        case .medium: return "中度"
        case .heavy: return "重度"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .light:
            return "你是一个文本编辑助手。请去除以下文本中明显的填充词（如'嗯'、'啊'、'那个'、'这个'、'就是'等），但保留口语化的表达风格。保持原意不变。"
        case .medium:
            return "你是一个专业的文本编辑助手。请去除以下文本中的填充词（如'嗯'、'啊'、'那个'、'这个'、'就是'等），修正语法错误，优化句子结构，使其更加流畅易读。保持原意不变。"
        case .heavy:
            return "你是一个专业的文本编辑助手。请深度优化以下文本：1) 去除所有填充词和冗余表达；2) 修正语法错误；3) 重组句子结构；4) 转换为书面化表达；5) 确保逻辑清晰。保持原意不变。"
        }
    }
}

/// 输出风格
enum OutputStyle: String, CaseIterable {
    case conversational = "conversational"
    case formal = "formal"
    
    var displayName: String {
        switch self {
        case .conversational: return "口语化"
        case .formal: return "书面化"
        }
    }
    
    var additionalPrompt: String {
        switch self {
        case .conversational: return "保持轻松的对话风格。"
        case .formal: return "使用正式的书面语风格。"
        }
    }
}


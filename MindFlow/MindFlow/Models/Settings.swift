//
//  Settings.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation

/// Application settings model
class Settings: ObservableObject {
    static let shared = Settings()
    
    // MARK: - Published Properties
    
    /// OpenAI API Key
    @Published var openAIKey: String = "" {
        didSet {
            // Trim whitespace and newlines from the API key
            let trimmedKey = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            KeychainManager.shared.save(key: "openai_api_key", value: trimmedKey)
        }
    }
    
    /// ElevenLabs API Key
    @Published var elevenLabsKey: String = "" {
        didSet {
            KeychainManager.shared.save(key: "elevenlabs_api_key", value: elevenLabsKey)
        }
    }
    
    /// Selected STT provider
    @Published var sttProvider: STTProvider {
        didSet {
            UserDefaults.standard.set(sttProvider.rawValue, forKey: "stt_provider")
        }
    }
    
    /// Selected LLM model
    @Published var llmModel: LLMModel {
        didSet {
            UserDefaults.standard.set(llmModel.rawValue, forKey: "llm_model")
        }
    }
    
    /// Optimization intensity level
    @Published var optimizationLevel: OptimizationLevel {
        didSet {
            UserDefaults.standard.set(optimizationLevel.rawValue, forKey: "optimization_level")
        }
    }
    
    /// Output style
    @Published var outputStyle: OutputStyle {
        didSet {
            UserDefaults.standard.set(outputStyle.rawValue, forKey: "output_style")
        }
    }
    
    /// Auto-paste toggle
    @Published var autoPaste: Bool {
        didSet {
            UserDefaults.standard.set(autoPaste, forKey: "auto_paste")
        }
    }
    
    /// Launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launch_at_login")
        }
    }
    
    /// Show notifications
    @Published var showNotifications: Bool {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: "show_notifications")
        }
    }

    /// Enable teacher explanations for expression improvements
    @Published var enableTeacherNotes: Bool {
        didSet {
            UserDefaults.standard.set(enableTeacherNotes, forKey: "enable_teacher_notes")
        }
    }

    /// App language preference
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "app_language")
            LocalizationManager.shared.setLanguage(appLanguage)
        }
    }

    /// Whether user has completed initial login flow (can be skipped)
    @Published var hasCompletedLoginFlow: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedLoginFlow, forKey: "has_completed_login_flow")
        }
    }

    // MARK: - Backend Sync Settings

    /// Automatically sync interactions to ZephyrOS backend
    @Published var autoSyncToBackend: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncToBackend, forKey: "auto_sync_to_backend")
        }
    }

    /// Minimum audio duration (in seconds) to trigger auto-sync
    @Published var autoSyncThreshold: Double {
        didSet {
            UserDefaults.standard.set(autoSyncThreshold, forKey: "auto_sync_threshold")
        }
    }

    // MARK: - Initialization
    
    private init() {
        // Load API Keys from Keychain
        self.openAIKey = (KeychainManager.shared.get(key: "openai_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.elevenLabsKey = (KeychainManager.shared.get(key: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Load settings from UserDefaults
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
        self.enableTeacherNotes = UserDefaults.standard.bool(forKey: "enable_teacher_notes")

        // Load language preference
        let languageRaw = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        self.appLanguage = AppLanguage(rawValue: languageRaw) ?? .system

        // Load login flow completion status
        self.hasCompletedLoginFlow = UserDefaults.standard.bool(forKey: "has_completed_login_flow")

        // Load backend sync settings (with defaults)
        // Default: auto-sync enabled with 30 second threshold
        if UserDefaults.standard.object(forKey: "auto_sync_to_backend") == nil {
            UserDefaults.standard.set(true, forKey: "auto_sync_to_backend")
        }
        self.autoSyncToBackend = UserDefaults.standard.bool(forKey: "auto_sync_to_backend")

        self.autoSyncThreshold = UserDefaults.standard.double(forKey: "auto_sync_threshold")
        if self.autoSyncThreshold == 0 {
            // Default to 30 seconds if not set
            self.autoSyncThreshold = 30.0
            UserDefaults.standard.set(30.0, forKey: "auto_sync_threshold")
        }

        // Apply language setting (after all properties are initialized)
        LocalizationManager.shared.setLanguage(self.appLanguage)
    }
    
    // MARK: - Helper Methods
    
    /// Validate if OpenAI API Key is valid
    func validateOpenAIKey() async -> Bool {
        guard !openAIKey.isEmpty else { return false }
        // TODO: Actually call API for validation
        return true
    }

    /// Validate if ElevenLabs API Key is valid
    func validateElevenLabsKey() async -> Bool {
        guard !elevenLabsKey.isEmpty else { return false }
        // TODO: Actually call API for validation
        return true
    }
}

// MARK: - Enums

/// STT service provider
enum STTProvider: String, CaseIterable {
    case openAI = "OpenAI"
    case elevenLabs = "ElevenLabs"
    
    var displayName: String {
        return self.rawValue
    }
}

/// LLM model
enum LLMModel: String, CaseIterable {
    case gpt4oMini = "gpt-4o-mini"
    case gpt4o = "gpt-4o"
    case gpt4 = "gpt-4"
    
    var displayName: String {
        switch self {
        case .gpt4oMini: return "enum.llm.gpt4o_mini".localized
        case .gpt4o: return "enum.llm.gpt4o".localized
        case .gpt4: return "enum.llm.gpt4".localized
        }
    }
}

/// Optimization intensity level
enum OptimizationLevel: String, CaseIterable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    
    var displayName: String {
        switch self {
        case .light: return "enum.optimization.light".localized
        case .medium: return "enum.optimization.medium".localized
        case .heavy: return "enum.optimization.heavy".localized
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

/// Output style
enum OutputStyle: String, CaseIterable {
    case conversational = "conversational"
    case formal = "formal"

    var displayName: String {
        switch self {
        case .conversational: return "enum.style.conversational".localized
        case .formal: return "enum.style.formal".localized
        }
    }

    var additionalPrompt: String {
        switch self {
        case .conversational: return "Keep a casual conversational style."
        case .formal: return "Use formal written language style."
        }
    }
}

/// App language preference
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: return "enum.language.system".localized
        case .english: return "enum.language.english".localized
        case .chinese: return "enum.language.chinese".localized
        }
    }

    var languageCode: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }
}


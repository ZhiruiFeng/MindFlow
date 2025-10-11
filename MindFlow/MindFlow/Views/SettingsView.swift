//
//  SettingsView.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    @State private var openAIKeyInput: String = ""
    @State private var elevenLabsKeyInput: String = ""
    @State private var isValidatingOpenAI = false
    @State private var isValidatingElevenLabs = false
    @State private var openAIValidationStatus: ValidationStatus = .none
    @State private var elevenLabsValidationStatus: ValidationStatus = .none
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题
                Text("⚙️ MindFlow 设置")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 8)
                
                // API 配置部分
                GroupBox(label: Label("API 配置", systemImage: "key.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // STT 提供商选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STT 提供商")
                                .font(.headline)
                            Picker("", selection: $settings.sttProvider) {
                                ForEach(STTProvider.allCases, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Divider()
                        
                        // OpenAI API Key
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API Key")
                                .font(.headline)
                            HStack {
                                SecureField("输入你的 OpenAI API Key", text: $openAIKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .onAppear {
                                        openAIKeyInput = settings.openAIKey
                                    }
                                
                                Button(action: {
                                    settings.openAIKey = openAIKeyInput
                                    validateOpenAIKey()
                                }) {
                                    if isValidatingOpenAI {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 60)
                                    } else {
                                        Text("保存")
                                            .frame(width: 60)
                                    }
                                }
                                .disabled(openAIKeyInput.isEmpty || isValidatingOpenAI)
                            }
                            
                            // 验证状态
                            if openAIValidationStatus != .none {
                                HStack {
                                    Image(systemName: openAIValidationStatus.icon)
                                        .foregroundColor(openAIValidationStatus.color)
                                    Text(openAIValidationStatus.message)
                                        .font(.caption)
                                        .foregroundColor(openAIValidationStatus.color)
                                }
                            }
                            
                            Text("用于语音转文字 (Whisper) 和文本优化 (GPT)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // ElevenLabs API Key
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ElevenLabs API Key (可选)")
                                .font(.headline)
                            HStack {
                                SecureField("输入你的 ElevenLabs API Key", text: $elevenLabsKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .onAppear {
                                        elevenLabsKeyInput = settings.elevenLabsKey
                                    }
                                
                                Button(action: {
                                    settings.elevenLabsKey = elevenLabsKeyInput
                                    validateElevenLabsKey()
                                }) {
                                    if isValidatingElevenLabs {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 60)
                                    } else {
                                        Text("保存")
                                            .frame(width: 60)
                                    }
                                }
                                .disabled(elevenLabsKeyInput.isEmpty || isValidatingElevenLabs)
                            }
                            
                            // 验证状态
                            if elevenLabsValidationStatus != .none {
                                HStack {
                                    Image(systemName: elevenLabsValidationStatus.icon)
                                        .foregroundColor(elevenLabsValidationStatus.color)
                                    Text(elevenLabsValidationStatus.message)
                                        .font(.caption)
                                        .foregroundColor(elevenLabsValidationStatus.color)
                                }
                            }
                            
                            Text("备用 STT 服务")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // LLM 配置
                GroupBox(label: Label("LLM 配置", systemImage: "brain.head.profile")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("模型选择")
                                .font(.headline)
                            Picker("", selection: $settings.llmModel) {
                                ForEach(LLMModel.allCases, id: \.self) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                    .padding()
                }
                
                // 权限状态
                GroupBox(label: Label("权限状态", systemImage: "lock.shield")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 麦克风权限
                        HStack {
                            Image(systemName: permissionManager.microphonePermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permissionManager.microphonePermissionGranted ? .green : .red)
                            Text("麦克风权限")
                            Spacer()
                            if !permissionManager.microphonePermissionGranted {
                                Button("请求权限") {
                                    Task {
                                        await permissionManager.requestMicrophonePermission()
                                    }
                                }
                            }
                        }
                        
                        // 辅助功能权限
                        HStack {
                            Image(systemName: permissionManager.accessibilityPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permissionManager.accessibilityPermissionGranted ? .green : .orange)
                            Text("辅助功能权限")
                            Spacer()
                            if !permissionManager.accessibilityPermissionGranted {
                                Button("打开设置") {
                                    permissionManager.requestAccessibilityPermission()
                                }
                            }
                        }
                        
                        if !permissionManager.accessibilityPermissionGranted {
                            Text("辅助功能权限用于全局热键和自动粘贴。如不授予，可手动复制文本。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                // 快捷键设置
                GroupBox(label: Label("快捷键", systemImage: "command")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("全局触发")
                            Spacer()
                            Text("⌘ Shift V")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(6)
                        }
                        Text("在任何应用中按此快捷键即可开始录音")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // 行为设置
                GroupBox(label: Label("行为", systemImage: "gearshape.2")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("处理完成后自动粘贴", isOn: $settings.autoPaste)
                        Toggle("登录时启动", isOn: $settings.launchAtLogin)
                        Toggle("显示桌面通知", isOn: $settings.showNotifications)
                    }
                    .padding()
                }
                
                // 默认优化设置
                GroupBox(label: Label("默认优化", systemImage: "wand.and.stars")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("优化强度")
                                .font(.headline)
                            Picker("", selection: $settings.optimizationLevel) {
                                ForEach(OptimizationLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输出风格")
                                .font(.headline)
                            Picker("", selection: $settings.outputStyle) {
                                ForEach(OutputStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding(24)
        }
        .frame(width: 600, height: 700)
    }
    
    // MARK: - Helper Methods
    
    private func validateOpenAIKey() {
        isValidatingOpenAI = true
        openAIValidationStatus = .validating
        
        Task {
            let isValid = await settings.validateOpenAIKey()
            await MainActor.run {
                isValidatingOpenAI = false
                openAIValidationStatus = isValid ? .valid : .invalid
            }
        }
    }
    
    private func validateElevenLabsKey() {
        isValidatingElevenLabs = true
        elevenLabsValidationStatus = .validating
        
        Task {
            let isValid = await settings.validateElevenLabsKey()
            await MainActor.run {
                isValidatingElevenLabs = false
                elevenLabsValidationStatus = isValid ? .valid : .invalid
            }
        }
    }
}

// MARK: - Validation Status

enum ValidationStatus {
    case none
    case validating
    case valid
    case invalid
    
    var icon: String {
        switch self {
        case .none: return ""
        case .validating: return "arrow.clockwise"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .primary
        case .validating: return .blue
        case .valid: return .green
        case .invalid: return .red
        }
    }
    
    var message: String {
        switch self {
        case .none: return ""
        case .validating: return "验证中..."
        case .valid: return "✓ 已保存"
        case .invalid: return "✗ 无效"
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}


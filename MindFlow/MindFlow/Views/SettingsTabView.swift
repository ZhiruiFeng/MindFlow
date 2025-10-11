//
//  SettingsTabView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// 设置页面 Tab 内容
///
/// 提供 API 配置、权限管理、行为设置等功能
struct SettingsTabView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var permissionManager = PermissionManager.shared

    @State private var openAIKeyInput: String = Settings.shared.openAIKey
    @State private var elevenLabsKeyInput: String = Settings.shared.elevenLabsKey
    @State private var isValidatingOpenAI = false
    @State private var isValidatingElevenLabs = false
    @State private var openAIValidationStatus: ValidationStatus = .none
    @State private var elevenLabsValidationStatus: ValidationStatus = .none

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                apiConfigurationSection
                llmConfigurationSection
                permissionsSection
                hotKeySection
                behaviorSection
                optimizationSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var apiConfigurationSection: some View {
        GroupBox(label: Label("API 配置", systemImage: "key.fill")) {
            VStack(alignment: .leading, spacing: 16) {
                sttProviderPicker
                Divider()
                openAIKeyField
                Divider()
                elevenLabsKeyField
            }
            .padding()
        }
    }

    private var llmConfigurationSection: some View {
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
    }

    private var permissionsSection: some View {
        GroupBox(label: Label("权限状态", systemImage: "lock.shield")) {
            VStack(alignment: .leading, spacing: 12) {
                microphonePermissionRow
                accessibilityPermissionRow

                if !permissionManager.isAccessibilityPermissionGranted {
                    Text("辅助功能权限用于全局热键和自动粘贴。如不授予，可手动复制文本。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    private var hotKeySection: some View {
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
    }

    private var behaviorSection: some View {
        GroupBox(label: Label("行为", systemImage: "gearshape.2")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("处理完成后自动粘贴", isOn: $settings.autoPaste)
                Toggle("登录时启动", isOn: $settings.launchAtLogin)
                Toggle("显示桌面通知", isOn: $settings.showNotifications)
            }
            .padding()
        }
    }

    private var optimizationSection: some View {
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
    }

    // MARK: - API Key Components

    private var sttProviderPicker: some View {
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
    }

    private var openAIKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenAI API Key")
                .font(.headline)
            HStack {
                SecureField("输入你的 OpenAI API Key", text: $openAIKeyInput)
                    .textFieldStyle(.roundedBorder)

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
    }

    private var elevenLabsKeyField: some View {
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

    // MARK: - Permission Components

    private var microphonePermissionRow: some View {
        HStack {
            Image(systemName: permissionManager.isMicrophonePermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(permissionManager.isMicrophonePermissionGranted ? .green : .red)
            Text("麦克风权限")
            Spacer()
            if !permissionManager.isMicrophonePermissionGranted {
                Button("请求权限") {
                    Task {
                        await permissionManager.requestMicrophonePermission()
                    }
                }
            }
        }
    }

    private var accessibilityPermissionRow: some View {
        HStack {
            Image(systemName: permissionManager.isAccessibilityPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(permissionManager.isAccessibilityPermissionGranted ? .green : .orange)
            Text("辅助功能权限")
            Spacer()
            if !permissionManager.isAccessibilityPermissionGranted {
                Button("打开设置") {
                    permissionManager.requestAccessibilityPermission()
                }
            }
        }
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

// MARK: - Preview

struct SettingsTabView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTabView()
    }
}

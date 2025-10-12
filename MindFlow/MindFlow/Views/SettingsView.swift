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

    @State private var openAIKeyInput: String = Settings.shared.openAIKey
    @State private var elevenLabsKeyInput: String = Settings.shared.elevenLabsKey
    @State private var isValidatingOpenAI = false
    @State private var isValidatingElevenLabs = false
    @State private var openAIValidationStatus: ValidationStatus = .none
    @State private var elevenLabsValidationStatus: ValidationStatus = .none
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("settings.title".localized)
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 8)

                // API Configuration section
                GroupBox(label: Label("settings.api_config".localized, systemImage: "key.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // STT Provider selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.stt_provider".localized)
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
                                SecureField("settings.openai_placeholder".localized, text: $openAIKeyInput)
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
                                        Text("settings.save".localized)
                                            .frame(width: 60)
                                    }
                                }
                                .disabled(openAIKeyInput.isEmpty || isValidatingOpenAI)
                            }

                            // Validation status
                            if openAIValidationStatus != .none {
                                HStack {
                                    Image(systemName: openAIValidationStatus.icon)
                                        .foregroundColor(openAIValidationStatus.color)
                                    Text(openAIValidationStatus.message)
                                        .font(.caption)
                                        .foregroundColor(openAIValidationStatus.color)
                                }
                            }

                            Text("settings.openai_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // ElevenLabs API Key
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.elevenlabs_key".localized)
                                .font(.headline)
                            HStack {
                                SecureField("settings.elevenlabs_placeholder".localized, text: $elevenLabsKeyInput)
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
                                        Text("settings.save".localized)
                                            .frame(width: 60)
                                    }
                                }
                                .disabled(elevenLabsKeyInput.isEmpty || isValidatingElevenLabs)
                            }

                            // Validation status
                            if elevenLabsValidationStatus != .none {
                                HStack {
                                    Image(systemName: elevenLabsValidationStatus.icon)
                                        .foregroundColor(elevenLabsValidationStatus.color)
                                    Text(elevenLabsValidationStatus.message)
                                        .font(.caption)
                                        .foregroundColor(elevenLabsValidationStatus.color)
                                }
                            }

                            Text("settings.elevenlabs_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // LLM Configuration
                GroupBox(label: Label("settings.llm_config".localized, systemImage: "brain.head.profile")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.model_selection".localized)
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

                // Permission Status
                GroupBox(label: Label("settings.permissions".localized, systemImage: "lock.shield")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Microphone permission
                        HStack {
                            Image(systemName: permissionManager.isMicrophonePermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permissionManager.isMicrophonePermissionGranted ? .green : .red)
                            Text("settings.microphone_permission".localized)
                            Spacer()
                            if !permissionManager.isMicrophonePermissionGranted {
                                Button("settings.request_permission".localized) {
                                    Task {
                                        await permissionManager.requestMicrophonePermission()
                                    }
                                }
                            }
                        }

                        // Accessibility permission
                        HStack {
                            Image(systemName: permissionManager.isAccessibilityPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permissionManager.isAccessibilityPermissionGranted ? .green : .orange)
                            Text("settings.accessibility_permission".localized)
                            Spacer()
                            if !permissionManager.isAccessibilityPermissionGranted {
                                Button("settings.open_settings".localized) {
                                    permissionManager.requestAccessibilityPermission()
                                }
                            }
                        }

                        if !permissionManager.isAccessibilityPermissionGranted {
                            Text("settings.accessibility_note".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // Hotkey settings
                GroupBox(label: Label("settings.hotkey".localized, systemImage: "command")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("settings.global_trigger".localized)
                            Spacer()
                            Text("⌘ Shift V")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(6)
                        }
                        Text("settings.hotkey_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Behavior settings
                GroupBox(label: Label("settings.behavior".localized, systemImage: "gearshape.2")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("settings.auto_paste".localized, isOn: $settings.autoPaste)
                        Toggle("settings.launch_at_login".localized, isOn: $settings.launchAtLogin)
                        Toggle("settings.show_notifications".localized, isOn: $settings.showNotifications)
                    }
                    .padding()
                }

                // Default optimization settings
                GroupBox(label: Label("settings.optimization".localized, systemImage: "wand.and.stars")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("settings.optimization_intensity".localized)
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
                            Text("settings.output_style".localized)
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
        case .validating: return "settings.validating".localized
        case .valid: return "settings.valid".localized
        case .invalid: return "settings.invalid".localized
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}


//
//  PreviewView.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

struct PreviewView: View {
    let result: TranscriptionResult?
    
    @ObservedObject private var settings = Settings.shared
    @State private var selectedOptimizationLevel: OptimizationLevel
    @State private var isReoptimizing = false
    @State private var currentOptimizedText: String
    @State private var showCopiedAlert = false
    @State private var showPastedAlert = false
    
    init(result: TranscriptionResult?) {
        self.result = result
        _selectedOptimizationLevel = State(initialValue: Settings.shared.optimizationLevel)
        _currentOptimizedText = State(initialValue: result?.optimizedText ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("文本预览")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 原始文本
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原始文本：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: .constant(result?.originalText ?? ""))
                            .frame(height: 80)
                            .font(.body)
                            .disabled(true)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // 优化后的文本
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("优化后：")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if isReoptimizing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        if currentOptimizedText.isEmpty {
                            Text("未进行优化")
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(height: 80)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            TextEditor(text: $currentOptimizedText)
                                .frame(height: 80)
                                .font(.body)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 优化级别选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("优化级别：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedOptimizationLevel) {
                            ForEach(OptimizationLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedOptimizationLevel) { _ in
                            // 当级别改变时，提示用户重新优化
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 复制按钮
                Button(action: {
                    copyToClipboard()
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // 重新优化按钮
                Button(action: {
                    reoptimize()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("重新优化")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isReoptimizing || result?.originalText.isEmpty == true)
                
                // 粘贴按钮
                Button(action: {
                    pasteText()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("粘贴")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // 提示信息
            if showCopiedAlert {
                Text("✓ 已复制到剪贴板")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            if showPastedAlert {
                Text("✓ 已粘贴到活动窗口")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        let textToCopy = currentOptimizedText.isEmpty ? (result?.originalText ?? "") : currentOptimizedText
        ClipboardManager.shared.copy(text: textToCopy)
        
        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }
    }
    
    private func reoptimize() {
        guard let originalText = result?.originalText, !originalText.isEmpty else { return }
        
        isReoptimizing = true
        
        Task {
            do {
                let optimizedText = try await LLMService.shared.optimizeText(
                    originalText,
                    level: selectedOptimizationLevel
                )
                
                await MainActor.run {
                    self.currentOptimizedText = optimizedText
                    self.isReoptimizing = false
                }
            } catch {
                await MainActor.run {
                    self.isReoptimizing = false
                    // TODO: 显示错误提示
                }
            }
        }
    }
    
    private func pasteText() {
        let textToPaste = currentOptimizedText.isEmpty ? (result?.originalText ?? "") : currentOptimizedText
        
        // 先复制到剪贴板
        ClipboardManager.shared.copy(text: textToPaste)
        
        // 如果有辅助功能权限，自动粘贴
        if PermissionManager.shared.accessibilityPermissionGranted {
            ClipboardManager.shared.paste()
            
            showPastedAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showPastedAlert = false
            }
            
            // 自动粘贴后，延迟关闭窗口
            if settings.autoPaste {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApplication.shared.keyWindow?.close()
                }
            }
        } else {
            // 没有权限，提示用户手动粘贴
            showCopiedAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopiedAlert = false
            }
        }
    }
}

// MARK: - Preview

struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView(result: TranscriptionResult(
            originalText: "嗯，那个，我想说的是，就是这个项目嗯需要在下周完成",
            optimizedText: "我想说的是，这个项目需要在下周完成。",
            duration: 5.5
        ))
    }
}


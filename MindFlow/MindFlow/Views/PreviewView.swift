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
            // Title
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("preview.title".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("preview.original".localized)
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

                    // Optimized text
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("preview.optimized".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if isReoptimizing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        if currentOptimizedText.isEmpty {
                            Text("preview.no_optimization".localized)
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
                    
                    // Teacher's Note (if available)
                    if let teacherNote = result?.teacherExplanation, !teacherNote.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Teacher's Note")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Text(teacherNote)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    // Optimization level selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("preview.optimization_level".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedOptimizationLevel) {
                            ForEach(OptimizationLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedOptimizationLevel) { _ in
                            // Prompt user to re-optimize when level changes
                        }
                    }
                }
                .padding()
            }
            
            Divider()

            // Action buttons
            HStack(spacing: 12) {
                // Copy button
                Button(action: {
                    copyToClipboard()
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("preview.copy".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Re-optimize button
                Button(action: {
                    reoptimize()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("preview.reoptimize".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isReoptimizing || result?.originalText.isEmpty == true)

                // Paste button
                Button(action: {
                    pasteText()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("preview.paste".localized)
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

            // Alert messages
            if showCopiedAlert {
                Text("preview.copied".localized)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            if showPastedAlert {
                Text("preview.pasted".localized)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        // Only copy refined text (not original)
        guard !currentOptimizedText.isEmpty else {
            // If no optimized text, don't copy anything
            return
        }

        ClipboardManager.shared.copy(text: currentOptimizedText)

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
                    // TODO: Show error message
                }
            }
        }
    }
    
    private func pasteText() {
        // Only paste refined text (not original)
        guard !currentOptimizedText.isEmpty else {
            // If no optimized text, don't paste anything
            return
        }

        // Copy to clipboard first
        ClipboardManager.shared.copy(text: currentOptimizedText)

        // Auto-paste if accessibility permission is granted
        if PermissionManager.shared.isAccessibilityPermissionGranted {
            ClipboardManager.shared.paste()

            showPastedAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showPastedAlert = false
            }

            // Close window after auto-paste with delay
            if settings.autoPaste {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApplication.shared.keyWindow?.close()
                }
            }
        } else {
            // No permission, prompt user to paste manually
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


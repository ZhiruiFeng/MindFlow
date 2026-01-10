//
//  PreviewView.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

struct PreviewView: View {
    @Binding var result: TranscriptionResult?
    let viewModel: RecordingViewModel

    @ObservedObject private var settings = Settings.shared
    @State private var selectedOptimizationLevel: OptimizationLevel
    @State private var isReoptimizing = false
    @State private var currentOptimizedText: String
    @State private var showCopiedAlert = false
    @State private var showPastedAlert = false
    @State private var expandedSuggestion: VocabularySuggestion? = nil

    init(result: Binding<TranscriptionResult?>, viewModel: RecordingViewModel) {
        self._result = result
        self.viewModel = viewModel
        _selectedOptimizationLevel = State(initialValue: Settings.shared.optimizationLevel)
        _currentOptimizedText = State(initialValue: result.wrappedValue?.optimizedText ?? "")
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
                    // Original text (with vocabulary lookup support)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("preview.original".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Right-click word to add to vocabulary")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        TranscriptionTextView(text: result?.originalText ?? "")
                            .frame(height: 80)
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

                                // Extract and display score if present
                                if let score = extractScore(from: teacherNote) {
                                    Text(score)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.orange)
                                }
                            }

                            FormattedTeacherNoteView(text: teacherNote)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    // Vocabulary Suggestions (if available)
                    if let suggestions = result?.vocabularySuggestions, !suggestions.isEmpty {
                        Divider()

                        VocabularySuggestionsSection(
                            suggestions: suggestions,
                            onAdd: { suggestion in
                                Task {
                                    await viewModel.addSuggestionToVocabulary(suggestion)
                                }
                            },
                            onExpand: { suggestion in
                                expandedSuggestion = suggestion
                            }
                        )
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
        .sheet(item: $expandedSuggestion) { suggestion in
            VocabularySuggestionDetailView(
                suggestion: suggestion,
                onAdd: {
                    Task {
                        await viewModel.addSuggestionToVocabulary(suggestion)
                    }
                },
                onClose: {
                    expandedSuggestion = nil
                }
            )
            .frame(width: 320, height: 380)
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

    private func extractScore(from text: String) -> String? {
        // Extract "Score: X/10" pattern
        let pattern = #"Score:\s*(\d+/10)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let scoreRange = Range(match.range(at: 1), in: text) {
            return String(text[scoreRange])
        }
        return nil
    }
}

// MARK: - Formatted Teacher Note View

struct FormattedTeacherNoteView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = text.components(separatedBy: .newlines)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.contains("Score:") {
                    if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                        // Bullet point
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.body)
                                .foregroundColor(.orange)
                            Text(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else if trimmed.hasSuffix(":") {
                        // Section header
                        Text(trimmed)
                            .font(.body)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                    } else {
                        // Regular text
                        Text(trimmed)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct PreviewView_Previews: PreviewProvider {
    @State static var mockResult: TranscriptionResult? = TranscriptionResult(
        originalText: "嗯，那个，我想说的是，就是这个项目嗯需要在下周完成",
        optimizedText: "我想说的是，这个项目需要在下周完成。",
        duration: 5.5,
        vocabularySuggestions: [
            VocabularySuggestion(
                word: "eloquent",
                partOfSpeech: "adjective",
                definition: "Fluent or persuasive in speaking or writing.",
                reason: "More expressive alternative to 'well-spoken'.",
                sourceSentence: "She gave an eloquent presentation."
            )
        ]
    )

    static var previews: some View {
        PreviewView(result: $mockResult, viewModel: RecordingViewModel())
    }
}


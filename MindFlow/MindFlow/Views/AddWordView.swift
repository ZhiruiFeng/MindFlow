//
//  AddWordView.swift
//  MindFlow
//
//  Modal view for adding a new word to vocabulary
//

import SwiftUI

/// Modal view for adding a new vocabulary word
struct AddWordView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var word: String = ""
    @State private var context: String = ""
    @State private var category: String = ""
    @State private var useManualEntry: Bool = false
    @State private var manualDefinitionEN: String = ""
    @State private var manualDefinitionCN: String = ""
    @State private var showingDuplicateAlert: Bool = false

    private var isWordValid: Bool {
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    wordInputSection
                    contextSection
                    categorySection

                    if useManualEntry {
                        manualEntrySection
                    }

                    // Lookup result preview
                    if let result = viewModel.lastLookupResult {
                        lookupResultPreview(result)
                    }

                    // Error display
                    if let error = viewModel.error {
                        errorView(error)
                    }
                }
                .padding()
            }

            Divider()

            // Footer with buttons
            footer
        }
        .frame(width: 500, height: 600)
        .alert("Word Already Exists", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("'\(word)' is already in your vocabulary.")
        }
        .onAppear {
            viewModel.lastLookupResult = nil
            viewModel.clearError()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Add New Word")
                .font(.headline)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Word Input Section

    private var wordInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Word")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("Enter a word to look up", text: $word)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if isWordValid && !useManualEntry {
                            lookupWord()
                        }
                    }

                if viewModel.isLoading && viewModel.lookingUpWord != nil {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Toggle("Enter manually (offline mode)", isOn: $useManualEntry)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("Where did you encounter this word?", text: $context, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Text("Adding context helps the AI provide more relevant explanations")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("e.g., Work, Daily, Academic", text: $category)
                    .textFieldStyle(.roundedBorder)

                if !viewModel.categories.isEmpty {
                    Menu {
                        ForEach(viewModel.categories, id: \.self) { existingCategory in
                            Button(existingCategory) {
                                category = existingCategory
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                }
            }
        }
    }

    // MARK: - Manual Entry Section

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("Manual Entry")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                Text("English Definition")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Enter the English definition", text: $manualDefinitionEN, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Chinese Definition")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("输入中文释义", text: $manualDefinitionCN, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }

    // MARK: - Lookup Result Preview

    @ViewBuilder
    private func lookupResultPreview(_ result: WordExplanation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.word)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let phonetic = result.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let partOfSpeech = result.partOfSpeech {
                    Text(partOfSpeech)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                if let defEN = result.definitionEN {
                    Text(defEN)
                        .font(.body)
                }

                if let defCN = result.definitionCN {
                    Text(defCN)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Dismiss") {
                    viewModel.clearError()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !useManualEntry {
                Text("You can switch to manual entry mode to add this word offline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Spacer()

            if useManualEntry {
                Button("Add Word") {
                    addWordManually()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isWordValid)
            } else {
                if viewModel.lastLookupResult != nil {
                    Button("Add to Vocabulary") {
                        saveWord()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Look Up") {
                        lookupWord()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isWordValid || viewModel.isLoading)
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func lookupWord() {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check for duplicate
        if VocabularyStorage.shared.wordExists(trimmedWord) {
            showingDuplicateAlert = true
            return
        }

        Task {
            await viewModel.lookupAndAddWord(
                trimmedWord,
                context: context.isEmpty ? nil : context,
                category: category.isEmpty ? nil : category
            )

            // If successful, the word is already added, so dismiss
            if viewModel.error == nil {
                NotificationCenter.default.post(name: .vocabularyWordAdded, object: nil)
                dismiss()
            }
        }
    }

    private func saveWord() {
        // Word was already looked up and saved in lookupAndAddWord
        NotificationCenter.default.post(name: .vocabularyWordAdded, object: nil)
        dismiss()
    }

    private func addWordManually() {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check for duplicate
        if VocabularyStorage.shared.wordExists(trimmedWord) {
            showingDuplicateAlert = true
            return
        }

        Task {
            await viewModel.addWordManually(
                trimmedWord,
                definitionEN: manualDefinitionEN.isEmpty ? nil : manualDefinitionEN,
                definitionCN: manualDefinitionCN.isEmpty ? nil : manualDefinitionCN,
                context: context.isEmpty ? nil : context,
                category: category.isEmpty ? nil : category
            )

            if viewModel.error == nil {
                NotificationCenter.default.post(name: .vocabularyWordAdded, object: nil)
                dismiss()
            }
        }
    }
}

// MARK: - Preview

struct AddWordView_Previews: PreviewProvider {
    static var previews: some View {
        AddWordView(viewModel: VocabularyViewModel())
    }
}

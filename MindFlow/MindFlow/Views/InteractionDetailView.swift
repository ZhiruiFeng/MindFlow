//
//  InteractionDetailView.swift
//  MindFlow
//
//  A comprehensive detail page for a single interaction record.
//
//  Both the local store (`LocalInteraction`) and the remote store
//  (`InteractionRecord`) hold the same comprehensive set of fields — original
//  transcription, refined text, teacher's note, and the optimization metadata.
//  This view normalizes either source into `InteractionDetail` so the same
//  detail page can present a local or a synced record.
//

import SwiftUI

// MARK: - Normalized Detail Model

/// A source-agnostic snapshot of an interaction, suitable for presenting in a
/// detail page regardless of whether it originated locally or from the backend.
struct InteractionDetail: Identifiable {
    enum Source {
        case local
        case remote
    }

    let id: UUID
    let source: Source

    // Content
    let originalTranscription: String
    let refinedText: String?
    let teacherExplanation: String?

    // Metadata
    let transcriptionApi: String?
    let transcriptionModel: String?
    let optimizationModel: String?
    let optimizationLevel: String?
    let outputStyle: String?
    let userLanguage: String?
    let audioDuration: Double?
    let audioFileUrl: String?
    let createdAt: Date?
    let updatedAt: Date?

    // Sync (local records only)
    let syncStatus: LocalInteraction.SyncStatus?
    let isSynced: Bool

    // Learning
    let vocabularySuggestions: [VocabularySuggestion]

    /// Build a detail snapshot from a locally stored interaction.
    init(local: LocalInteraction) {
        self.id = local.id
        self.source = .local
        self.originalTranscription = local.originalTranscription
        self.refinedText = local.refinedText
        self.teacherExplanation = local.teacherExplanation
        self.transcriptionApi = local.transcriptionApi
        self.transcriptionModel = local.transcriptionModel
        self.optimizationModel = local.optimizationModel
        self.optimizationLevel = local.optimizationLevel
        self.outputStyle = local.outputStyle
        self.userLanguage = local.userLanguage
        self.audioDuration = local.audioDuration > 0 ? local.audioDuration : nil
        self.audioFileUrl = local.audioFileUrl
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.syncStatus = local.syncStatusEnum
        self.isSynced = local.isSynced
        self.vocabularySuggestions = local.vocabularySuggestionsArray
    }

    /// Build a detail snapshot from a record fetched from the backend.
    init(remote: InteractionRecord) {
        self.id = remote.id ?? UUID()
        self.source = .remote
        self.originalTranscription = remote.originalTranscription ?? ""
        self.refinedText = remote.refinedText
        self.teacherExplanation = remote.teacherExplanation
        self.transcriptionApi = remote.transcriptionApi
        self.transcriptionModel = remote.transcriptionModel
        self.optimizationModel = remote.optimizationModel
        self.optimizationLevel = remote.optimizationLevel
        self.outputStyle = remote.outputStyle
        self.userLanguage = nil
        self.audioDuration = remote.audioDuration
        self.audioFileUrl = remote.audioFileUrl
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.syncStatus = .synced
        self.isSynced = true
        // Remote records don't carry suggestions yet; they live on local records.
        self.vocabularySuggestions = []
    }
}

// MARK: - Detail View

struct InteractionDetailView: View {
    let detail: InteractionDetail

    @Environment(\.dismiss) private var dismiss
    @State private var copiedField: String?

    // Recommended words persisted with this record. Held as mutable state so the
    // add/already-saved status can update in place.
    @State private var suggestions: [VocabularySuggestion] = []
    @State private var expandedSuggestion: VocabularySuggestion?

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    originalSection

                    if let refined = detail.refinedText, !refined.isEmpty {
                        refinedSection(refined)
                    }

                    if let note = detail.teacherExplanation, !note.isEmpty {
                        teacherNoteSection(note)
                    }

                    if !suggestions.isEmpty {
                        recommendedWordsSection
                    }

                    metadataSection
                }
                .padding()
            }
        }
        .frame(width: 520, height: 600)
        .onAppear(perform: loadSuggestions)
        .sheet(item: $expandedSuggestion) { suggestion in
            VocabularySuggestionDetailView(
                suggestion: suggestion,
                onAdd: { Task { await addSuggestion(suggestion) } },
                onClose: { expandedSuggestion = nil }
            )
            .frame(width: 320, height: 380)
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.blue)
            Text("detail.title".localized)
                .font(.headline)
            Spacer()
            Button("detail.done".localized) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 8) {
            sourceBadge
            if let score = extractScore(from: detail.teacherExplanation) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(score)
                        .font(.caption)
                        .bold()
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            Spacer()
            if let created = detail.createdAt {
                Text(absoluteDate(created))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let isSynced = detail.source == .remote || detail.isSynced
        HStack(spacing: 4) {
            Image(systemName: isSynced ? "checkmark.icloud.fill" : "internaldrive")
            Text(isSynced ? "detail.source_synced".localized : "detail.source_local".localized)
                .font(.caption)
        }
        .foregroundColor(isSynced ? .green : .gray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isSynced ? Color.green : Color.gray).opacity(0.12))
        .cornerRadius(6)
    }

    private var originalSection: some View {
        sectionContainer(
            title: "detail.original".localized,
            systemImage: "text.quote",
            copyText: detail.originalTranscription
        ) {
            if detail.originalTranscription.isEmpty {
                Text("—")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Selectable text view enables right-click → add word to vocabulary,
                // matching the record preview page.
                TranscriptionTextView(text: detail.originalTranscription)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func refinedSection(_ refined: String) -> some View {
        sectionContainer(
            title: "detail.refined".localized,
            systemImage: "sparkles",
            accessory: detail.optimizationModel.map { AnyView(modelChip($0)) },
            copyText: refined
        ) {
            // Selectable so users can right-click → add a word to vocabulary.
            TranscriptionTextView(text: refined, selfSizing: true, minHeight: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func teacherNoteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("detail.teacher_note".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            TranscriptionTextView(
                text: note,
                attributed: teacherNoteAttributedString(note),
                selfSizing: true,
                minHeight: 40
            )
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Recommended Words

    private var recommendedWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VocabularySuggestionsSection(
                suggestions: suggestions,
                onAdd: { suggestion in Task { await addSuggestion(suggestion) } },
                onExpand: { suggestion in expandedSuggestion = suggestion }
            )
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("detail.metadata".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                metadataRow("detail.duration".localized, detail.audioDuration.map(formatDuration))
                metadataRow("detail.stt_provider".localized, detail.transcriptionApi)
                metadataRow("detail.stt_model".localized, detail.transcriptionModel)
                metadataRow("detail.optimization_model".localized, detail.optimizationModel)
                metadataRow("detail.optimization_level".localized, detail.optimizationLevel?.capitalized)
                metadataRow("detail.output_style".localized, detail.outputStyle?.capitalized)
                metadataRow("detail.language".localized, detail.userLanguage)
                metadataRow("detail.created".localized, detail.createdAt.map(absoluteDate))
                metadataRow("detail.updated".localized, detail.updatedAt.map(absoluteDate))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
        }
    }

    // MARK: - Building Blocks

    /// A titled content block with an optional accessory and a copy button.
    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        systemImage: String,
        accessory: AnyView? = nil,
        copyText: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let accessory = accessory {
                    accessory
                }

                Spacer()

                if let copyText = copyText, !copyText.isEmpty {
                    Button(action: { copy(copyText, field: title) }) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedField == title ? "checkmark" : "doc.on.doc")
                            Text(copiedField == title ? "detail.copied".localized : "detail.copy".localized)
                        }
                        .font(.caption2)
                        .foregroundColor(copiedField == title ? .green : .blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
        }
    }

    private func modelChip(_ model: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(LLMModel(rawValue: model)?.displayName ?? model)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(4)
    }

    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String?) -> some View {
        if let value = value, !value.isEmpty {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 6)
            Divider()
        }
    }

    // MARK: - Suggestion Actions

    /// Load persisted suggestions once, flagging any already in the user's vocabulary.
    private func loadSuggestions() {
        guard suggestions.isEmpty else { return }
        var loaded = detail.vocabularySuggestions
        for index in loaded.indices where VocabularyStorage.shared.wordExists(loaded[index].word) {
            loaded[index].isAlreadySaved = true
        }
        suggestions = loaded
    }

    /// Look up a recommended word and save it to the vocabulary, updating row state.
    @MainActor
    private func addSuggestion(_ suggestion: VocabularySuggestion) async {
        guard let index = suggestions.firstIndex(where: {
            $0.word.lowercased() == suggestion.word.lowercased()
        }) else { return }

        guard !suggestions[index].isAlreadySaved, !suggestions[index].isAdding else { return }

        if VocabularyStorage.shared.wordExists(suggestion.word) {
            suggestions[index].isAlreadySaved = true
            return
        }

        suggestions[index].isAdding = true

        do {
            let explanation = try await VocabularyLookupService.shared.lookupWord(
                suggestion.word,
                context: suggestion.sourceSentence
            )
            VocabularyStorage.shared.addWord(from: explanation, userContext: suggestion.sourceSentence)
            VocabularyStorage.shared.incrementWordsAdded()

            suggestions[index].isAdding = false
            suggestions[index].wasJustAdded = true
            suggestions[index].isAlreadySaved = true
            Logger.info("Added recommended word: \(suggestion.word)", category: .vocabulary)
        } catch {
            suggestions[index].isAdding = false
            Logger.error("Failed to add recommended word: \(suggestion.word)", category: .vocabulary, error: error)
        }
    }

    // MARK: - Helpers

    private func copy(_ text: String, field: String) {
        ClipboardManager.shared.copy(text: text)
        withAnimation { copiedField = field }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if copiedField == field { copiedField = nil }
            }
        }
    }

    private func absoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func extractScore(from text: String?) -> String? {
        guard let text = text else { return nil }
        let pattern = #"Score:\s*(\d+/10)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let scoreRange = Range(match.range(at: 1), in: text) {
            return String(text[scoreRange])
        }
        return nil
    }
}

// MARK: - Preview

struct InteractionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionDetailView(detail: InteractionDetail(remote: InteractionRecord(
            id: UUID(),
            originalTranscription: "Uh, now is another test for the model we selected from GPT.",
            transcriptionApi: "OpenAI",
            transcriptionModel: "whisper-1",
            refinedText: "Now we're conducting another test for the model we selected.",
            optimizationModel: "gpt-4o-mini",
            optimizationLevel: "moderate",
            outputStyle: "professional",
            teacherExplanation: "Score: 7/10\n\nKey improvements:\n• Removed filler words for clarity.\n• Improved verb choice for a more formal tone.",
            audioDuration: 18,
            createdAt: Date()
        )))
    }
}

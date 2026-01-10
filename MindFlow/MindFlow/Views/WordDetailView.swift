//
//  WordDetailView.swift
//  MindFlow
//
//  Full word information detail view
//

import SwiftUI

/// Detail view displaying comprehensive word information
struct WordDetailView: View {
    let entry: VocabularyEntry
    let onClose: () -> Void

    @State private var isEditing: Bool = false
    @State private var editedCategory: String = ""
    @State private var editedTags: String = ""
    @State private var editedUserContext: String = ""

    private let storage = VocabularyStorage.shared

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with word and controls
                headerSection

                Divider()

                // Main content sections
                definitionSection
                examplesSection
                relatedWordsSection
                etymologySection
                learningSection
                contextSection
                metadataSection
            }
            .padding()
        }
        .frame(minWidth: 400)
        .onAppear {
            editedCategory = entry.category ?? ""
            editedTags = entry.tagsArray.joined(separator: ", ")
            editedUserContext = entry.userContext ?? ""
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(entry.word)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if let phonetic = entry.phonetic {
                            Text(phonetic)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        PronunciationButton(word: entry.word, size: .regular)

                        Button(action: { storage.toggleFavorite(entry: entry) }) {
                            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                                .foregroundColor(entry.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let partOfSpeech = entry.partOfSpeech {
                        Text(partOfSpeech)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Mastery level indicator
            HStack(spacing: 8) {
                masteryLevelBadge

                Text("•")
                    .foregroundColor(.secondary)

                if let nextReview = entry.nextReviewAt {
                    if nextReview <= Date() {
                        Text("Due for review")
                            .foregroundColor(.orange)
                    } else {
                        Text("Next review: \(nextReview.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    }
                }

                Text("•")
                    .foregroundColor(.secondary)

                Text("\(entry.reviewCount) reviews")
                    .foregroundColor(.secondary)

                if entry.reviewCount > 0 {
                    Text("(\(Int(entry.accuracy))% accuracy)")
                        .foregroundColor(entry.accuracy >= 80 ? .green : (entry.accuracy >= 60 ? .orange : .red))
                }
            }
            .font(.caption)
        }
    }

    private var masteryLevelBadge: some View {
        let level = entry.masteryLevelEnum

        return HStack(spacing: 4) {
            Circle()
                .fill(masteryColor(level))
                .frame(width: 8, height: 8)

            Text(level.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(masteryColor(level).opacity(0.1))
        .cornerRadius(8)
    }

    private func masteryColor(_ level: VocabularyEntry.MasteryLevel) -> Color {
        switch level {
        case .new: return .gray
        case .learning: return .red
        case .reviewing: return .orange
        case .familiar: return .blue
        case .mastered: return .green
        }
    }

    // MARK: - Definition Section

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Definition", icon: "text.book.closed")

            if let defEN = entry.definitionEN, !defEN.isEmpty {
                Text(defEN)
                    .font(.body)
            }

            if let defCN = entry.definitionCN, !defCN.isEmpty {
                Text(defCN)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if entry.definitionEN == nil && entry.definitionCN == nil {
                Text("No definition available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Examples Section

    @ViewBuilder
    private var examplesSection: some View {
        if !entry.exampleSentencesArray.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Examples", icon: "text.quote")

                ForEach(Array(entry.exampleSentencesArray.enumerated()), id: \.offset) { index, example in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.en)
                            .font(.body)

                        Text(example.cn)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Related Words Section

    @ViewBuilder
    private var relatedWordsSection: some View {
        if !entry.synonymsArray.isEmpty || !entry.antonymsArray.isEmpty || entry.wordFamily != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Related Words", icon: "link")

                if !entry.synonymsArray.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Synonyms")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(entry.synonymsArray, id: \.self) { synonym in
                                Text(synonym)
                                    .font(.callout)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                if !entry.antonymsArray.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Antonyms")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(entry.antonymsArray, id: \.self) { antonym in
                                Text(antonym)
                                    .font(.callout)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                if let wordFamily = entry.wordFamily, !wordFamily.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Word Family")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(wordFamily)
                            .font(.callout)
                    }
                }
            }
        }
    }

    // MARK: - Etymology Section

    @ViewBuilder
    private var etymologySection: some View {
        if let etymology = entry.etymology, !etymology.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Etymology", icon: "book")

                Text(etymology)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Learning Section

    @ViewBuilder
    private var learningSection: some View {
        if (entry.usageNotes != nil && !entry.usageNotes!.isEmpty) ||
           (entry.memoryTips != nil && !entry.memoryTips!.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Learning Tips", icon: "lightbulb")

                if let usageNotes = entry.usageNotes, !usageNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(usageNotes)
                            .font(.body)
                    }
                }

                if let memoryTips = entry.memoryTips, !memoryTips.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory Tips")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(memoryTips)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Context Section

    @ViewBuilder
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Your Context", icon: "text.bubble")

                Spacer()

                Button(action: { isEditing.toggle() }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Category", text: $editedCategory)
                        .textFieldStyle(.roundedBorder)

                    TextField("Tags (comma-separated)", text: $editedTags)
                        .textFieldStyle(.roundedBorder)

                    TextField("Personal notes about this word", text: $editedUserContext, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)

                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                if let userContext = entry.userContext, !userContext.isEmpty {
                    Text(userContext)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                } else {
                    Text("No personal notes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Details", icon: "info.circle")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(entry.category ?? "Uncategorized")
                        .font(.callout)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.callout)
                }
            }

            if !entry.tagsArray.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(entry.tagsArray, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }

    // MARK: - Actions

    private func saveChanges() {
        let tags = editedTags
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        storage.updateMetadata(
            entry: entry,
            tags: tags,
            category: editedCategory.isEmpty ? nil : editedCategory,
            userContext: editedUserContext.isEmpty ? nil : editedUserContext
        )

        isEditing = false
    }
}

// MARK: - Flow Layout

/// A simple flow layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)

                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                size.width = max(size.width, currentX)
            }

            size.height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

struct WordDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WordDetailView(
            entry: PreviewHelpers.sampleVocabularyEntry(),
            onClose: {}
        )
    }
}

// Preview helper
enum PreviewHelpers {
    static func sampleVocabularyEntry() -> VocabularyEntry {
        let entry = VocabularyEntry(context: CoreDataManager.shared.viewContext)
        entry.id = UUID()
        entry.word = "eloquent"
        entry.phonetic = "/ˈeləkwənt/"
        entry.partOfSpeech = "adjective"
        entry.definitionEN = "Fluent or persuasive in speaking or writing"
        entry.definitionCN = "雄辩的；有口才的"
        entry.masteryLevel = 2
        entry.reviewCount = 5
        entry.correctCount = 4
        entry.easeFactor = 2.5
        entry.interval = 7
        entry.nextReviewAt = Date().addingTimeInterval(86400 * 3)
        entry.createdAt = Date()
        entry.updatedAt = Date()
        return entry
    }
}

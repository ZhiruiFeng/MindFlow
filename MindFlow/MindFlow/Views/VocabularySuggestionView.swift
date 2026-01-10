//
//  VocabularySuggestionView.swift
//  MindFlow
//
//  Displays vocabulary suggestions from transcription with one-click add functionality.
//

import SwiftUI

/// Container view for the vocabulary suggestions section
struct VocabularySuggestionsSection: View {
    let suggestions: [VocabularySuggestion]
    let onAdd: (VocabularySuggestion) -> Void
    let onExpand: (VocabularySuggestion) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Section header
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("vocabulary.suggestions.title".localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Suggestions list
                VStack(spacing: 6) {
                    ForEach(suggestions) { suggestion in
                        VocabularySuggestionRow(
                            suggestion: suggestion,
                            onAdd: { onAdd(suggestion) },
                            onExpand: { onExpand(suggestion) }
                        )
                    }
                }
            }
        }
    }
}

/// Single vocabulary suggestion row with compact display
struct VocabularySuggestionRow: View {
    let suggestion: VocabularySuggestion
    let onAdd: () -> Void
    let onExpand: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Word and part of speech
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(suggestion.word)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(suggestion.partOfSpeech)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(3)
                }

                // Brief definition (truncated)
                Text(suggestion.definition)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onExpand()
        }
    }

    private var backgroundColor: Color {
        if suggestion.wasJustAdded {
            return Color.green.opacity(0.1)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.8)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if suggestion.isAdding {
            // Loading state
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 24, height: 24)
        } else if suggestion.wasJustAdded || suggestion.isAlreadySaved {
            // Already saved state
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
        } else {
            // Add button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 24, height: 24)
            .help("vocabulary.suggestions.add".localized)
        }
    }
}

/// Expanded detail view for a vocabulary suggestion
struct VocabularySuggestionDetailView: View {
    let suggestion: VocabularySuggestion
    let onAdd: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with word and close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.word)
                        .font(.system(size: 18, weight: .semibold))

                    Text(suggestion.partOfSpeech)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider()

            // Definition
            VStack(alignment: .leading, spacing: 4) {
                Text("vocabulary.suggestions.definition".localized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(suggestion.definition)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }

            // Why learn this word
            VStack(alignment: .leading, spacing: 4) {
                Text("vocabulary.suggestions.why_learn".localized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(suggestion.reason)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Source sentence
            VStack(alignment: .leading, spacing: 4) {
                Text("vocabulary.suggestions.source".localized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(highlightWord(in: suggestion.sourceSentence, word: suggestion.word))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(4)
            }

            Spacer()

            // Action button
            HStack {
                Spacer()
                actionButton
                Spacer()
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var actionButton: some View {
        if suggestion.isAdding {
            ProgressView()
                .scaleEffect(0.8)
        } else if suggestion.wasJustAdded || suggestion.isAlreadySaved {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("vocabulary.suggestions.added".localized)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.green)
        } else {
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("vocabulary.suggestions.add_to_vocab".localized)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Highlight the target word in the sentence
    private func highlightWord(in sentence: String, word: String) -> AttributedString {
        var attributedString = AttributedString(sentence)

        // Find and highlight the word (case-insensitive)
        let lowercaseSentence = sentence.lowercased()
        let lowercaseWord = word.lowercased()

        if let range = lowercaseSentence.range(of: lowercaseWord) {
            let start = sentence.distance(from: sentence.startIndex, to: range.lowerBound)
            let length = word.count

            if let attrRange = Range(NSRange(location: start, length: length), in: attributedString) {
                attributedString[attrRange].foregroundColor = .primary
                attributedString[attrRange].font = .system(size: 12, weight: .semibold)
            }
        }

        return attributedString
    }
}

// MARK: - Preview

#Preview {
    let mockSuggestions = [
        VocabularySuggestion(
            word: "eloquent",
            partOfSpeech: "adjective",
            definition: "Fluent or persuasive in speaking or writing.",
            reason: "More expressive alternative to 'well-spoken'. Useful in formal contexts.",
            sourceSentence: "She gave an eloquent presentation."
        ),
        VocabularySuggestion(
            word: "meticulous",
            partOfSpeech: "adjective",
            definition: "Showing great attention to detail; very careful and precise.",
            reason: "Conveys more precision than 'careful'. Common in professional writing.",
            sourceSentence: "His meticulous approach ensured no errors."
        )
    ]

    return VStack(spacing: 20) {
        VocabularySuggestionsSection(
            suggestions: mockSuggestions,
            onAdd: { _ in },
            onExpand: { _ in }
        )

        Divider()

        VocabularySuggestionDetailView(
            suggestion: mockSuggestions[0],
            onAdd: {},
            onClose: {}
        )
        .frame(width: 300)
    }
    .padding()
    .frame(width: 400, height: 600)
}

//
//  FlashcardView.swift
//  MindFlow
//
//  Flashcard component for vocabulary review
//

import SwiftUI

/// Flashcard view for displaying vocabulary during review
struct FlashcardView: View {
    let entry: VocabularyEntry
    let isRevealed: Bool
    let reviewMode: ReviewSession.ReviewMode
    let onReveal: () -> Void

    @State private var isFlipped: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            cardContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onChange(of: isRevealed) { newValue in
            if newValue && !isFlipped {
                isFlipped = true
            } else if !newValue {
                isFlipped = false
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRevealed {
                onReveal()
            }
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        if isRevealed {
            revealedContent
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        } else {
            questionContent
        }
    }

    // MARK: - Question Side

    private var questionContent: some View {
        VStack(spacing: 24) {
            Spacer()

            switch reviewMode {
            case .flashcard:
                // Show word, recall meaning
                VStack(spacing: 12) {
                    Text(entry.word)
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    HStack(spacing: 8) {
                        if let phonetic = entry.phonetic {
                            Text(phonetic)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }

                        PronunciationButton(word: entry.word, size: .regular)
                    }

                    if let partOfSpeech = entry.partOfSpeech {
                        Text(partOfSpeech)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
                .onAppear {
                    // Auto-play pronunciation if enabled
                    if Settings.shared.vocabularyAutoPlayPronunciation {
                        Task {
                            try? await TTSService.shared.pronounce(word: entry.word)
                        }
                    }
                }

            case .reverse:
                // Show meaning, recall word
                VStack(spacing: 12) {
                    if let defEN = entry.definitionEN {
                        Text(defEN)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                    }

                    if let defCN = entry.definitionCN {
                        Text(defCN)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

            case .context:
                // Show context/example, recall word
                if let example = entry.exampleSentencesArray.first {
                    VStack(spacing: 16) {
                        Text("Complete the sentence:")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(hideWordInSentence(example.en, word: entry.word))
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Text(example.cn)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Fill in the blank:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Tap hint
            VStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Tap to reveal answer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("or press Space")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Answer Side

    private var revealedContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // Word header
            VStack(spacing: 8) {
                Text(entry.word)
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    if let phonetic = entry.phonetic {
                        Text(phonetic)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    PronunciationButton(word: entry.word, size: .regular)
                }

                if let partOfSpeech = entry.partOfSpeech {
                    Text(partOfSpeech)
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }

            Divider()
                .padding(.horizontal, 32)

            // Definitions
            VStack(alignment: .leading, spacing: 12) {
                if let defEN = entry.definitionEN {
                    Text(defEN)
                        .font(.body)
                }

                if let defCN = entry.definitionCN {
                    Text(defCN)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Example sentence
            if let example = entry.exampleSentencesArray.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(example.en)
                        .font(.callout)
                        .italic()

                    Text(example.cn)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }

            // Memory tip
            if let memoryTips = entry.memoryTips, !memoryTips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Memory Tip", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text(memoryTips)
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }

            Spacer()

            // Rating hint
            Text("How well did you remember?")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private func hideWordInSentence(_ sentence: String, word: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(sentence.startIndex..., in: sentence)
            return regex.stringByReplacingMatches(
                in: sentence,
                options: [],
                range: range,
                withTemplate: "_____"
            )
        }
        return sentence.replacingOccurrences(of: word, with: "_____")
    }
}

// MARK: - Preview

struct FlashcardView_Previews: PreviewProvider {
    static var previews: some View {
        FlashcardView(
            entry: PreviewHelpers.sampleVocabularyEntry(),
            isRevealed: false,
            reviewMode: .flashcard,
            onReveal: {}
        )
        .frame(width: 400, height: 500)
        .padding()
    }
}

//
//  VocabularyRowView.swift
//  MindFlow
//
//  Single vocabulary entry row for list display
//

import SwiftUI

/// Row view for displaying a vocabulary entry in a list
struct VocabularyRowView: View {
    let entry: VocabularyEntry

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Mastery indicator
            masteryIndicator

            // Word info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.word)
                        .font(.body)
                        .fontWeight(.medium)

                    if let phonetic = entry.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                HStack(spacing: 4) {
                    if let partOfSpeech = entry.partOfSpeech {
                        Text(partOfSpeech)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    Text(truncatedDefinition)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Review status
            reviewStatus
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mastery Indicator

    private var masteryIndicator: some View {
        let level = entry.masteryLevelEnum

        return ZStack {
            Circle()
                .fill(masteryColor(level).opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: masteryIcon(level))
                .font(.caption)
                .foregroundColor(masteryColor(level))
        }
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

    private func masteryIcon(_ level: VocabularyEntry.MasteryLevel) -> String {
        switch level {
        case .new: return "sparkle"
        case .learning: return "brain"
        case .reviewing: return "arrow.clockwise"
        case .familiar: return "hand.thumbsup"
        case .mastered: return "checkmark.seal.fill"
        }
    }

    // MARK: - Review Status

    private var reviewStatus: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if entry.isDueForReview {
                Text("Due")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(8)
            } else if let nextReview = entry.nextReviewAt {
                Text(nextReviewText(nextReview))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if entry.reviewCount > 0 {
                HStack(spacing: 2) {
                    Text("\(entry.reviewCount)")
                        .font(.caption2)

                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)

                    Text("•")

                    Text("\(Int(entry.accuracy))%")
                        .font(.caption2)
                        .foregroundColor(entry.accuracy >= 80 ? .green : (entry.accuracy >= 60 ? .orange : .red))
                }
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var truncatedDefinition: String {
        if let defEN = entry.definitionEN, !defEN.isEmpty {
            return defEN
        } else if let defCN = entry.definitionCN, !defCN.isEmpty {
            return defCN
        }
        return "No definition"
    }

    private func nextReviewText(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            if days < 7 {
                return "\(days)d"
            } else if days < 30 {
                return "\(days / 7)w"
            } else {
                return "\(days / 30)mo"
            }
        }
    }
}

// MARK: - Preview

struct VocabularyRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            VocabularyRowView(entry: PreviewHelpers.sampleVocabularyEntry())
        }
        .frame(width: 400)
    }
}

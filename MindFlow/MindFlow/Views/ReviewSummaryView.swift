//
//  ReviewSummaryView.swift
//  MindFlow
//
//  Summary view shown after completing a review session
//

import SwiftUI

/// View displaying review session results and statistics
struct ReviewSummaryView: View {
    @ObservedObject var viewModel: ReviewViewModel
    let onDismiss: () -> Void

    private var session: ReviewSession? {
        viewModel.session
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Celebration icon
            celebrationHeader

            // Statistics
            statisticsSection

            // Performance message
            performanceMessage

            Spacer()

            // Actions
            actionButtons
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Celebration Header

    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(celebrationColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: celebrationIcon)
                    .font(.system(size: 56))
                    .foregroundColor(celebrationColor)
            }

            Text("Session Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let session = session {
                Text("You reviewed \(session.totalWords) word\(session.totalWords == 1 ? "" : "s")")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var celebrationColor: Color {
        guard let session = session else { return .blue }
        let accuracy = session.accuracy

        if accuracy >= 80 {
            return .green
        } else if accuracy >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private var celebrationIcon: String {
        guard let session = session else { return "checkmark.circle.fill" }
        let accuracy = session.accuracy

        if accuracy >= 80 {
            return "star.circle.fill"
        } else if accuracy >= 60 {
            return "checkmark.circle.fill"
        } else {
            return "arrow.clockwise.circle.fill"
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        HStack(spacing: 32) {
            statisticCard(
                title: "Correct",
                value: "\(viewModel.correctCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            statisticCard(
                title: "Incorrect",
                value: "\(viewModel.incorrectCount)",
                icon: "xmark.circle.fill",
                color: .red
            )

            statisticCard(
                title: "Skipped",
                value: "\(viewModel.skippedCount)",
                icon: "forward.circle.fill",
                color: .gray
            )

            statisticCard(
                title: "Accuracy",
                value: "\(Int(viewModel.accuracy))%",
                icon: "percent",
                color: accuracyColor
            )

            if let session = session, session.durationSeconds > 0 {
                statisticCard(
                    title: "Duration",
                    value: session.formattedDuration,
                    icon: "clock.fill",
                    color: .blue
                )
            }
        }
        .padding(.horizontal)
    }

    private var accuracyColor: Color {
        let accuracy = viewModel.accuracy
        if accuracy >= 80 {
            return .green
        } else if accuracy >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private func statisticCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Performance Message

    private var performanceMessage: some View {
        VStack(spacing: 8) {
            Text(performanceTitle)
                .font(.headline)

            Text(performanceSubtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var performanceTitle: String {
        let accuracy = viewModel.accuracy

        if accuracy >= 90 {
            return "Outstanding! 🌟"
        } else if accuracy >= 80 {
            return "Great job! 👏"
        } else if accuracy >= 60 {
            return "Good effort! 💪"
        } else {
            return "Keep practicing! 📚"
        }
    }

    private var performanceSubtitle: String {
        let accuracy = viewModel.accuracy

        if accuracy >= 90 {
            return "You have excellent recall of these words. Keep up the great work!"
        } else if accuracy >= 80 {
            return "You're doing well! Most of these words are becoming familiar."
        } else if accuracy >= 60 {
            return "You're making progress. Regular review will help strengthen your memory."
        } else {
            return "Don't worry – learning takes time. These words will become familiar with more practice."
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onDismiss) {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.escape)

            if viewModel.getDueCount() > 0 {
                Button(action: startNewSession) {
                    Label("Review More (\(viewModel.getDueCount()))", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func startNewSession() {
        viewModel.resetSession()
        Task {
            await viewModel.startSession(
                limit: Settings.shared.vocabularyDailyReviewGoal,
                mode: .flashcard
            )
        }
    }
}

// MARK: - Preview

struct ReviewSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewSummaryView(viewModel: ReviewViewModel(), onDismiss: {})
    }
}

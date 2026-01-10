//
//  ReviewSessionView.swift
//  MindFlow
//
//  Container view for vocabulary review session
//

import SwiftUI

/// Review session container view with flashcards and rating
struct ReviewSessionView: View {
    @ObservedObject var viewModel: ReviewViewModel
    let onComplete: () -> Void

    @State private var showingSummary: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if showingSummary {
                ReviewSummaryView(viewModel: viewModel, onDismiss: onComplete)
            } else if viewModel.isSessionActive {
                activeSessionView
            } else {
                noSessionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: viewModel.isSessionActive) { isActive in
            if !isActive && viewModel.session != nil {
                showingSummary = true
            }
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 0) {
            // Header with progress
            sessionHeader

            // Flashcard
            flashcardArea

            // Rating buttons (when revealed)
            if viewModel.isAnswerRevealed {
                ratingButtons
            }
        }
        .modifier(KeyPressModifier(
            onSpace: {
                if !viewModel.isAnswerRevealed {
                    viewModel.revealAnswer()
                }
            },
            on1: {
                if viewModel.isAnswerRevealed {
                    viewModel.rateAndProceed(quality: .forgot)
                }
            },
            on2: {
                if viewModel.isAnswerRevealed {
                    viewModel.rateAndProceed(quality: .hard)
                }
            },
            on3: {
                if viewModel.isAnswerRevealed {
                    viewModel.rateAndProceed(quality: .good)
                }
            },
            onEscape: {
                viewModel.cancelSession()
                onComplete()
            }
        ))
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    viewModel.cancelSession()
                    onComplete()
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .keyboardShortcut(.escape)

                Spacer()

                // Progress indicator
                HStack(spacing: 8) {
                    Text("\(viewModel.currentIndex + 1)")
                        .fontWeight(.bold)

                    Text("/")
                        .foregroundColor(.secondary)

                    Text("\(viewModel.reviewWords.count)")
                        .foregroundColor(.secondary)
                }
                .font(.headline)

                Spacer()

                // Session stats
                HStack(spacing: 16) {
                    Label("\(viewModel.correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Label("\(viewModel.incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .font(.callout)
            }
            .padding()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * viewModel.progress, height: 4)
                        .animation(.easeInOut, value: viewModel.progress)
                }
            }
            .frame(height: 4)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Flashcard Area

    private var flashcardArea: some View {
        VStack {
            if let word = viewModel.currentWord {
                FlashcardView(
                    entry: word,
                    isRevealed: viewModel.isAnswerRevealed,
                    reviewMode: viewModel.reviewMode,
                    onReveal: {
                        viewModel.revealAnswer()
                    }
                )
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 16) {
            ratingButton(
                quality: .forgot,
                title: "Forgot",
                subtitle: "Start over",
                color: .red,
                shortcut: "1"
            )

            ratingButton(
                quality: .hard,
                title: "Hard",
                subtitle: "Struggled",
                color: .orange,
                shortcut: "2"
            )

            ratingButton(
                quality: .good,
                title: "Good",
                subtitle: "Got it!",
                color: .green,
                shortcut: "3"
            )

            Divider()
                .frame(height: 50)

            Button(action: { viewModel.skipWord() }) {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                    Text("Skip")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .frame(width: 80)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func ratingButton(
        quality: SpacedRepetitionService.ResponseQuality,
        title: String,
        subtitle: String,
        color: Color,
        shortcut: String
    ) -> some View {
        Button(action: {
            viewModel.rateAndProceed(quality: quality)
        }) {
            VStack(spacing: 4) {
                Image(systemName: ratingIcon(for: quality))
                    .font(.title)

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("[\(shortcut)]")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(12)
    }

    private func ratingIcon(for quality: SpacedRepetitionService.ResponseQuality) -> String {
        switch quality {
        case .forgot: return "xmark.circle"
        case .hard: return "exclamationmark.circle"
        case .good: return "checkmark.circle"
        }
    }

    // MARK: - No Session View

    private var noSessionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Review Session")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a review session from the vocabulary list")
                .foregroundColor(.secondary)

            Button("Go Back") {
                onComplete()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Key Press Modifier

/// Cross-version compatible key press handling
struct KeyPressModifier: ViewModifier {
    let onSpace: () -> Void
    let on1: () -> Void
    let on2: () -> Void
    let on3: () -> Void
    let onEscape: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.space) {
                    onSpace()
                    return .handled
                }
                .onKeyPress("1") {
                    on1()
                    return .handled
                }
                .onKeyPress("2") {
                    on2()
                    return .handled
                }
                .onKeyPress("3") {
                    on3()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onEscape()
                    return .handled
                }
        } else {
            // Fallback for older macOS - keyboard shortcuts handled via buttons
            content
        }
    }
}

// MARK: - Preview

struct ReviewSessionView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewSessionView(viewModel: ReviewViewModel(), onComplete: {})
    }
}

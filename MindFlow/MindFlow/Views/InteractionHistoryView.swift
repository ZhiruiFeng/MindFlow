//
//  InteractionHistoryView.swift
//  MindFlow
//
//  View for displaying interaction history with pagination
//

import SwiftUI

struct InteractionHistoryView: View {
    @StateObject private var viewModel = InteractionHistoryViewModel()
    @EnvironmentObject var authService: SupabaseAuthService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if !authService.isAuthenticated {
                notAuthenticatedView
            } else {
                contentView
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.blue)
            Text("History")
                .font(.title2)
                .bold()

            Spacer()

            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.interactions.isEmpty {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if viewModel.interactions.isEmpty {
            emptyStateView
        } else {
            interactionListView
        }
    }

    private var interactionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.interactions) { interaction in
                    InteractionRowView(interaction: interaction)
                        .padding(.horizontal)
                }

                // Load More Button
                if viewModel.hasMore {
                    loadMoreButton
                        .padding(.vertical)
                }

                // Loading indicator at bottom
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.vertical)
        }
    }

    private var loadMoreButton: some View {
        Button(action: {
            Task {
                await viewModel.loadMore()
            }
        }) {
            HStack {
                Image(systemName: "arrow.down.circle")
                Text("Load More")
            }
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingMore)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading history...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Interactions Yet")
                .font(.title3)
                .bold()
            Text("Your transcription history will appear here")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Authentication Required")
                .font(.title3)
                .bold()
            Text("Please sign in to view your interaction history")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("Error Loading History")
                .font(.title3)
                .bold()
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

// MARK: - Interaction Row View

struct InteractionRowView: View {
    let interaction: InteractionRecord
    @State private var isOriginalExpanded = false
    @State private var isRefinedExpanded = false
    @State private var isTeacherNoteExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with date and API info
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                    Text(interaction.transcriptionApi ?? "Unknown")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            // Original text
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if (interaction.originalTranscription?.count ?? 0) > 100 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isOriginalExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isOriginalExpanded ? "chevron.up.circle" : "chevron.down.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(interaction.originalTranscription ?? "No transcription")
                    .font(.body)
                    .lineLimit(isOriginalExpanded ? nil : 3)
                    .animation(.easeInOut(duration: 0.2), value: isOriginalExpanded)
            }

            // Refined text (if available)
            if let refined = interaction.refinedText {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Refined:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let model = interaction.optimizationModel {
                                Text("(\(model))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if refined.count > 100 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isRefinedExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isRefinedExpanded ? "chevron.up.circle" : "chevron.down.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(refined)
                        .font(.body)
                        .lineLimit(isRefinedExpanded ? nil : 3)
                        .foregroundColor(.primary)
                        .animation(.easeInOut(duration: 0.2), value: isRefinedExpanded)
                }
            }

            // Teacher explanation (if available)
            if let explanation = interaction.teacherExplanation, !explanation.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    // Header with expand/collapse button
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Teacher's Note:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isTeacherNoteExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isTeacherNoteExpanded ? "Collapse" : "Expand")
                                    .font(.caption2)
                                Image(systemName: isTeacherNoteExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // Explanation text
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isTeacherNoteExpanded ? nil : 2)
                        .animation(.easeInOut(duration: 0.2), value: isTeacherNoteExpanded)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }

            // Metadata footer
            HStack(spacing: 12) {
                if let duration = interaction.audioDuration {
                    Label(formatDuration(duration), systemImage: "timer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let level = interaction.optimizationLevel {
                    Label(level.capitalized, systemImage: "slider.horizontal.3")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var formattedDate: String {
        guard let date = interaction.createdAt else { return "Unknown date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

struct InteractionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionHistoryView()
            .environmentObject(SupabaseAuthService())
    }
}

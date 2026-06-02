//
//  LocalHistoryView.swift
//  MindFlow
//
//  View for displaying local interaction history with sync status
//

import SwiftUI

struct LocalHistoryView: View {
    @StateObject private var viewModel = LocalHistoryViewModel()
    @EnvironmentObject var authService: SupabaseAuthService
    @State private var selectedDetail: InteractionDetail?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView
        }
        .onAppear {
            viewModel.loadInteractions()
        }
        .sheet(item: $selectedDetail) { detail in
            InteractionDetailView(detail: detail)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "externaldrive")
                .font(.title2)
                .foregroundColor(.blue)
            Text("Local History")
                .font(.title2)
                .bold()

            Spacer()

            // Sync All button
            if authService.isAuthenticated && viewModel.hasPendingSync {
                Button(action: {
                    Task {
                        await viewModel.syncAllPending()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync All")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSyncing)
            }

            Button(action: {
                viewModel.loadInteractions()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if viewModel.interactions.isEmpty {
            emptyStateView
        } else {
            interactionListView
        }
    }

    private var interactionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.interactions) { interaction in
                    LocalInteractionRowView(
                        interaction: interaction,
                        isAuthenticated: authService.isAuthenticated,
                        onSync: {
                            Task {
                                await viewModel.syncInteraction(interaction)
                            }
                        },
                        onOpenDetail: {
                            selectedDetail = InteractionDetail(local: interaction)
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Local Interactions")
                .font(.title3)
                .bold()
            Text("Your local recordings will appear here")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Local Interaction Row View

struct LocalInteractionRowView: View {
    let interaction: LocalInteraction
    let isAuthenticated: Bool
    let onSync: () -> Void
    let onOpenDetail: () -> Void

    @State private var isExpanded = false

    private var hasTeacherNote: Bool {
        !(interaction.teacherExplanation ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with date and sync status
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                syncStatusBadge
            }

            // Original transcription
            Text(interaction.originalTranscription)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)

            // Refined text (if available)
            if let refined = interaction.refinedText {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Refined:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let model = interaction.optimizationModel {
                            Text("(\(LLMModel(rawValue: model)?.displayName ?? model))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(refined)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 3)
                }
            }

            // Teacher's Note indicator (content is shown in the detail page)
            if hasTeacherNote {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text(teacherNotePreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 1)
                }
            }

            // Metadata footer
            HStack(spacing: 12) {
                Label(formatDuration(interaction.audioDuration), systemImage: "timer")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label(interaction.transcriptionApi, systemImage: "waveform")
                    .font(.caption2)
                    .foregroundColor(.blue)

                if let level = interaction.optimizationLevel {
                    Label(level.capitalized, systemImage: "slider.horizontal.3")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Open the comprehensive detail page
                Button(action: onOpenDetail) {
                    HStack(spacing: 4) {
                        Text("Details")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                // Expand/collapse button
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { onOpenDetail() }
    }

    /// First non-empty, non-score line of the teacher's note for an inline teaser.
    private var teacherNotePreview: String {
        let note = interaction.teacherExplanation ?? ""
        for line in note.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.lowercased().contains("score:") {
                return trimmed
            }
        }
        return "Teacher's Note"
    }

    @ViewBuilder
    private var syncStatusBadge: some View {
        if interaction.isSynced {
            // Synced to backend
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Synced")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .cornerRadius(4)
        } else if interaction.syncStatusEnum == .failed {
            // Sync failed - show retry button
            Button(action: onSync) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.red)
                    Text("Retry")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        } else if isAuthenticated {
            // Local only - can sync
            Button(action: onSync) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(.blue)
                    Text("Sync")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        } else {
            // Not authenticated - local only
            HStack(spacing: 4) {
                Image(systemName: "externaldrive")
                    .foregroundColor(.gray)
                Text("Local")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: interaction.createdAt, relativeTo: Date())
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

struct LocalHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        LocalHistoryView()
            .environmentObject(SupabaseAuthService())
    }
}

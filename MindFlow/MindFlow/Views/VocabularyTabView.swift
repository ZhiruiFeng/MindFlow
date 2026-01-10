//
//  VocabularyTabView.swift
//  MindFlow
//
//  Main container view for vocabulary learning feature
//

import SwiftUI

/// Main vocabulary tab container view
struct VocabularyTabView: View {
    @StateObject private var vocabularyViewModel = VocabularyViewModel()
    @StateObject private var reviewViewModel = ReviewViewModel()

    @State private var showingAddWord = false
    @State private var showingReview = false
    @State private var selectedWord: VocabularyEntry?
    @State private var sidebarSelection: SidebarItem = .allWords

    // Sync state
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var lastSyncDate: Date?

    private let syncService = VocabularySyncService.shared

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            if showingReview {
                ReviewSessionView(viewModel: reviewViewModel) {
                    showingReview = false
                }
            } else if let word = selectedWord {
                WordDetailView(entry: word) {
                    selectedWord = nil
                }
            } else {
                mainContentView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddWord) {
            AddWordView(viewModel: vocabularyViewModel)
        }
        .task {
            await vocabularyViewModel.loadWords()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vocabularyWordAdded)) { _ in
            Task {
                await vocabularyViewModel.loadWords()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with stats
            sidebarHeader

            Divider()

            // Navigation items
            List(selection: $sidebarSelection) {
                Section("Library") {
                    sidebarRow(.allWords, count: vocabularyViewModel.totalWordCount)
                    sidebarRow(.favorites, count: nil)
                    sidebarRow(.dueForReview, count: vocabularyViewModel.dueForReviewCount)
                }

                Section("Mastery Level") {
                    ForEach(VocabularyEntry.MasteryLevel.allCases, id: \.self) { level in
                        sidebarRow(.masteryLevel(level), count: vocabularyViewModel.masteryLevelCounts[level])
                    }
                }

                if !vocabularyViewModel.categories.isEmpty {
                    Section("Categories") {
                        ForEach(vocabularyViewModel.categories, id: \.self) { category in
                            sidebarRow(.category(category), count: nil)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: sidebarSelection) { newValue in
                Task {
                    await handleSidebarSelection(newValue)
                }
            }
        }
        .frame(minWidth: 200)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vocabulary")
                    .font(.headline)

                Spacer()

                // Sync status indicator
                if syncService.isConfigured {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else if let error = syncError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help("Sync error: \(error)")
                    } else if lastSyncDate != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .help("Synced")
                    }
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("\(vocabularyViewModel.totalWordCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(vocabularyViewModel.dueForReviewCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(vocabularyViewModel.dueForReviewCount > 0 ? .orange : .green)
                    Text("Due Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func sidebarRow(_ item: SidebarItem, count: Int?) -> some View {
        HStack {
            Label(item.title, systemImage: item.icon)

            Spacer()

            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item == .dueForReview ? Color.orange : Color.secondary.opacity(0.2))
                    .foregroundColor(item == .dueForReview ? .white : .primary)
                    .cornerRadius(8)
            }
        }
        .tag(item)
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content based on selection
            if vocabularyViewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vocabularyViewModel.words.isEmpty {
                emptyStateView
            } else {
                wordListView
            }
        }
    }

    private var toolbar: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search words...", text: $vocabularyViewModel.searchText)
                    .textFieldStyle(.plain)

                if !vocabularyViewModel.searchText.isEmpty {
                    Button(action: { vocabularyViewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 300)

            Spacer()

            // Filter indicator
            if vocabularyViewModel.selectedCategory != nil ||
               vocabularyViewModel.selectedMasteryLevel != nil ||
               vocabularyViewModel.showFavoritesOnly {
                Button(action: {
                    Task { await vocabularyViewModel.clearFilters() }
                }) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // Action buttons
            if vocabularyViewModel.dueForReviewCount > 0 {
                Button(action: startReview) {
                    Label("Review (\(vocabularyViewModel.dueForReviewCount))", systemImage: "brain")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }

            Button(action: { showingAddWord = true }) {
                Label("Add Word", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("n", modifiers: .command)

            // Sync button
            if syncService.isConfigured {
                Button(action: performSync) {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing)
                .help(lastSyncDate != nil ? "Last synced: \(lastSyncDate!.formatted())" : "Sync vocabulary")
            }
        }
        .padding()
    }

    private var wordListView: some View {
        List(vocabularyViewModel.words, selection: $selectedWord) { word in
            VocabularyRowView(entry: word)
                .tag(word)
                .contextMenu {
                    Button(action: { vocabularyViewModel.toggleFavorite(word) }) {
                        Label(word.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: word.isFavorite ? "star.slash" : "star")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        Task { await vocabularyViewModel.deleteWord(word) }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Words Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start building your vocabulary by adding your first word.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showingAddWord = true }) {
                Label("Add Your First Word", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func startReview() {
        Task {
            await reviewViewModel.startSession(
                limit: Settings.shared.vocabularyDailyReviewGoal,
                mode: .flashcard
            )
            if reviewViewModel.isSessionActive {
                showingReview = true
            }
        }
    }

    private func performSync() {
        guard !isSyncing else { return }

        Task {
            isSyncing = true
            syncError = nil

            do {
                let result = try await syncService.fullSync()
                lastSyncDate = Date()
                print("[VocabularyTabView] Sync completed: pushed \(result.pushed), pulled \(result.pulled)")

                // Reload words after sync
                await vocabularyViewModel.loadWords()
            } catch {
                syncError = error.localizedDescription
                print("[VocabularyTabView] Sync failed: \(error)")
            }

            isSyncing = false
        }
    }

    private func handleSidebarSelection(_ selection: SidebarItem) async {
        selectedWord = nil

        switch selection {
        case .allWords:
            await vocabularyViewModel.clearFilters()
        case .favorites:
            await vocabularyViewModel.toggleFavoritesFilter()
        case .dueForReview:
            // Show words due for review
            vocabularyViewModel.words = VocabularyStorage.shared.fetchWordsDueForReview()
        case .masteryLevel(let level):
            await vocabularyViewModel.filterByMasteryLevel(level)
        case .category(let category):
            await vocabularyViewModel.filterByCategory(category)
        }
    }
}

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case allWords
    case favorites
    case dueForReview
    case masteryLevel(VocabularyEntry.MasteryLevel)
    case category(String)

    var title: String {
        switch self {
        case .allWords: return "All Words"
        case .favorites: return "Favorites"
        case .dueForReview: return "Due for Review"
        case .masteryLevel(let level): return level.displayName
        case .category(let name): return name
        }
    }

    var icon: String {
        switch self {
        case .allWords: return "books.vertical"
        case .favorites: return "star.fill"
        case .dueForReview: return "clock.badge.exclamationmark"
        case .masteryLevel(let level):
            switch level {
            case .new: return "sparkle"
            case .learning: return "brain"
            case .reviewing: return "arrow.clockwise"
            case .familiar: return "hand.thumbsup"
            case .mastered: return "checkmark.seal.fill"
            }
        case .category: return "folder"
        }
    }
}

// MARK: - Mastery Level CaseIterable

extension VocabularyEntry.MasteryLevel: CaseIterable {
    public static var allCases: [VocabularyEntry.MasteryLevel] {
        return [.new, .learning, .reviewing, .familiar, .mastered]
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let vocabularyWordAdded = Notification.Name("vocabularyWordAdded")
}

// MARK: - Preview

struct VocabularyTabView_Previews: PreviewProvider {
    static var previews: some View {
        VocabularyTabView()
    }
}

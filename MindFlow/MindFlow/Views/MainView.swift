//
//  MainView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// Main workspace window.
///
/// Uses a native `NavigationSplitView` sidebar (the standard macOS multi-pane
/// layout) instead of the previous segmented-control + `TabView` combination,
/// which rendered two competing sets of tab chrome. Settings now lives in its
/// own `Settings` scene (⌘,) and recording can also be triggered from the
/// menu bar, so this window is purely the workspace.
struct MainView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject var authService: SupabaseAuthService
    @State private var selection: MainTab? = .recording

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .navigationTitle("MindFlow")
        } detail: {
            detailView
                .frame(minWidth: 460, minHeight: 520)
        }
        .frame(minWidth: 720, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: .switchToRecordingTab)) { _ in
            selection = .recording
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToVocabularyTab)) { _ in
            selection = .vocabulary
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToSettingsTab)) { _ in
            selection = .settings
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .recording {
        case .recording:
            RecordingTabView(viewModel: viewModel)
        case .localHistory:
            LocalHistoryView()
        case .history:
            InteractionHistoryView()
        case .vocabulary:
            VocabularyTabView()
        case .settings:
            SettingsTabView()
        }
    }
}

// MARK: - Main Tab Enum

/// Sidebar destinations for the main workspace window.
enum MainTab: CaseIterable {
    case recording
    case localHistory
    case history
    case vocabulary
    case settings

    var icon: String {
        switch self {
        case .recording: return "mic.circle.fill"
        case .localHistory: return "internaldrive"
        case .history: return "clock.arrow.circlepath"
        case .vocabulary: return "book"
        case .settings: return "gearshape"
        }
    }

    var title: String {
        switch self {
        case .recording: return "tab.recording".localized
        case .localHistory: return "Local"
        case .history: return "tab.history".localized
        case .vocabulary: return "Vocabulary"
        case .settings: return "tab.settings".localized
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(SupabaseAuthService())
    }
}

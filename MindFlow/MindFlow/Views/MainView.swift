//
//  MainView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// Main view - Integrates recording and settings functionality
///
/// Provides a unified user interface for navigating between recording and settings via tabs
struct MainView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject var authService: SupabaseAuthService
    @State private var selectedTab: MainTab = .recording

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .frame(minWidth: 500, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .switchToRecordingTab)) { _ in
            selectedTab = .recording
        }
    }

    // MARK: - Components

    private var headerBar: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.blue)
            Text("MindFlow")
                .font(.title2)
                .bold()
            Spacer()

            tabSwitcher
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var tabSwitcher: some View {
        Picker("", selection: $selectedTab) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Image(systemName: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }

    private var contentArea: some View {
        TabView(selection: $selectedTab) {
            RecordingTabView(viewModel: viewModel)
                .tag(MainTab.recording)

            InteractionHistoryView()
                .tag(MainTab.history)

            SettingsTabView()
                .tag(MainTab.settings)
        }
        .tabViewStyle(.automatic)
    }
}

// MARK: - Main Tab Enum

/// Main view tab type
enum MainTab: CaseIterable {
    case recording
    case history
    case settings

    var icon: String {
        switch self {
        case .recording: return "mic.circle.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gear"
        }
    }

    var title: String {
        switch self {
        case .recording: return "tab.recording".localized
        case .history: return "tab.history".localized
        case .settings: return "tab.settings".localized
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

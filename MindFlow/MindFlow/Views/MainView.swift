//
//  MainView.swift
//  MindFlow
//
//  Created on 2025-10-11.
//

import SwiftUI

/// 主视图 - 整合录音和设置功能
///
/// 提供统一的用户界面，通过 Tab 切换在录音和设置之间导航
struct MainView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var selectedTab: MainTab = .recording

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .frame(minWidth: 500, minHeight: 600)
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
        .frame(width: 120)
    }

    private var contentArea: some View {
        TabView(selection: $selectedTab) {
            RecordingTabView(viewModel: viewModel)
                .tag(MainTab.recording)

            SettingsTabView()
                .tag(MainTab.settings)
        }
        .tabViewStyle(.automatic)
    }
}

// MARK: - Main Tab Enum

/// 主视图的 Tab 类型
enum MainTab: CaseIterable {
    case recording
    case settings

    var icon: String {
        switch self {
        case .recording: return "mic.circle.fill"
        case .settings: return "gear"
        }
    }

    var title: String {
        switch self {
        case .recording: return "录音"
        case .settings: return "设置"
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

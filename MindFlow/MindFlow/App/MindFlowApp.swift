//
//  MindFlowApp.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

@main
struct MindFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = SupabaseAuthService()
    @StateObject private var settings = Settings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(settings)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 500, height: 600)
    }

    @MainActor
    struct ContentView: View {
        @EnvironmentObject private var authService: SupabaseAuthService
        @EnvironmentObject private var settings: Settings
        @State private var isInitialized = false

        var body: some View {
            Group {
                if isInitialized {
                    if settings.hasCompletedLoginFlow {
                        MainView()
                    } else {
                        LoginView()
                    }
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                Task {
                    await authService.restoreSession()
                    isInitialized = true
                }
            }
        }
    }
}

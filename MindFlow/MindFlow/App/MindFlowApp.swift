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
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(authService)
                .environmentObject(settings)
        }
        .commands {
            // Keep the File menu but remove "New" command since it doesn't make sense for this app
            CommandGroup(replacing: .newItem) {
                // Empty - removes the default "New" command
            }
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

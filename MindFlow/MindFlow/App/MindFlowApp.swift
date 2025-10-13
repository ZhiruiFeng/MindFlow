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
            if settings.hasCompletedLoginFlow {
                MainView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 500, height: 600)
    }
}

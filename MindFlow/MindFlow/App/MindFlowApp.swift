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

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 500, height: 600)
    }
}

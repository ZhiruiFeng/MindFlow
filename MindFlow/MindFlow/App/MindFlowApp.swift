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
        // 菜单栏应用，不需要主窗口
        // 使用 WindowGroup 但不显示窗口（由 Info.plist 中的 LSUIElement 控制）
        WindowGroup {
            EmptyView()
        }
    }
}


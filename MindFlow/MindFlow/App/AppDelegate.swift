//
//  AppDelegate.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // Managers
    let hotKeyManager = HotKeyManager.shared
    let permissionManager = PermissionManager.shared
    let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show Dock icon, run as normal application
        NSApplication.shared.setActivationPolicy(.regular)

        // Register global hotkey
        setupHotKey()

        // Check permissions
        checkPermissions()

        print("✅ MindFlow 启动成功")
    }

    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // Register default hotkey: Cmd+Shift+V
        // cmdKey = 0x0100 (256), shiftKey = 0x0200 (512)
        let modifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        hotKeyManager.registerHotKey(keyCode: 9, modifiers: modifiers) { [weak self] in
            self?.activateApp()
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Permissions
    
    private func checkPermissions() {
        Task {
            // Check microphone permission
            if !permissionManager.isMicrophonePermissionGranted {
                let granted = await permissionManager.requestMicrophonePermission()
                if !granted {
                    // Must show Alert on main thread
                    await MainActor.run {
                        showPermissionAlert(for: .microphone)
                    }
                }
            }

            // Check accessibility permission
            await MainActor.run {
                if !permissionManager.isAccessibilityPermissionGranted {
                    // Not mandatory, just prompt
                    print("⚠️ 辅助功能权限未授予，自动粘贴功能将不可用")
                }
            }
        }
    }
    
    private func showPermissionAlert(for permissionType: PermissionType) {
        let alert = NSAlert()
        alert.messageText = String(format: "alert.permission_required".localized, permissionType.displayName)
        alert.informativeText = permissionType.description
        alert.alertStyle = .warning
        alert.addButton(withTitle: "alert.open_system_settings".localized)
        alert.addButton(withTitle: "alert.later".localized)

        if alert.runModal() == .alertFirstButtonReturn {
            permissionManager.openSystemPreferences(for: permissionType)
        }
    }
    
}

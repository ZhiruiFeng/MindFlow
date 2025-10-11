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
        // 显示 Dock 图标，作为普通应用运行
        NSApplication.shared.setActivationPolicy(.regular)

        // 注册全局热键
        setupHotKey()

        // 检查权限
        checkPermissions()

        print("✅ MindFlow 启动成功")
    }

    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // 注册默认热键: Cmd+Shift+V
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
            // 检查麦克风权限
            if !permissionManager.isMicrophonePermissionGranted {
                let granted = await permissionManager.requestMicrophonePermission()
                if !granted {
                    // 必须在主线程上显示 Alert
                    await MainActor.run {
                        showPermissionAlert(for: .microphone)
                    }
                }
            }
            
            // 检查辅助功能权限
            await MainActor.run {
                if !permissionManager.isAccessibilityPermissionGranted {
                    // 不强制要求，只提示
                    print("⚠️ 辅助功能权限未授予，自动粘贴功能将不可用")
                }
            }
        }
    }
    
    private func showPermissionAlert(for permissionType: PermissionType) {
        let alert = NSAlert()
        alert.messageText = "需要\(permissionType.displayName)权限"
        alert.informativeText = permissionType.description
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        
        if alert.runModal() == .alertFirstButtonReturn {
            permissionManager.openSystemPreferences(for: permissionType)
        }
    }
    
}

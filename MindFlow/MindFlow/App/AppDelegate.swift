//
//  AppDelegate.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var settingsWindow: NSWindow?
    var recordingWindow: NSWindow?
    
    // Managers
    let hotKeyManager = HotKeyManager.shared
    let permissionManager = PermissionManager.shared
    let settings = Settings.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        setupMenuBar()
        
        // 注册全局热键
        setupHotKey()
        
        // 检查权限
        checkPermissions()
        
        print("✅ MindFlow 启动成功")
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "MindFlow")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "开始录音", action: #selector(startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于 MindFlow", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // 注册默认热键: Cmd+Shift+V
        // cmdKey = 0x0100 (256), shiftKey = 0x0200 (512)
        let modifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        hotKeyManager.registerHotKey(keyCode: 9, modifiers: modifiers) { [weak self] in
            self?.startRecording()
        }
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
    
    // MARK: - Actions
    
    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.close()
        } else {
            startRecording()
        }
    }
    
    @objc func startRecording() {
        // 关闭已有的录音窗口
        recordingWindow?.close()
        
        // 创建录音视图
        let contentView = RecordingView()
        
        // 创建托管视图
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 500)
        
        // 创建窗口 - 增加高度以显示所有控件
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MindFlow - 录音"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        window.minSize = NSSize(width: 400, height: 450)  // 设置最小尺寸
        
        recordingWindow = window
        
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openSettings() {
        // 关闭已有的设置窗口
        settingsWindow?.close()
        
        // 创建设置视图
        let contentView = SettingsView()
        
        // 创建托管视图
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MindFlow - 设置"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        settingsWindow = window
        
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MindFlow"
        alert.informativeText = """
        版本 1.0.0
        
        一款智能的 macOS 语音转文字助手
        让文字输入更高效
        
        © 2025 MindFlow
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}


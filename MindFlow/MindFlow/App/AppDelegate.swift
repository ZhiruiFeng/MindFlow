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
    var mainWindow: NSWindow?

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
            button.action = #selector(toggleMainWindow)
            button.target = self
        }

        // 创建右键菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "关于 MindFlow", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        // 设置右键菜单
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // 注册默认热键: Cmd+Shift+V
        // cmdKey = 0x0100 (256), shiftKey = 0x0200 (512)
        let modifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        hotKeyManager.registerHotKey(keyCode: 9, modifiers: modifiers) { [weak self] in
            self?.openMainWindow()
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

    @objc private func toggleMainWindow(_ sender: NSStatusBarButton?) {
        // 检测鼠标事件类型
        guard let event = NSApp.currentEvent else {
            openMainWindow()
            return
        }

        if event.type == .rightMouseUp {
            // 右键：显示菜单
            if let button = statusItem?.button {
                let menu = createRightClickMenu()
                statusItem?.menu = menu
                button.performClick(nil)
                statusItem?.menu = nil
            }
        } else {
            // 左键：打开/关闭主窗口
            if let window = mainWindow, window.isVisible {
                window.close()
            } else {
                openMainWindow()
            }
        }
    }

    private func createRightClickMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "关于 MindFlow", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    @objc func openMainWindow() {
        // 如果窗口已存在，直接显示并激活
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建主视图
        let contentView = MainView()

        // 创建托管视图
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 600)

        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "MindFlow"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.minSize = NSSize(width: 500, height: 600)

        mainWindow = window

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


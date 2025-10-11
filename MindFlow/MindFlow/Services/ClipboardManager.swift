//
//  ClipboardManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import AppKit
import ApplicationServices

/// 剪贴板管理器
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    // MARK: - Copy
    
    /// 复制文本到剪贴板
    func copy(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("✅ 已复制到剪贴板: \(text.prefix(30))...")
    }
    
    // MARK: - Paste
    
    /// 自动粘贴（需要辅助功能权限）
    func paste() {
        guard PermissionManager.shared.accessibilityPermissionGranted else {
            print("⚠️ 没有辅助功能权限，无法自动粘贴")
            return
        }
        
        // 模拟 Cmd+V 键盘事件
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.simulateCmdV()
        }
    }
    
    /// 模拟 Cmd+V 快捷键
    private func simulateCmdV() {
        // 创建按下 Cmd 键的事件
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        // 创建按下 V 键的事件
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        
        // 创建释放 V 键的事件
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        // 创建释放 Cmd 键的事件
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)
        
        // 按顺序发送事件
        let location = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: location)
        vDown?.post(tap: location)
        vUp?.post(tap: location)
        cmdUp?.post(tap: location)
        
        print("✅ 已自动粘贴")
    }
    
    // MARK: - Read
    
    /// 从剪贴板读取文本
    func readText() -> String? {
        return pasteboard.string(forType: .string)
    }
}


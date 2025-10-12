//
//  ClipboardManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import AppKit
import ApplicationServices

/// Clipboard manager
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    // MARK: - Copy
    
    /// Copy text to clipboard
    func copy(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("✅ Copied to clipboard, length: \(text.count) characters")
    }
    
    // MARK: - Paste
    
    /// Auto-paste (requires accessibility permission)
    func paste() {
        guard PermissionManager.shared.isAccessibilityPermissionGranted else {
            print("⚠️ 没有辅助功能权限，无法自动粘贴")
            return
        }

        // Simulate Cmd+V keyboard event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.simulateCmdV()
        }
    }
    
    /// Simulate Cmd+V shortcut
    private func simulateCmdV() {
        // Create Cmd key down event
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        // Create V key down event
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        // Create V key up event
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // Create Cmd key up event
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)

        // Send events in order
        let location = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: location)
        vDown?.post(tap: location)
        vUp?.post(tap: location)
        cmdUp?.post(tap: location)
        
        print("✅ 已自动粘贴")
    }
    
    // MARK: - Read
    
    /// Read text from clipboard
    func readText() -> String? {
        return pasteboard.string(forType: .string)
    }
}


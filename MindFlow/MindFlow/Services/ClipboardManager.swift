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
        Logger.info("Copied to clipboard, length: \(text.count) characters", category: .general)
    }
    
    // MARK: - Paste
    
    /// Auto-paste (requires accessibility permission)
    func paste() {
        // Re-verify accessibility trust at call time rather than relying on a
        // possibly-stale cached value, since the user may have revoked/granted
        // the permission after the cached value was computed.
        guard AXIsProcessTrusted() else {
            Logger.warning("Accessibility permission not granted — cannot auto-paste", category: .general)
            return
        }

        // Simulate Cmd+V keyboard event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.simulateCmdV()
        }
    }

    /// Simulate Cmd+V shortcut
    private func simulateCmdV() {
        // Use a dedicated HID-system event source so the synthetic events are
        // posted consistently regardless of the current event state.
        let source = CGEventSource(stateID: .hidSystemState)

        // Create Cmd key down event
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        // Create V key down event (explicitly set the command flag)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        // Create V key up event (explicitly set the command flag)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // Create Cmd key up event
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        // Send events in order
        let location = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: location)
        vDown?.post(tap: location)
        vUp?.post(tap: location)
        cmdUp?.post(tap: location)

        Logger.info("Auto-pasted via synthetic Cmd+V", category: .general)
    }
    
    // MARK: - Read
    
    /// Read text from clipboard
    func readText() -> String? {
        return pasteboard.string(forType: .string)
    }
}


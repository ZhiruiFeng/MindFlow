//
//  HotKeyManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import Carbon
import AppKit

/// Global hotkey manager
class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotKeyCallback: (() -> Void)?
    
    private init() {}
    
    // MARK: - Register HotKey
    
    /// Register global hotkey
    /// - Parameters:
    ///   - keyCode: Key code (e.g., 9 = V)
    ///   - modifiers: Modifier keys (e.g., cmdKey | shiftKey)
    ///   - callback: Callback when hotkey is pressed
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        // Unregister existing hotkey first
        unregisterHotKey()

        // Save callback
        hotKeyCallback = callback

        // Create hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D464C57) // "MFLW"
        hotKeyID.id = 1

        // Create event type
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                HotKeyManager.shared.handleHotKeyEvent()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Register hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("✅ Global hotkey registered successfully: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            print("❌ Global hotkey registration failed: \(status)")
        }
    }
    
    /// Unregister global hotkey
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            print("✅ Global hotkey unregistered")
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        hotKeyCallback = nil
    }
    
    // MARK: - Event Handler
    
    private func handleHotKeyEvent() {
        print("🔥 Hotkey triggered")
        DispatchQueue.main.async {
            self.hotKeyCallback?()
        }
    }
    
    deinit {
        unregisterHotKey()
    }
}

// MARK: - Key Codes Reference

/*
 Common key code reference:

 Letter keys:
 A = 0x00
 S = 0x01
 D = 0x02
 V = 0x09

 Modifier keys:
 cmdKey = 0x0100 (Command/⌘)
 shiftKey = 0x0200 (Shift)
 optionKey = 0x0800 (Option/⌥)
 controlKey = 0x1000 (Control)

 Combination examples:
 Cmd+Shift+V = keyCode: 9, modifiers: cmdKey | shiftKey
 */


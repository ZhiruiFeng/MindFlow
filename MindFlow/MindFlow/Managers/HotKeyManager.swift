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

        // Install event handler. Pass `self` as userData so the C trampoline can
        // recover the exact instance instead of hard-coding `.shared`.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                if let userData = userData {
                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    manager.handleHotKeyEvent()
                } else {
                    // Fallback to the shared instance if userData is unexpectedly nil.
                    HotKeyManager.shared.handleHotKeyEvent()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        guard installStatus == noErr else {
            Logger.error("Global hotkey: InstallEventHandler failed: \(installStatus)", category: .general)
            // Clean up any partially-installed state.
            eventHandler = nil
            hotKeyCallback = nil
            return
        }

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
            Logger.info("Global hotkey registered successfully: keyCode=\(keyCode), modifiers=\(modifiers)", category: .general)
        } else {
            Logger.error("Global hotkey registration failed: \(status)", category: .general)
            // Roll back the installed event handler so we don't leave a
            // half-installed state.
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            hotKeyRef = nil
            hotKeyCallback = nil
        }
    }
    
    /// Unregister global hotkey
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            Logger.info("Global hotkey unregistered", category: .general)
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        hotKeyCallback = nil
    }
    
    // MARK: - Event Handler
    
    private func handleHotKeyEvent() {
        Logger.debug("Hotkey triggered", category: .general)
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


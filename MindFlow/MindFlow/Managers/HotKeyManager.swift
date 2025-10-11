//
//  HotKeyManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import Carbon
import AppKit

/// 全局热键管理器
class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotKeyCallback: (() -> Void)?
    
    private init() {}
    
    // MARK: - Register HotKey
    
    /// 注册全局热键
    /// - Parameters:
    ///   - keyCode: 按键代码（例如：9 = V）
    ///   - modifiers: 修饰键（例如：cmdKey | shiftKey）
    ///   - callback: 按下热键时的回调
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        // 先注销已有的热键
        unregisterHotKey()
        
        // 保存回调
        hotKeyCallback = callback
        
        // 创建热键 ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D464C57) // "MFLW"
        hotKeyID.id = 1
        
        // 创建事件类型
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器
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
        
        // 注册热键
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("✅ 全局热键注册成功: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            print("❌ 全局热键注册失败: \(status)")
        }
    }
    
    /// 注销全局热键
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            print("✅ 全局热键已注销")
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        hotKeyCallback = nil
    }
    
    // MARK: - Event Handler
    
    private func handleHotKeyEvent() {
        print("🔥 热键被触发")
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
 常用按键代码参考：
 
 字母键：
 A = 0x00
 S = 0x01
 D = 0x02
 V = 0x09
 
 修饰键：
 cmdKey = 0x0100 (Command/⌘)
 shiftKey = 0x0200 (Shift)
 optionKey = 0x0800 (Option/⌥)
 controlKey = 0x1000 (Control)
 
 组合示例：
 Cmd+Shift+V = keyCode: 9, modifiers: cmdKey | shiftKey
 */


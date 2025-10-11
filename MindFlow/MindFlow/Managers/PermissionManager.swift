//
//  PermissionManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import AVFoundation
import ApplicationServices
import AppKit

/// 权限管理器 - 处理麦克风和辅助功能权限
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var isMicrophonePermissionGranted = false
    @Published var isAccessibilityPermissionGranted = false
    
    private init() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }
    
    // MARK: - Microphone Permission
    
    /// 检查麦克风权限状态
    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            isMicrophonePermissionGranted = true
        case .notDetermined, .denied, .restricted:
            isMicrophonePermissionGranted = false
        @unknown default:
            isMicrophonePermissionGranted = false
        }
    }
    
    /// 请求麦克风权限
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            self.isMicrophonePermissionGranted = granted
        }
        return granted
    }
    
    // MARK: - Accessibility Permission
    
    /// 检查辅助功能权限状态
    func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityPermissionGranted = AXIsProcessTrustedWithOptions(options)
    }
    
    /// 请求辅助功能权限（会打开系统设置）
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        
        // 延迟一会儿后重新检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }
    
    /// 打开系统偏好设置中的隐私设置
    func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .microphone:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Combined Check
    
    /// 检查所有必需的权限
    func checkAllPermissions() -> (microphone: Bool, accessibility: Bool) {
        checkMicrophonePermission()
        checkAccessibilityPermission()
        return (isMicrophonePermissionGranted, isAccessibilityPermissionGranted)
    }
}

// MARK: - Permission Type

enum PermissionType {
    case microphone
    case accessibility
    
    var displayName: String {
        switch self {
        case .microphone: return "麦克风"
        case .accessibility: return "辅助功能"
        }
    }
    
    var description: String {
        switch self {
        case .microphone:
            return "MindFlow 需要访问麦克风以录制您的语音。"
        case .accessibility:
            return "MindFlow 需要辅助功能权限以实现全局热键和自动粘贴功能。如果不授予此权限，您仍可以使用应用，但需要手动复制文本。"
        }
    }
}


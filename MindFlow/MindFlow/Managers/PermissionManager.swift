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

/// Permission manager - handles microphone and accessibility permissions
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var isMicrophonePermissionGranted = false
    @Published var isAccessibilityPermissionGranted = false
    
    private init() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }
    
    // MARK: - Microphone Permission
    
    /// Check microphone permission status
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
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            self.isMicrophonePermissionGranted = granted
        }
        return granted
    }
    
    // MARK: - Accessibility Permission
    
    /// Check accessibility permission status
    func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityPermissionGranted = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Request accessibility permission (will open System Settings)
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // Recheck after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }
    
    /// Open privacy settings in System Preferences
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
    
    /// Check all required permissions
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
        case .microphone: return "permission.microphone".localized
        case .accessibility: return "permission.accessibility".localized
        }
    }

    var description: String {
        switch self {
        case .microphone:
            return "permission.microphone_description".localized
        case .accessibility:
            return "permission.accessibility_description".localized
        }
    }
}


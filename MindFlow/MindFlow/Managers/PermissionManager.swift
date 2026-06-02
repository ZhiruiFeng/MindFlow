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
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            granted = true
        case .notDetermined, .denied, .restricted:
            granted = false
        @unknown default:
            granted = false
        }
        // Mutate the @Published property on the main thread to avoid a data race.
        if Thread.isMainThread {
            isMicrophonePermissionGranted = granted
        } else {
            DispatchQueue.main.async { self.isMicrophonePermissionGranted = granted }
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
        let granted = AXIsProcessTrustedWithOptions(options)
        // Mutate the @Published property on the main thread to avoid a data race.
        if Thread.isMainThread {
            isAccessibilityPermissionGranted = granted
        } else {
            DispatchQueue.main.async { self.isAccessibilityPermissionGranted = granted }
        }
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
        // Refresh the @Published properties (these hop to the main thread).
        checkMicrophonePermission()
        checkAccessibilityPermission()

        // Compute the current values directly so the return value is accurate
        // even when the published-property updates are dispatched asynchronously.
        let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let axOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axGranted = AXIsProcessTrustedWithOptions(axOptions)
        return (micGranted, axGranted)
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


//
//  RecordingKeyboardManager.swift
//  MindFlow
//
//  Created on 2025-10-13.
//

import Foundation
import AppKit
import Carbon

/// Manages keyboard shortcuts for recording (fn+shift press to start, release to stop)
class RecordingKeyboardManager {
    static let shared = RecordingKeyboardManager()

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var isRecording = false
    private var recordingCallback: ((Bool) -> Void)?

    /// Whether the process is currently trusted for global event monitoring.
    /// When false, the global (system-wide) fn+shift shortcut will silently not
    /// fire while other apps are focused. Exposed so callers can surface this.
    private(set) var isGlobalMonitoringTrusted = false

    private init() {}

    // MARK: - Setup

    /// Start monitoring for fn+shift key combination
    /// - Parameter callback: Callback with true for start recording, false for stop recording
    func startMonitoring(callback: @escaping (Bool) -> Void) {
        stopMonitoring()

        recordingCallback = callback

        // Monitor for flags changed events - LOCAL (when app is focused)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
            return event
        }

        // Monitor for flags changed events - GLOBAL (system-wide, even when app is not focused)
        // Note: This requires Accessibility permissions
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }

        // Verify the process is trusted for input monitoring / accessibility.
        // The global monitor is installed regardless, but it will silently
        // receive no events when untrusted — surface a clear warning so a
        // broken global shortcut is detectable.
        isGlobalMonitoringTrusted = AXIsProcessTrusted()
        if !isGlobalMonitoringTrusted {
            Logger.warning("RecordingKeyboardManager: process is NOT trusted for input monitoring/accessibility — the global (system-wide) fn+shift shortcut will not fire while other apps are focused. Grant Accessibility permission in System Settings.", category: .general)
        }

        Logger.info("RecordingKeyboardManager started monitoring fn+shift (local + global, globalTrusted=\(isGlobalMonitoringTrusted))", category: .general)
    }

    /// Stop monitoring keyboard events
    func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        // If currently recording, stop it
        if isRecording {
            isRecording = false
            recordingCallback?(false)
        }

        Logger.info("RecordingKeyboardManager stopped monitoring", category: .general)
    }

    // MARK: - Event Handling

    private func handleFlagsChanged(event: NSEvent) {
        let flags = event.modifierFlags

        // Check if fn+shift are pressed
        // fn key is represented by .function modifier
        // shift is represented by .shift modifier
        let isFnShiftPressed = flags.contains(.function) && flags.contains(.shift)

        if isFnShiftPressed && !isRecording {
            // Start recording
            isRecording = true
            Logger.debug("fn+shift pressed - Starting recording", category: .recording)
            recordingCallback?(true)
        } else if !isFnShiftPressed && isRecording {
            // Stop recording (either key released)
            isRecording = false
            Logger.debug("fn+shift released - Stopping recording", category: .recording)
            recordingCallback?(false)
        }
    }

    deinit {
        stopMonitoring()
    }
}

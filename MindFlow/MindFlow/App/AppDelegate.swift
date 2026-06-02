//
//  AppDelegate.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    // Managers
    let hotKeyManager = HotKeyManager.shared
    let recordingKeyboardManager = RecordingKeyboardManager.shared
    let permissionManager = PermissionManager.shared
    let settings = Settings.shared

    // Vocabulary notification timer
    private var reviewReminderTimer: Timer?

    // Whether the user authorized user-notification delivery. Review reminders
    // are only scheduled when this is true.
    private var isNotificationAuthorized = false

    // Stable identifier so a newly scheduled review reminder replaces the prior
    // one instead of stacking up multiple notifications.
    private static let reviewReminderIdentifier = "vocabulary-review-reminder"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show Dock icon, run as normal application
        NSApplication.shared.setActivationPolicy(.regular)

        // In UI-test mode, skip hotkey registration, permission prompts, and
        // review reminders so automated screenshots are deterministic and no
        // system modal blocks the window.
        if !LaunchMode.isUITesting {
            // Register global hotkey
            setupHotKey()

            // Setup recording keyboard shortcuts (fn+shift)
            setupRecordingKeyboard()

            // Check permissions
            checkPermissions()

            // Setup vocabulary review reminders
            setupReviewReminders()
        }

        print("✅ MindFlow 启动成功")
    }

    // Keep app running even if all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in Dock
    }

    // When user clicks Dock icon, reopen the main window if none is visible
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        }
        return true
    }

    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // Register the global hotkey ⌘⇧V — the single "press-to-talk" shortcut.
        // cmdKey = 0x0100 (256), shiftKey = 0x0200 (512)
        let modifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        hotKeyManager.registerHotKey(keyCode: 9, modifiers: modifiers) { [weak self] in
            self?.toggleRecordingViaHotKey()
        }
    }

    /// ⌘⇧V toggles recording: open/focus the window, then start or stop based on
    /// the current state. This makes the marquee global shortcut do the core
    /// action directly instead of merely activating the app.
    private func toggleRecordingViaHotKey() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showMainWindow, object: nil)
        NotificationCenter.default.post(name: .switchToRecordingTab, object: nil)
        // Let the window come forward (and recreate the recording view model if
        // it was closed) before toggling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if AppStatus.shared.isRecording {
                NotificationCenter.default.post(name: .stopRecordingShortcut, object: nil)
            } else {
                NotificationCenter.default.post(name: .startRecordingShortcut, object: nil)
            }
        }
    }

    // MARK: - Recording Keyboard Setup

    private func setupRecordingKeyboard() {
        recordingKeyboardManager.startMonitoring { [weak self] shouldStartRecording in
            self?.handleRecordingShortcut(start: shouldStartRecording)
        }
    }

    private func handleRecordingShortcut(start: Bool) {
        // Only show window and start recording when pressing the shortcut
        if start {
            // Bring the main window forward (handled by the SwiftUI menu-bar bridge)
            NotificationCenter.default.post(name: .showMainWindow, object: nil)

            // Switch to recording tab
            NotificationCenter.default.post(name: .switchToRecordingTab, object: nil)

            // Small delay to ensure UI is ready, then start recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .startRecordingShortcut, object: nil)
            }
        } else {
            // Just stop recording, keep window open
            NotificationCenter.default.post(name: .stopRecordingShortcut, object: nil)
        }
    }

    // MARK: - Permissions
    
    private func checkPermissions() {
        Task {
            // Check microphone permission
            if !permissionManager.isMicrophonePermissionGranted {
                let granted = await permissionManager.requestMicrophonePermission()
                if !granted {
                    // Must show Alert on main thread
                    await MainActor.run {
                        showPermissionAlert(for: .microphone)
                    }
                }
            }

            // Check accessibility permission (required for global keyboard shortcuts)
            await MainActor.run {
                if !permissionManager.isAccessibilityPermissionGranted {
                    print("⚠️ Accessibility permission not granted - global keyboard shortcuts (fn+shift) won't work when other apps are focused")

                    // Show alert to guide user to enable accessibility
                    let alert = NSAlert()
                    alert.messageText = "Enable Global Keyboard Shortcuts"
                    alert.informativeText = "To use fn+shift shortcuts when other apps are focused, MindFlow needs Accessibility permission.\n\nGo to: System Settings → Privacy & Security → Accessibility → Enable MindFlow"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Later")

                    if alert.runModal() == .alertFirstButtonReturn {
                        permissionManager.openSystemPreferences(for: .accessibility)
                    }
                }
            }
        }
    }
    
    private func showPermissionAlert(for permissionType: PermissionType) {
        let alert = NSAlert()
        alert.messageText = String(format: "alert.permission_required".localized, permissionType.displayName)
        alert.informativeText = permissionType.description
        alert.alertStyle = .warning
        alert.addButton(withTitle: "alert.open_system_settings".localized)
        alert.addButton(withTitle: "alert.later".localized)

        if alert.runModal() == .alertFirstButtonReturn {
            permissionManager.openSystemPreferences(for: permissionType)
        }
    }

    // MARK: - Vocabulary Review Reminders

    private func setupReviewReminders() {
        // Request notification permission
        requestNotificationPermission()

        // Check for words due for review periodically (every hour)
        reviewReminderTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkAndNotifyReviewDue()
        }

        // Check immediately on launch (with delay to ensure Core Data is ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkAndNotifyReviewDue()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            // Store the granted result so we can skip scheduling reminders when
            // the user has not authorized notifications.
            self?.isNotificationAuthorized = granted
            if granted {
                Logger.info("Notification permission granted", category: .general)
            } else if let error = error {
                Logger.error("Notification permission error", category: .general, error: error)
            } else {
                Logger.warning("Notification permission denied", category: .general)
            }
        }
    }

    private func checkAndNotifyReviewDue() {
        let dueWords = VocabularyStorage.shared.fetchWordsDueForReview()
        let dueCount = dueWords.count

        // Keep the menu-bar review badge in sync regardless of whether
        // notification reminders are enabled.
        Task { @MainActor in
            AppStatus.shared.dueReviewCount = dueCount
        }

        guard settings.vocabularyReviewRemindersEnabled else { return }
        guard dueCount > 0 else { return }
        // Don't schedule reminders if the user hasn't authorized notifications.
        guard isNotificationAuthorized else { return }

        // Create notification
        let content = UNMutableNotificationContent()
        content.title = "Vocabulary Review"
        content.body = dueCount == 1
            ? "You have 1 word due for review"
            : "You have \(dueCount) words due for review"
        content.sound = .default
        content.categoryIdentifier = "VOCABULARY_REVIEW"

        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request with a stable identifier so a new reminder replaces the
        // prior one instead of stacking.
        let request = UNNotificationRequest(
            identifier: AppDelegate.reviewReminderIdentifier,
            content: content,
            trigger: trigger
        )

        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule notification", category: .general, error: error)
            } else {
                Logger.info("Review reminder notification scheduled (\(dueCount) words due)", category: .general)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timer
        reviewReminderTimer?.invalidate()
        reviewReminderTimer = nil
    }
}

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show Dock icon, run as normal application
        NSApplication.shared.setActivationPolicy(.regular)

        // Register global hotkey
        setupHotKey()

        // Setup recording keyboard shortcuts (fn+shift)
        setupRecordingKeyboard()

        // Check permissions
        checkPermissions()

        // Setup vocabulary review reminders
        setupReviewReminders()

        print("✅ MindFlow 启动成功")
    }

    // Keep app running even if all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in Dock
    }

    // When user clicks Dock icon, reopen window if no windows exist
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows - create/show a window
            showAndFocusWindow()
        }
        return true
    }

    
    // MARK: - Hot Key Setup
    
    private func setupHotKey() {
        // Register default hotkey: Cmd+Shift+V
        // cmdKey = 0x0100 (256), shiftKey = 0x0200 (512)
        let modifiers: UInt32 = 0x0100 | 0x0200  // Cmd + Shift
        hotKeyManager.registerHotKey(keyCode: 9, modifiers: modifiers) { [weak self] in
            self?.activateApp()
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
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
            showAndFocusWindow()

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

    /// Show and bring window to front, even if minimized or hidden
    private func showAndFocusWindow() {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Try to find an existing window (excluding panels and other non-main windows)
        let mainWindows = NSApp.windows.filter { window in
            // Filter for actual app windows (not system panels, sheets, etc)
            return window.canBecomeKey &&
                   !window.title.isEmpty &&
                   (window.isVisible || window.isMiniaturized)
        }

        if let mainWindow = mainWindows.first {
            // If minimized, deminiaturize
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }

            // Make it key and bring to front
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
            print("✅ Window restored and brought to front")
        } else {
            // Try ANY window as fallback
            if let anyWindow = NSApp.windows.first(where: { $0.canBecomeKey }) {
                anyWindow.makeKeyAndOrderFront(nil)
                anyWindow.orderFrontRegardless()
                print("✅ Fallback: Window shown")
            } else {
                // No window exists at all - need to create one
                // This can happen if user closed the window with Cmd+W
                print("⚠️ No window found - creating new window programmatically")

                createNewWindow()
            }
        }
    }

    /// Create a new window programmatically when all windows are closed
    private func createNewWindow() {
        // For SwiftUI WindowGroup apps, triggering a new window is tricky
        // Best approach: Use KeyEquivalent for Cmd+N which triggers new window

        // Method 1: Try the standard new window action
        let newWindowSelector = NSSelectorFromString("newDocument:")
        if NSApp.responds(to: newWindowSelector) {
            NSApp.perform(newWindowSelector, with: nil)
            print("✅ Sent newDocument action")
        }

        // Method 2: Try newWindowForTab
        NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)

        // Give it a moment to create the window, then activate it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                print("✅ New window created and activated")
            } else {
                print("❌ Failed to create window - user may need to click the Dock icon")

                // Show notification to user
                self.showWindowCreationFailedNotification()
            }
        }
    }

    /// Show a system notification when window creation fails
    private func showWindowCreationFailedNotification() {
        let notification = NSUserNotification()
        notification.title = "MindFlow"
        notification.informativeText = "Please click the MindFlow icon in the Dock to open the window"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }

    private func checkAndNotifyReviewDue() {
        guard settings.vocabularyReviewRemindersEnabled else { return }

        let dueWords = VocabularyStorage.shared.fetchWordsDueForReview()
        let dueCount = dueWords.count

        guard dueCount > 0 else { return }

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

        // Create request
        let request = UNNotificationRequest(
            identifier: "vocabulary-review-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("📢 Review reminder notification scheduled (\(dueCount) words due)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timer
        reviewReminderTimer?.invalidate()
        reviewReminderTimer = nil
    }
}

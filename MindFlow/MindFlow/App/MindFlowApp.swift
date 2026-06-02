//
//  MindFlowApp.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import SwiftUI

/// App-wide status shared with the menu bar.
///
/// The recording view model lives inside the main window (and is deallocated
/// when that window closes), so the always-present menu bar can't observe it
/// directly. This lightweight singleton mirrors the bits the menu needs:
/// whether a recording is active, whether the app is busy processing, and how
/// many vocabulary words are due for review.
@MainActor
final class AppStatus: ObservableObject {
    static let shared = AppStatus()

    @Published var isRecording = false
    @Published var isBusy = false
    @Published var dueReviewCount = 0

    private init() {}

    /// Mirror the recording view model's state.
    func update(from state: TranscriptionState) {
        switch state {
        case .recording:
            isRecording = true; isBusy = false
        case .processing, .transcribing, .optimizing:
            isRecording = false; isBusy = true
        case .completed:
            isRecording = false; isBusy = false
            refreshDueReviewCount()   // a finished session may add new words
        case .idle, .error:
            isRecording = false; isBusy = false
        }
    }

    /// Recompute how many words are due for review.
    func refreshDueReviewCount() {
        dueReviewCount = VocabularyStorage.shared.fetchWordsDueForReview().count
    }
}

/// Launch-time mode detection.
///
/// `-uiTestMode` is passed by the UI-test screenshot harness so the app starts
/// in a deterministic state: the login gate is bypassed and the startup
/// permission/notification prompts are suppressed, so they can't block or
/// pollute automated screenshots. It has no effect on a normal launch.
enum LaunchMode {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestMode")
    }
}

@main
struct MindFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = SupabaseAuthService()
    @StateObject private var settings = Settings.shared

    var body: some Scene {
        // MARK: - Main workspace window (Record · Library · Vocabulary)
        // A single `Window` (not `WindowGroup`) so there is exactly one main
        // window that `openWindow(id: "main")` reliably opens or re-focuses.
        Window("MindFlow", id: "main") {
            ContentView()
                .environmentObject(authService)
                .environmentObject(settings)
                .frame(minWidth: 720, minHeight: 560)
        }
        .commands {
            // This app has no document model, so remove the default "New" command.
            CommandGroup(replacing: .newItem) { }

            // Settings now lives inside the main window as a sidebar tab rather
            // than a separate window. Keep the standard ⌘, app-menu item, but
            // route it to the main window and select the Settings tab. The
            // menu-bar extra is always alive and observes `.showMainWindow`, so
            // it reliably opens/focuses the window even when it was closed.
            CommandGroup(replacing: .appSettings) {
                Button("tab.settings".localized) {
                    NotificationCenter.default.post(name: .showMainWindow, object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .defaultSize(width: 760, height: 640)

        // MARK: - Menu bar item — the quick-access home for a capture utility.
        // The label hosts a bridge so AppKit (global hotkey) can ask SwiftUI to
        // open the main window via the same reliable path the menu uses.
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(authService)
                .environmentObject(settings)
        } label: {
            MenuBarLabel()
        }
    }

    // MARK: - Root content (login gate)

    @MainActor
    struct ContentView: View {
        @EnvironmentObject private var authService: SupabaseAuthService
        @EnvironmentObject private var settings: Settings
        @State private var isInitialized = false

        var body: some View {
            Group {
                if isInitialized {
                    if settings.hasCompletedLoginFlow || LaunchMode.isUITesting {
                        MainView()
                    } else {
                        LoginView()
                    }
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                // In UI-test mode, skip the (network) session restore so the
                // workspace renders immediately and deterministically.
                if LaunchMode.isUITesting {
                    isInitialized = true
                    return
                }
                Task {
                    await authService.restoreSession()
                    isInitialized = true
                }
            }
        }
    }
}

// MARK: - Menu Bar

/// The status-bar icon. Doubles as an always-alive bridge so AppKit code (the
/// global hotkey, Dock re-open) can ask SwiftUI to open the main window through
/// the same reliable `openWindow` path the menu uses — instead of hunting
/// `NSApp.windows`, which could surface the Settings window by mistake.
struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var status = AppStatus.shared

    var body: some View {
        icon
            .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
    }

    /// Reflects live state: red record dot while recording, a busy glyph while
    /// processing, the mic otherwise.
    @ViewBuilder
    private var icon: some View {
        if status.isRecording {
            Image(systemName: "record.circle.fill")
                .symbolRenderingMode(.multicolor)   // renders red
        } else if status.isBusy {
            Image(systemName: "waveform.circle")
        } else {
            Image(systemName: "mic.fill")
        }
    }
}

/// Content shown when the user clicks the menu bar icon.
///
/// For a menu-bar capture utility this is the primary entry point: start/stop a
/// recording, jump into a due review, open the workspace, Settings, or quit.
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var status = AppStatus.shared

    var body: some View {
        // Live status line (disabled — informational).
        Text(statusText).disabled(true)

        Divider()

        // Hero action: toggles recording. ⌘⇧V is shown here for discoverability;
        // because a menu-bar-extra key equivalent is only live while the menu is
        // open, it does not clash with the global Carbon hotkey of the same combo.
        if status.isRecording {
            Button("Stop Recording") { stopRecording() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
        } else {
            Button("Start Recording") { startRecording() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(status.isBusy)
        }

        // Review deep link — only when something is due.
        if status.dueReviewCount > 0 {
            Button("Review \(status.dueReviewCount) " +
                   (status.dueReviewCount == 1 ? "Word…" : "Words…")) {
                openReview()
            }
        }

        Button("Open MindFlow") { openMainWindow() }
            .keyboardShortcut("o", modifiers: .command)

        Divider()

        // ⌘, is owned by the app-menu Settings item, so it is not re-bound here
        // (a duplicate key equivalent would conflict). This opens the main
        // window and selects the in-window Settings tab.
        Button("Settings…") { openSettings() }

        Divider()

        Button("Quit MindFlow") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    private var statusText: String {
        if status.isRecording { return "● Recording…" }
        if status.isBusy { return "Processing…" }
        return "Ready to record"
    }

    // MARK: Actions

    /// Open / focus the single main window via the scene's reliable action.
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }

    private func startRecording() {
        openMainWindow()
        NotificationCenter.default.post(name: .switchToRecordingTab, object: nil)
        // Give the window a moment to come forward before kicking off capture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .startRecordingShortcut, object: nil)
        }
    }

    private func stopRecording() {
        NotificationCenter.default.post(name: .stopRecordingShortcut, object: nil)
    }

    private func openReview() {
        openMainWindow()
        NotificationCenter.default.post(name: .switchToVocabularyTab, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .startVocabularyReview, object: nil)
        }
    }

    /// Open the main window and select the in-window Settings tab.
    private func openSettings() {
        openMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
        }
    }
}

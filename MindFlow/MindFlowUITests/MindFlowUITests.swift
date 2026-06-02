//
//  MindFlowUITests.swift
//  MindFlowUITests
//
//  Automated visual-test / screenshot harness.
//
//  Run from the command line:
//    xcodebuild test -scheme MindFlow \
//      -destination 'platform=macOS' \
//      -only-testing:MindFlowUITests/MindFlowUITests/testCaptureAllScreens
//
//  PNGs are written to $MINDFLOW_SHOTS (if set) or ~/MindFlowShots, in addition
//  to being attached to the Xcode test report. Point a visual-diff tool — or a
//  reviewer — at that directory.
//

import XCTest

final class MindFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in deterministic UI-test mode and captures one
    /// screenshot per workspace screen.
    @MainActor
    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestMode"]
        app.launch()

        let dir = Self.outputDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // The workspace opens on the Record screen.
        // Canonical filenames follow the {screen}-{surface} convention used by
        // the sibling iOS apps (e.g. Collector's `explore-mobile.png`); here the
        // surface is `macos`.
        capture(app, name: "record-macos", into: dir)

        // Walk the sidebar destinations. Labels come from MainTab.title.
        let destinations: [(label: String, file: String)] = [
            ("Local", "local-history-macos"),
            ("History", "cloud-history-macos"),
            ("Vocabulary", "vocabulary-macos"),
        ]
        for dest in destinations {
            if selectSidebarItem(app, labeled: dest.label) {
                // Let the detail pane settle before capturing.
                usleep(400_000)
                capture(app, name: dest.file, into: dir)
            } else {
                XCTContext.runActivity(named: "Sidebar item '\(dest.label)' not found") { _ in }
            }
        }

        print("📸 Screenshots written to: \(dir.path)")
    }

    /// Interaction-driven UX test: drives the "Add Word" flow end to end —
    /// clicks the button, types into the field, switches to offline mode, saves,
    /// and asserts the new word appears in the list. A screenshot is captured at
    /// each step so the flow can be reviewed visually.
    ///
    /// Runs against an in-memory Core Data store (UI-test mode), so it never
    /// touches the user's real vocabulary.
    @MainActor
    func testVocabularyAddWordFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestMode"]
        app.launch()

        let dir = Self.outputDirectory().appendingPathComponent("flow-add-word", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 1. Go to the Vocabulary screen.
        XCTAssertTrue(selectSidebarItem(app, labeled: "Vocabulary"), "Could not open Vocabulary")
        capture(app, name: "01-vocabulary-empty", into: dir)

        // 2. Click "Add Word" — the sheet should open.
        let addButton = app.buttons["vocab.addWord"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Word button not found")
        addButton.click()

        let wordField = app.textFields["addWord.wordField"]
        XCTAssertTrue(wordField.waitForExistence(timeout: 5), "Add Word sheet did not open")
        capture(app, name: "02-sheet-open", into: dir)

        // 3. Type a word.
        let newWord = "serendipity"
        wordField.click()
        wordField.typeText(newWord)

        // 4. Switch to offline/manual entry so the flow doesn't hit the network.
        let manualToggle = app.checkBoxes["addWord.manualToggle"]
        if manualToggle.waitForExistence(timeout: 2) {
            manualToggle.click()
        }
        capture(app, name: "03-word-typed", into: dir)

        // 5. Save.
        let saveButton = app.buttons["addWord.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button not available")
        saveButton.click()

        // 6. Assert the sheet dismissed and the word is now in the list.
        XCTAssertTrue(
            waitForDisappearance(wordField, timeout: 5),
            "Sheet did not dismiss after saving"
        )
        let addedWord = app.staticTexts[newWord]
        XCTAssertTrue(
            addedWord.waitForExistence(timeout: 5),
            "Added word '\(newWord)' did not appear in the vocabulary list"
        )
        capture(app, name: "04-word-added", into: dir)

        print("📸 Add-Word flow screenshots written to: \(dir.path)")
    }

    // MARK: - Helpers

    /// Wait for an element to stop existing (e.g. a sheet to dismiss).
    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            usleep(100_000)
        }
        return !element.exists
    }

    /// Resolve the on-disk output directory for PNGs.
    private static func outputDirectory() -> URL {
        if let custom = ProcessInfo.processInfo.environment["MINDFLOW_SHOTS"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("MindFlowShots", isDirectory: true)
    }

    /// Capture the app's main window and record it two ways:
    ///  1. As an XCTAttachment (always works — survives the runner sandbox and is
    ///     harvestable from the .xcresult by Scripts/capture-screenshots.sh).
    ///  2. Best-effort direct PNG write to `dir` (works only when the runner is
    ///     unsandboxed; a sandbox denial is ignored, never fails the test).
    @MainActor
    private func capture(_ app: XCUIApplication, name: String, into dir: URL) {
        // Bring MindFlow to the front so we capture its window, not whatever
        // else is on screen, then prefer the window element over the whole app.
        app.activate()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 3)
        usleep(300_000)
        let shot = window.exists ? window.screenshot() : app.screenshot()

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Best effort — the sandboxed runner can't write outside its container.
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    /// Click a sidebar row by its visible label. Only ever clicks an element
    /// that is actually hittable — never a container like the sidebar ScrollView,
    /// which has no hit point and would throw.
    @MainActor
    private func selectSidebarItem(_ app: XCUIApplication, labeled label: String) -> Bool {
        app.activate()
        let candidates: [XCUIElement] = [
            app.outlines.staticTexts[label],
            app.staticTexts[label],
            app.outlines.buttons[label],
            app.buttons[label],
            app.cells.containing(.staticText, identifier: label).firstMatch,
        ]
        for element in candidates {
            if element.exists && element.isHittable {
                element.click()
                return true
            }
        }
        return false
    }
}

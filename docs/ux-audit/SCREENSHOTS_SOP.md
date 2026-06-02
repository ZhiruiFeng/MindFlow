# Screenshot Management SOP (MindFlow / macOS)

**Version**: 1.0 | **Updated**: 2026-06-02

Keeps "what the MindFlow macOS app actually looks like right now" in sync with the codebase, the same way the Anora/Collector apps track live iOS state.

---

## TL;DR

- **Canonical** lives in [docs/ux-audit/screenshots/](screenshots/) — committed, one file per screen, always overwrite.
- **Scratch** lives in `/screenshots/` (repo root) — gitignored. Iterate freely.
- After any UI change, run `Scripts/capture-screenshots.sh` to refresh the canonical captures.
- UI/UX review reads from canonical first; only re-capture when missing or stale.

---

## How this differs from the iOS apps (Anora / Collector)

The **discipline is identical** — two-tier scratch/canonical, fixed canonical names, refresh-on-UI-change. Only the **capture engine** differs, because MindFlow is a native **macOS** app:

| | Anora / Collector (iOS) | MindFlow (macOS) |
|---|---|---|
| Runs in iOS Simulator | ✅ | ❌ (AppKit lifecycle, Carbon hotkeys, CGEvent) |
| Capture command | `xcrun simctl io booted screenshot` | **XCUITest + `XCUIScreenshot`** |
| Navigation | Manual (navigate sim, then shoot) | **Automatic** (the test walks the sidebar) |
| Determinism hook | launch the build | `-uiTestMode` launch arg (bypass login, suppress permission prompts) |

There is no `simctl` screenshot path for macOS apps, so XCUITest is the native equivalent. It has the upside of auto-navigating instead of requiring a human to drive the UI first.

---

## Two-tier model

| Tier | Path | Purpose | Tracked |
|------|------|---------|---------|
| **Canonical** | [docs/ux-audit/screenshots/](screenshots/) | "Latest live state" per screen | **Committed** (overwrite; git history is the version log) |
| **Scratch** | `/screenshots/<YYYY-MM-DD>/` | Iteration, A/B, diff comparisons | Gitignored |

**Canonical filenames are fixed** — `{screen}-{surface}`, surface is always `macos` (matches Collector's `explore-mobile.png` convention):

```
docs/ux-audit/screenshots/
  ├── record-macos.png          # Record / capture screen
  ├── local-history-macos.png   # Local history
  ├── cloud-history-macos.png   # ZephyrOS cloud history
  └── vocabulary-macos.png      # Vocabulary library
```

No `-v2`, no dates, no variants. To compare against an old version: `git log -p -- docs/ux-audit/screenshots/`.

---

## Capture workflow

```bash
# Canonical refresh (default) → docs/ux-audit/screenshots/
Scripts/capture-screenshots.sh

# Scratch run → screenshots/<today>/  (gitignored)
Scripts/capture-screenshots.sh --scratch

# Explicit directory
Scripts/capture-screenshots.sh /tmp/some-dir
```

What it does:
1. Launches the app via XCUITest with `-uiTestMode` (deterministic: no login gate, no permission modals).
2. Captures the Record screen, then clicks each sidebar destination and captures it.
3. Writes PNGs to the chosen directory **and** attaches them to the Xcode test report.

Underlying command (if you prefer running it directly):

```bash
cd MindFlow
MINDFLOW_SHOTS=../docs/ux-audit/screenshots xcodebuild test \
  -scheme MindFlow -destination 'platform=macOS' \
  -only-testing:MindFlowUITests/MindFlowUITests/testCaptureAllScreens
```

### First-run permission (one time)

macOS UI testing requires an automation grant. The first run prompts:
**System Settings → Privacy & Security → Automation / Accessibility → allow Xcode**.
Grant once, then re-run. CI agents must have this pre-provisioned (otherwise the
runner is killed with *"signal kill before establishing connection"* — that's the
TCC gate, not a code failure).

---

## Adding a new screen

1. Add the destination to `MindFlowUITests.testCaptureAllScreens` (label + `{screen}-macos` filename).
2. Run `Scripts/capture-screenshots.sh`.
3. Commit the new canonical PNG alongside the code change.

---

## When to capture (the discipline)

**Rule: a UI PR is not done until the affected screen's canonical screenshot is refreshed.**

| Trigger | Action |
|---------|--------|
| Changed a SwiftUI view in `MindFlow/MindFlow/Views/` | `Scripts/capture-screenshots.sh`, commit the changed PNG(s) |
| Added a new screen | Add it to the harness, capture, commit |
| Removed a screen | Remove from harness + `git rm` its canonical PNG in the same PR |

**Reviewing UI/UX**: read canonical first. Only re-capture if a file is missing or you have evidence the screen drifted since the snapshot was last committed.

---

## Related

- [Scripts/capture-screenshots.sh](../../Scripts/capture-screenshots.sh) — the runner
- [MindFlow/MindFlowUITests/MindFlowUITests.swift](../../MindFlow/MindFlowUITests/MindFlowUITests.swift) — the XCUITest harness
- `-uiTestMode` hook — `MindFlow/MindFlow/App/MindFlowApp.swift` (`LaunchMode`) + `AppDelegate.swift`
- Anora's original pattern — `Anora/product-ux/docs/SCREENSHOTS_SOP.md`

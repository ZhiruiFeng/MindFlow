#!/usr/bin/env bash
#
# capture-screenshots.sh — Run the MindFlow UI-test screenshot/automation harness
# and collect the resulting PNGs for visual review / regression.
#
# This is the macOS analog of the iOS `xcrun simctl io booted screenshot` flow
# used by the Anora and Collector apps. macOS apps can't run in the iOS
# Simulator, so capture goes through XCUITest + XCUIScreenshot, which also
# auto-navigates and can click/type to drive real UX flows.
#
# Because the UI-test runner is sandboxed (it can't write PNGs to arbitrary
# paths), screenshots are taken as XCTAttachments and then harvested out of the
# .xcresult bundle into the output directory here.
#
# Two-tier model (matches product-ux SCREENSHOTS_SOP):
#   • Canonical (default) → docs/ux-audit/screenshots/   committed, fixed names.
#   • Scratch  (--scratch) → screenshots/<date>/          gitignored.
#
# First run only: macOS prompts to allow Xcode/the test runner to control the
# app (System Settings → Privacy & Security → Automation / Accessibility).
#
# Usage:
#   Scripts/capture-screenshots.sh [--scratch | <dir>] [--only <TestName>]
#
#   (no args)        screen captures → docs/ux-audit/screenshots/
#   --scratch        → screenshots/<YYYY-MM-DD>/
#   <dir>            → explicit directory
#   --only <Test>    run a single test (default: testCaptureAllScreens)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_DIR/MindFlow"
CANONICAL_DIR="$REPO_DIR/docs/ux-audit/screenshots"

ONLY_TEST="testCaptureAllScreens"
OUT_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY_TEST="$2"; shift 2 ;;
    --scratch) OUT_ARG="--scratch"; shift ;;
    *) OUT_ARG="$1"; shift ;;
  esac
done

case "$OUT_ARG" in
  --scratch) OUT_DIR="$REPO_DIR/screenshots/$(date +%Y-%m-%d)" ;;
  "")        OUT_DIR="$CANONICAL_DIR" ;;
  *)         OUT_DIR="$OUT_ARG" ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
echo "📂 Output directory: $OUT_DIR"

# 1) Quit any running MindFlow — otherwise XCUITest's launch-time terminate of
#    the existing menu-bar instance fails and the test aborts before it starts.
echo "> Quitting any running MindFlow instance..."
osascript -e 'quit app "MindFlow"' >/dev/null 2>&1 || true
pkill -x MindFlow >/dev/null 2>&1 || true
sleep 1
# Menu-bar agent instances (especially the DerivedData test build) can ignore
# SIGTERM and get stuck — XCUITest then fails to terminate them at launch.
# Force-kill anything still alive before the test starts.
pkill -9 -x MindFlow >/dev/null 2>&1 || true
# A previous interrupted/failed run can leave the app suspended under LLDB's
# debugserver, where it survives SIGKILL while traced. Kill the debugger parent
# first, then the app, so launch isn't blocked by an un-terminable instance.
for pid in $(pgrep -f "Debug/MindFlow.app/Contents/MacOS/MindFlow" 2>/dev/null); do
  ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$ppid" ] && ps -o comm= -p "$ppid" 2>/dev/null | grep -q debugserver; then
    kill -9 "$ppid" 2>/dev/null || true
  fi
  kill -9 "$pid" 2>/dev/null || true
done
sleep 1

# 2) Run the test into a known result bundle.
RESULT_BUNDLE="$(mktemp -d)/MindFlow.xcresult"
rm -rf "$RESULT_BUNDLE"
echo "> Running MindFlowUITests/${ONLY_TEST}..."
cd "$PROJECT_DIR"
set +e
# NOTE: do NOT disable code signing here. XCUITest injects its bridge libraries
# into the (sandboxed, hardened-runtime) app; with signing disabled, library
# validation blocks the injection and `app.launch()` fails with "does not have a
# process ID". Use the project's normal automatic signing.
xcodebuild test \
  -scheme MindFlow \
  -destination 'platform=macOS' \
  -only-testing:"MindFlowUITests/MindFlowUITests/$ONLY_TEST" \
  -resultBundlePath "$RESULT_BUNDLE" \
  >/tmp/mindflow-uitest.log 2>&1
TEST_STATUS=$?
set -e
echo "  xcodebuild exit: $TEST_STATUS (full log: /tmp/mindflow-uitest.log)"

# 3) Harvest screenshot attachments from the .xcresult into OUT_DIR.
echo "> Extracting screenshots from result bundle..."
RAW_DIR="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$RAW_DIR" >/dev/null 2>&1 || true

python3 - "$RAW_DIR" "$OUT_DIR" <<'PY'
import json, os, re, sys, shutil
raw, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(raw, "manifest.json")
if not os.path.exists(manifest):
    print("  (no manifest.json — nothing extracted)"); sys.exit(0)
data = json.load(open(manifest))
# xcresulttool appends _<index>_<UUID> to exported filenames; strip it back to
# the clean step name we set via XCTAttachment.name.
suffix = re.compile(r"_\d+_[0-9A-Fa-f-]{36}(\.\w+)$")
n = 0
for test in data:
    for att in test.get("attachments", []):
        src = att.get("exportedFileName")
        if not src or not src.lower().endswith(".png"):
            continue  # skip screen-recording .mp4 etc.
        # Prefer the human-readable step name (XCTAttachment.name); fall back to
        # the exported filename. Strip any _<index>_<UUID> suffix either way.
        human = att.get("suggestedHumanReadableName")
        name = suffix.sub(r"\1", human if human else src)
        if not name.lower().endswith(".png"):
            name += ".png"
        shutil.copyfile(os.path.join(raw, src), os.path.join(out, name)); n += 1
        print(f"  ✓ {name}")
print(f"  {n} screenshot(s) → {out}")
PY

echo ""
echo "✅ Files in $OUT_DIR:"
ls -1 "$OUT_DIR"/*.png 2>/dev/null || echo "  (none — see /tmp/mindflow-uitest.log)"
open "$OUT_DIR" 2>/dev/null || true
exit "$TEST_STATUS"

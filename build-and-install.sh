#!/bin/bash

# MindFlow Build & Install Script
# This script builds MindFlow and installs it to /Applications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MindFlow"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="MindFlow.app"
INSTALL_DIR="/Applications"

echo "🔨 Building MindFlow..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app in Release configuration
xcodebuild -project "$PROJECT_DIR/MindFlow.xcodeproj" \
    -scheme MindFlow \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find the built app
BUILT_APP=$(find "$BUILD_DIR" -name "$APP_NAME" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "❌ Build failed - MindFlow.app not found"
    exit 1
fi

echo "✅ Build successful!"

# Check if app is already running and close it
if pgrep -x "MindFlow" > /dev/null; then
    echo "⏳ Closing running MindFlow instance..."
    pkill -x "MindFlow" || true
    sleep 1
fi

# Remove old installation
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    echo "🗑️  Removing old installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Copy to Applications
echo "📦 Installing to $INSTALL_DIR..."
cp -R "$BUILT_APP" "$INSTALL_DIR/"

# Remove quarantine attribute (prevents "unidentified developer" warning)
xattr -cr "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

echo "✅ MindFlow installed successfully!"
echo ""
echo "You can now:"
echo "  • Open MindFlow from Spotlight (⌘ + Space, type 'MindFlow')"
echo "  • Open from Applications folder"
echo "  • Run: open -a MindFlow"
echo ""

# Ask if user wants to open the app
read -p "Would you like to open MindFlow now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open -a MindFlow
fi

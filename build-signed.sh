#!/bin/bash

# MindFlow Signed Build Script
# Builds a properly signed version using your Apple Developer certificate

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MindFlow"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="MindFlow.app"
INSTALL_DIR="/Applications"

echo "🔨 Building MindFlow (signed)..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build with automatic signing (uses your developer certificate)
xcodebuild -project "$PROJECT_DIR/MindFlow.xcodeproj" \
    -scheme MindFlow \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -quiet

# Find the built app
BUILT_APP=$(find "$BUILD_DIR" -name "$APP_NAME" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "❌ Build failed - MindFlow.app not found"
    exit 1
fi

echo "✅ Build successful!"

# Verify code signing
echo "🔍 Verifying code signature..."
codesign -dv --verbose=2 "$BUILT_APP" 2>&1 | head -5

# Check if app is already running
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

echo "✅ MindFlow installed successfully!"
echo ""
echo "The app is properly signed and ready to use."
echo ""

read -p "Would you like to open MindFlow now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open -a MindFlow
fi

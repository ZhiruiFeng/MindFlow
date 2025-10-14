# Chrome Extension Permission Issues

## Microphone permission denied

### Problem

When clicking "Start Recording" in the MindFlow Chrome extension, you see the error:

```
Microphone access denied. Please enable microphone permissions.
```

The browser doesn't show a permission prompt, or you previously denied permission.

### Cause

Chrome remembers microphone permission decisions for extensions. If you:
1. Previously clicked "Block" when prompted for microphone access
2. Never received a permission prompt due to browser settings
3. Have system-level microphone restrictions

The extension cannot access your microphone.

### Solution

#### Method 1: Extension settings (recommended)

1. Right-click the MindFlow extension icon in your Chrome toolbar
2. Select **"Manage extension"**
3. Scroll down to **"Site settings"** or **"Permissions"**
4. Find **"Microphone"** in the list
5. Change from "Block" or "Ask" to **"Allow"**
6. Close and reopen the extension popup

#### Method 2: Chrome settings page

1. Open the extension ID by clicking the MindFlow icon
2. Copy the extension ID from the URL (e.g., `chrome-extension://abcdefghijklmnop`)
3. Navigate to: `chrome://settings/content/siteDetails?site=chrome-extension://<YOUR-ID>`
4. Find **"Microphone"** in the permissions list
5. Change to **"Allow"**
6. Reload the extension

#### Method 3: System-level check (macOS)

If neither method works, check system permissions:

1. Open **System Settings** → **Privacy & Security**
2. Click **"Microphone"**
3. Ensure **Google Chrome** is checked/enabled
4. Restart Chrome if you made changes
5. Try recording again

#### Method 4: System-level check (Windows)

1. Open **Settings** → **Privacy** → **Microphone**
2. Ensure **"Allow apps to access your microphone"** is ON
3. Scroll down and ensure **Google Chrome** is enabled
4. Restart Chrome
5. Try recording again

### Verification

After applying the fix:

1. Click the MindFlow extension icon
2. Click **"Start Recording"**
3. You should see:
   - Recording indicator appear
   - Timer start counting
   - Waveform animation (if applicable)
4. Speak a few words
5. Click **"Stop & Process"**
6. Verify transcription appears

### Still not working?

If you still see permission errors:

1. **Check browser console for errors**:
   - Right-click the extension popup → Inspect
   - Check Console tab for detailed error messages

2. **Try a different browser**:
   - Test in Chrome Canary or Edge
   - Helps identify if it's a browser-specific issue

3. **Verify microphone works elsewhere**:
   - Test microphone in a different application
   - Try a browser-based microphone test site

4. **Check extension version**:
   - Ensure you're running the latest version
   - Check for updates in `chrome://extensions`

### Technical background

The MindFlow extension uses an **offscreen document** to handle microphone access because:

- Chrome extension popups cannot directly request microphone permissions
- The permission dialog won't appear when called from a popup context
- Offscreen documents provide a proper context for user media APIs

The architecture flow:
```
Popup → Service Worker → Offscreen Document → getUserMedia() → Microphone
```

This is a Chrome Extension Manifest V3 requirement and the recommended approach for audio recording in extensions.

## Related issues

- [Extension popup appears blank](./chrome-extension-ui.md#blank-popup)
- [Recording fails silently](./chrome-extension-recording.md#recording-fails)
- [Audio quality issues](./chrome-extension-audio.md)

## See also

- [Chrome Extension User Guide](../guides/chrome-extension-user-guide.md)
- [Setup Guide](../guides/chrome-extension-setup.md)
- [Architecture Documentation](../architecture/chrome-extension-architecture.md)

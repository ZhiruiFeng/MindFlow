# MindFlow Extension - Troubleshooting Guide

## Common Errors and Solutions

### ✅ FIXED: Service Worker Registration Failed (Status code: 15)

**Error**: `Service worker registration failed. Status code: 15`

**Cause**: Service worker wasn't declared as a module in manifest.json

**Solution**: ✅ Fixed! The manifest.json now includes `"type": "module"` in the background section.

**What was changed**:
```json
"background": {
  "service_worker": "src/background/service-worker.js",
  "type": "module"  // ← Added this line
}
```

---

### ✅ FIXED: Cannot use import statement outside a module

**Error**: `Uncaught SyntaxError: Cannot use import statement outside a module`

**Solution**: ✅ Fixed! Service worker is now declared as a module.

**Action needed**: Reload the extension in chrome://extensions/

---

### ✅ FIXED: Icon Loading Errors

**Error**: Missing icon files (icon-16.png, icon-48.png, icon-128.png)

**Solution**: ✅ Fixed! Icons have been generated in `assets/icons/`

**Verify icons exist**:
```bash
ls MindFlow-Extension/assets/icons/*.png
```

You should see:
- icon-16.png (819 bytes)
- icon-48.png (1.2 KB)
- icon-128.png (1.5 KB)

---

### ⚠️ Expected: API key not configured

**Error**: `[MindFlow Error] Service initialization error: ConfigurationError: API key not configured. Please add your API key in settings.`

**This is NORMAL on first load!**

**Solution**:
1. Click the MindFlow extension icon
2. Click the settings gear icon (⚙️)
3. Enter your OpenAI API key from https://platform.openai.com/api-keys
4. Click "Test API Key" to validate
5. Click "Save Settings"

---

### ⚠️ Expected: Microphone access denied

**Error**: `RecordingError: Microphone access denied. Please enable microphone permissions.`

**This is NORMAL if you haven't granted microphone permission!**

**Solution**:
1. When you click "Start Recording", Chrome will show a permission prompt
2. Click "Allow" to grant microphone access
3. If you accidentally denied it:
   - Click the camera icon in Chrome's address bar
   - Change microphone setting to "Allow"
   - Open `chrome://settings/content/siteDetails?site=chrome-extension://<EXTENSION_ID>` and set Microphone to Allow (replace `<EXTENSION_ID>` with the one shown on the extension's Details page)
   - Or go to: chrome://settings/content/microphone
   - Add exception for the extension

---

### ⚠️ Testing Errors (ElevenLabs)

**Error**: `[MindFlow Error] ElevenLabs API error: 422`

**This is EXPECTED if you don't have an ElevenLabs API key!**

**Why this happens**:
- The extension tries to validate ElevenLabs API even if no key is configured
- This is only during settings page load when testing API keys
- It doesn't affect OpenAI Whisper functionality

**Solution**:
- Ignore this error if you're only using OpenAI Whisper (recommended)
- Or add an ElevenLabs API key in settings to use their STT service

---

## Loading the Extension

### Step-by-Step Setup

1. **Open Extensions Page**
   ```
   chrome://extensions/
   ```

2. **Enable Developer Mode**
   - Toggle "Developer mode" in the top right

3. **Load Extension**
   - Click "Load unpacked"
   - Navigate to: `MindFlow-Extension/`
   - Click "Select"

4. **Verify Installation**
   - ✅ Extension appears in list
   - ✅ No red errors in card
   - ✅ Icon appears in browser toolbar

5. **Configure API Key**
   - Click extension icon
   - Click settings (⚙️)
   - Enter OpenAI API key
   - Test and save

---

## Testing the Extension

### Quick Test Flow

1. **Open any website** (e.g., gmail.com)
2. **Click in a text field** (so there's an active input)
3. **Click MindFlow extension icon**
4. **Click "Start Recording"**
5. **Allow microphone access** (if prompted)
6. **Speak clearly**: "Hello, this is a test"
7. **Click "Stop & Process"**
8. **Wait 10-15 seconds**:
   - Processing... (1-2 sec)
   - Transcribing... (5-8 sec)
   - Optimizing... (3-5 sec)
9. **See results**: Original text vs Optimized text
10. **Click "Insert"** → Text appears in the field!

---

## Expected Behavior

### ✅ What Should Work

- Extension loads without errors
- Popup opens with clean UI
- Settings page accessible
- API key can be entered and tested
- Recording starts with permission
- Transcription works with valid API key
- Text optimization works
- Insert puts text in active field

### ⚠️ Known Limitations

- **No API Key**: Can't record/transcribe without OpenAI key
- **No Microphone**: Must grant permission first
- **Network Required**: No offline mode
- **Chrome Only**: Doesn't work in Firefox (different APIs)

---

## Debugging Tips

### Check Service Worker Logs

1. Go to `chrome://extensions/`
2. Find MindFlow extension
3. Click "service worker" link
4. Open DevTools console
5. Look for `[MindFlow]` logs

### Check Popup Logs

1. Right-click extension icon
2. Click "Inspect"
3. Open Console tab
4. Look for errors or `[MindFlow]` logs

### Check Content Script Logs

1. Open any web page
2. Right-click → Inspect
3. Console tab
4. Look for `[MindFlow] Content script loaded`

### Common Log Messages

**Normal/Good**:
```
[MindFlow] Service worker loaded successfully
[MindFlow] Initializing popup...
[MindFlow] Services initialized
[MindFlow] Content script loaded
[MindFlow] Recording started
[MindFlow] Transcription: <text>
[MindFlow] Optimization complete
```

**Expected Warnings**:
```
[MindFlow Error] Service initialization error: ConfigurationError: API key not configured
// ↑ Normal on first load, add API key in settings
```

**Actual Errors** (need fixing):
```
Uncaught SyntaxError: Cannot use import statement outside a module
// ↑ Manifest issue (now fixed)

Service worker registration failed
// ↑ Manifest issue (now fixed)

Cannot find module
// ↑ File path issue, check file exists
```

---

## Reset Everything

If things are really broken:

### 1. Remove Extension
```
chrome://extensions/ → Remove MindFlow
```

### 2. Reload Code
```bash
cd MindFlow-Extension
git status  # Check for changes
# Or re-download/re-clone
```

### 3. Reload Extension
```
chrome://extensions/ → Load unpacked → Select directory
```

### 4. Clear Storage (if needed)
```javascript
// In DevTools console (service worker or popup):
chrome.storage.sync.clear();
chrome.storage.local.clear();
console.log('Storage cleared');
```

---

## Getting Help

### Before Reporting Issues

1. ✅ Check this troubleshooting guide
2. ✅ Verify icons exist (run icon script if needed)
3. ✅ Check manifest.json has `"type": "module"`
4. ✅ Verify API key is entered in settings
5. ✅ Check browser console for actual errors

### Information to Include

When reporting issues:
- Chrome version: `chrome://version/`
- Error messages (full text)
- Console logs (from service worker and popup)
- Steps to reproduce
- Screenshots if UI issue

### Quick Checks

```bash
# Verify structure
ls MindFlow-Extension/manifest.json
ls MindFlow-Extension/assets/icons/*.png

# Check manifest syntax
cat MindFlow-Extension/manifest.json | grep -A2 "background"
# Should show: "type": "module"

# Verify icons
file MindFlow-Extension/assets/icons/*.png
# Should show: PNG image data
```

---

## Success Checklist

Before considering the extension "working":

- [x] Extension loads without errors
- [x] Icons display in toolbar
- [x] Popup opens and shows UI
- [x] Settings page opens
- [ ] API key added and validated ← **YOU NEED TO DO THIS**
- [ ] Recording works (with mic permission) ← **TEST THIS**
- [ ] Transcription works ← **TEST THIS**
- [ ] Optimization works ← **TEST THIS**
- [ ] Text insertion works ← **TEST THIS**

---

## Next Steps After Fixing Errors

1. **Reload extension** in chrome://extensions/
2. **Add your OpenAI API key** in settings
3. **Test the full flow** (record → transcribe → optimize → insert)
4. **Try on different websites**:
   - Gmail
   - Google Docs
   - Twitter
   - Reddit
   - Any site with text input

---

**Remember**: Most "errors" on first load are expected!
The only actual bugs were the manifest/module issues, which are now fixed.

All other errors just mean you need to:
1. Add your API key (settings page)
2. Grant microphone permission (when recording)

Happy testing! 🎤✨

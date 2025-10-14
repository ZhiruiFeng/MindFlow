# Local-First Sync Debugging Guide

## Issue: Authentication Detection & Auto-Sync Not Working

### Problem 1: Manual Sync Failing with "Not authenticated"

**Error Log:**
```
🔄 [LocalHistory] Syncing interaction: 3652B0A0-93C0-459F-BE82-A328F90A1F91
🔄 [StorageService] Manual sync requested for: 3652B0A0-93C0-459F-BE82-A328F90A1F91
⚠️ [StorageService] Not authenticated, cannot sync
❌ [LocalHistory] Sync failed
```

**Root Cause:**
`InteractionStorageService` was checking for auth token in `KeychainManager`, but `SupabaseAuthService` stores tokens in `UserDefaults`.

**Fix Applied:**
Changed authentication check in `InteractionStorageService.swift:22-25`:

```swift
// Before (WRONG):
private var isAuthenticated: Bool {
    return KeychainManager.shared.get(key: "supabase_access_token") != nil
}

// After (CORRECT):
private var isAuthenticated: Bool {
    // Check if user has valid Supabase session (stored in UserDefaults)
    return UserDefaults.standard.string(forKey: "supabase_access_token") != nil
}
```

### Problem 2: Auto-Sync Not Triggering for Long Recordings

**Symptoms:**
- Long recordings (>30s) not syncing automatically
- ZMemory backend not receiving any requests
- No error messages in logs

**Debugging Steps Added:**

1. **Enhanced Auto-Sync Logging** (`InteractionStorageService.swift:216-248`)
   - Logs all 3 conditions: auto-sync enabled, authenticated, duration check
   - Shows actual values for each check
   - Clear indication why sync is skipped or proceeding

2. **Enhanced Sync Attempt Logging** (`InteractionStorageService.swift:254-276`)
   - Logs request preparation details
   - Shows transcription preview, API, duration
   - Tracks API client invocation
   - Shows response reception

3. **Enhanced Error Logging** (`InteractionStorageService.swift:290-299`)
   - Full error object dump
   - Localized description
   - API-specific error details

## Debugging Log Format

### Successful Auto-Sync Flow:
```
💾 [StorageService] Saving interaction locally first
   📝 Transcription length: 245 chars
   🎤 STT Provider: OpenAI
   ⏱️ Duration: 45s
✅ [StorageService] Saved locally with ID: ABC-123

🔍 [StorageService] Checking auto-sync conditions...
   📋 Interaction ID: ABC-123
   ⏱️ Duration: 45.0s
   🔧 Auto-sync enabled: true
   🔐 Has auth token: true
   📏 Threshold: 30.0s
🚀 [StorageService] Meeting auto-sync criteria, syncing to backend...

📤 [StorageService] Preparing to sync interaction to backend
   📝 Transcription: Hello, this is a test recording that is long...
   🎤 API: OpenAI
   ⏱️ Duration: 45.0s
🌐 [StorageService] Calling API client...
🔑 [MindFlowAPI] Access token found (length: 234)
📥 [StorageService] Received response from API
✅ [StorageService] Successfully synced to backend with ID: DEF-456
```

### Skipped Auto-Sync (Short Recording):
```
🔍 [StorageService] Checking auto-sync conditions...
   📋 Interaction ID: XYZ-789
   ⏱️ Duration: 15.0s
   🔧 Auto-sync enabled: true
   🔐 Has auth token: true
   📏 Threshold: 30.0s
⏭️ [StorageService] Duration 15.0s < 30.0s threshold, keeping local only
```

### Manual Sync Flow:
```
🔄 [LocalHistory] Syncing interaction: ABC-123
🔄 [StorageService] Manual sync requested for: ABC-123
📤 [StorageService] Preparing to sync interaction to backend
   📝 Transcription: Hello, this is a test recording...
   🎤 API: OpenAI
   ⏱️ Duration: 45.0s
🌐 [StorageService] Calling API client...
🔑 [MindFlowAPI] Access token found (length: 234)
📥 [StorageService] Received response from API
✅ [StorageService] Successfully synced to backend with ID: DEF-456
✅ [LocalHistory] Sync successful
```

### Failed Sync (Not Authenticated):
```
🔄 [StorageService] Manual sync requested for: ABC-123
⚠️ [StorageService] Not authenticated, cannot sync
❌ [LocalHistory] Sync failed
```

### Failed Sync (API Error):
```
🌐 [StorageService] Calling API client...
⚠️ [MindFlowAPI] No access token found in UserDefaults
❌ [MindFlowAPI] Fetch failed - No access token
❌ [StorageService] Failed to sync to backend
   ⚠️ Error: MindFlowAPIError.notAuthenticated
   📝 Description: Not authenticated
   🔍 API Error: notAuthenticated
```

## Testing Checklist

### Before Testing:
- [ ] Verify you're signed in (check Settings → Account section)
- [ ] Verify auto-sync is enabled (Settings → Backend Sync)
- [ ] Note the threshold value (default: 30 seconds)
- [ ] Open Console.app and filter for "MindFlow" to see logs

### Test 1: Short Recording (< Threshold)
1. Record audio < 30 seconds
2. Check logs for:
   - `💾 [StorageService] Saving interaction locally first`
   - `⏭️ [StorageService] Duration X.Xs < 30.0s threshold, keeping local only`
3. Go to Local History tab
4. Verify interaction shows "Local" badge (gray)
5. Click "Sync" button
6. Verify it syncs successfully

### Test 2: Long Recording (≥ Threshold)
1. Record audio ≥ 30 seconds
2. Check logs for:
   - `💾 [StorageService] Saving interaction locally first`
   - `🔍 [StorageService] Checking auto-sync conditions...`
   - `🚀 [StorageService] Meeting auto-sync criteria, syncing to backend...`
   - `✅ [StorageService] Successfully synced to backend with ID: XXX`
3. Go to Local History tab
4. Verify interaction shows "Synced" badge (green)
5. Go to History tab (backend history)
6. Verify interaction appears there too

### Test 3: Not Authenticated
1. Sign out (Settings → Account → Sign Out)
2. Record any audio
3. Check logs for:
   - `💾 [StorageService] Saving interaction locally first`
   - `🔐 Has auth token: false`
   - `⏭️ [StorageService] Not authenticated, keeping local only`
4. Go to Local History tab
5. Verify all interactions show "Local" badge
6. Verify no "Sync" buttons (since not authenticated)

### Test 4: Batch Sync
1. Create 3 short recordings (all < 30s)
2. Verify all are local-only
3. Sign in if needed
4. Go to Local History tab
5. Click "Sync All" button
6. Check logs for sync progress
7. Verify all show "Synced" badge after completion

## Common Issues

### Issue: "Not authenticated" despite being signed in

**Check:**
```bash
defaults read com.yourcompany.MindFlow supabase_access_token
```

**Solution:**
- If empty: Sign out and sign in again
- If present but still failing: Check token is being passed to API client

### Issue: No sync logs appearing

**Check:**
- Is auto-sync enabled in settings?
- Is recording duration ≥ threshold?
- Open Console.app and search for "StorageService"

### Issue: Sync fails with API error

**Check:**
1. ZMemory backend is running
2. Backend URL is correct in ConfigurationManager
3. Auth token is valid (not expired)
4. Check network connectivity

**Verify Backend URL:**
```swift
print(ConfigurationManager.shared.zmemoryAPIURL)
```

### Issue: Backend not receiving requests

**Check:**
1. Look for `🌐 [StorageService] Calling API client...` in logs
2. Check if `🔑 [MindFlowAPI] Access token found` appears
3. Enable backend logging to see incoming requests
4. Use network debugging tool (Charles, Proxyman) to inspect HTTP traffic

## Files Changed

### Core Changes:
- `Services/InteractionStorageService.swift` - Fixed auth check, added logging
- `Views/SettingsTabView.swift` - Added Backend Sync configuration UI
- `Views/LocalHistoryView.swift` - New local history view with sync status
- `ViewModels/LocalHistoryViewModel.swift` - View model for local history
- `Views/MainView.swift` - Added Local History tab

### Supporting Files:
- `Services/LocalInteractionStorage.swift` - Core Data CRUD operations
- `Models/LocalInteraction+CoreDataClass.swift` - Entity with computed properties
- `Models/LocalInteraction+CoreDataProperties.swift` - 19 Core Data properties
- `Managers/CoreDataManager.swift` - Core Data stack
- `Models/Settings.swift` - Added sync configuration properties

## Next Steps After Fixing

1. Run the app with enhanced logging
2. Test each scenario in the checklist
3. Share the logs from Console.app showing:
   - Authentication check results
   - Auto-sync condition checks
   - API call attempts and responses
4. Verify ZMemory backend logs show incoming requests

This will help identify exactly where the sync flow is breaking down.

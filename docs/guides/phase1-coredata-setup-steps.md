# Phase 1: Core Data Setup - Next Steps

## ✅ Completed

- [x] Created `CoreDataManager.swift` - Core Data stack management
- [x] Created `LocalInteraction+CoreDataClass.swift` - Managed object class
- [x] Created `LocalInteraction+CoreDataProperties.swift` - Entity properties
- [x] Created `LocalInteractionStorage.swift` - Storage service layer
- [x] Created `InteractionMetadata.swift` - Helper struct
- [x] Updated `Settings.swift` - Added sync configuration

## 🎯 Next Steps - Required in Xcode

### Step 1: Create Core Data Model File

1. **Open Xcode project:**
   ```bash
   open /Users/zhiruifeng/Workspace/dev/MindFlow/MindFlow/MindFlow.xcodeproj
   ```

2. **Create Data Model:**
   - Right-click on `MindFlow/Models` folder
   - Select `New File...`
   - Choose `Data Model` (under Core Data section)
   - Name it: `MindFlow.xcdatamodeld`
   - Click `Create`

### Step 2: Define LocalInteraction Entity

1. **Select the Model File:**
   - Click on `MindFlow.xcdatamodeld` in Project Navigator

2. **Add Entity:**
   - Click `Add Entity` button at the bottom
   - Rename it to: `LocalInteraction`
   - Set `Class` to: `LocalInteraction`
   - Set `Module` to: `MindFlow`
   - Set `Codegen` to: `Manual/None` (important!)

3. **Add Attributes:**

   Click `+` in Attributes section and add each of these:

   | Attribute Name | Type | Optional | Default |
   |---------------|------|----------|---------|
   | `id` | UUID | ☐ No | - |
   | `createdAt` | Date | ☐ No | - |
   | `updatedAt` | Date | ☐ No | - |
   | `originalTranscription` | String | ☐ No | - |
   | `refinedText` | String | ☑ Yes | - |
   | `teacherExplanation` | String | ☑ Yes | - |
   | `transcriptionApi` | String | ☐ No | - |
   | `transcriptionModel` | String | ☑ Yes | - |
   | `optimizationModel` | String | ☑ Yes | - |
   | `optimizationLevel` | String | ☑ Yes | - |
   | `outputStyle` | String | ☑ Yes | - |
   | `audioDuration` | Double | ☐ No | `0` |
   | `audioFileUrl` | String | ☑ Yes | - |
   | `syncStatus` | String | ☑ Yes | `"pending"` |
   | `backendId` | UUID | ☑ Yes | - |
   | `syncedAt` | Date | ☑ Yes | - |
   | `syncError` | String | ☑ Yes | - |
   | `syncRetryCount` | Integer 16 | ☐ No | `0` |

4. **Configure Indexes (for Performance):**
   - Select the entity
   - Click on the `Indexes` section (at the top)
   - Add index on: `createdAt` (for sorting)
   - Add index on: `syncStatus` (for filtering pending syncs)
   - Add composite index on: `syncStatus + createdAt` (optional, for better query performance)

### Step 3: Add Files to Xcode Project

The Swift files are already created, but you need to add them to Xcode:

1. **Drag and Drop Files:**
   - In Finder, navigate to the file locations
   - Drag these files into Xcode's Project Navigator under appropriate groups:

   **Managers:**
   - `CoreDataManager.swift` → `Managers` folder

   **Models:**
   - `InteractionMetadata.swift` → `Models` folder
   - `LocalInteraction+CoreDataClass.swift` → `Models` folder
   - `LocalInteraction+CoreDataProperties.swift` → `Models` folder

   **Services:**
   - `LocalInteractionStorage.swift` → `Services` folder

2. **When prompted:**
   - ☑ Check "Copy items if needed"
   - ☑ Check your app target (`MindFlow`)
   - Click `Finish`

### Step 4: Build and Test

1. **Clean Build:**
   - Press `Cmd + Shift + K` (Clean Build Folder)

2. **Build Project:**
   - Press `Cmd + B` (Build)

3. **Check for Errors:**
   - Fix any import issues or missing references

4. **Run App:**
   - Press `Cmd + R` (Run)
   - Check console for Core Data initialization logs:
     ```
     🔧 [CoreData] Initializing Core Data stack
     ✅ [CoreData] Persistent store loaded
     ✅ [CoreData] Persistent container ready
     ```

## ✅ Verification Checklist

Run these checks after setup:

### 1. Core Data Stack Loads
```swift
// In AppDelegate or MindFlowApp.swift, add:
print("Testing Core Data...")
let manager = CoreDataManager.shared
print("View context: \(manager.viewContext)")
```

Expected output:
```
🔧 [CoreData] Initializing Core Data stack
✅ [CoreData] Persistent store loaded
✅ [CoreData] Persistent container ready
Testing Core Data...
View context: <NSManagedObjectContext: 0x...>
```

### 2. Can Create LocalInteraction
```swift
// Test in a view or service:
let storage = LocalInteractionStorage.shared
let metadata = InteractionMetadata(
    transcriptionApi: "OpenAI",
    transcriptionModel: "whisper-1"
)

let interaction = storage.saveInteraction(
    transcription: "Test transcription",
    refinedText: "Test refined",
    teacherExplanation: nil,
    audioDuration: 25.0,
    metadata: metadata
)

print("Created interaction: \(interaction.id)")
print("Sync status: \(interaction.syncStatusEnum.rawValue)")
```

Expected output:
```
💾 [LocalStorage] Interaction saved locally
   📝 ID: 12345678-1234-1234-1234-123456789ABC
   ⏱️ Duration: 25.0s
   🔄 Sync status: pending
Created interaction: 12345678-1234-1234-1234-123456789ABC
Sync status: pending
```

### 3. Can Fetch Interactions
```swift
let interactions = storage.fetchAllInteractions()
print("Total interactions: \(interactions.count)")
```

Expected output:
```
📋 [LocalStorage] Fetched 1 interactions
Total interactions: 1
```

## 🐛 Troubleshooting

### Error: "Entity not found"
**Solution:** Make sure:
- Entity name is exactly `LocalInteraction`
- Codegen is set to `Manual/None`
- Model file is in the app target

### Error: "Unknown type name"
**Solution:**
- Clean build folder (`Cmd + Shift + K`)
- Build again (`Cmd + B`)
- Make sure all files are added to the target

### Error: "Multiple instances of CoreDataManager"
**Solution:** Use `CoreDataManager.shared` singleton, don't create new instances

### Error: "Persistent store incompatible"
**Solution:** If you changed the model after first run:
```swift
// Delete app container (in simulator):
// Simulator → Device → Erase All Content and Settings

// Or delete specific app data:
CoreDataManager.shared.resetPersistentStore()
```

## 📝 Quick Reference

### File Locations
```
MindFlow/
├── Managers/
│   └── CoreDataManager.swift ← Core Data stack
├── Models/
│   ├── MindFlow.xcdatamodeld ← Data model (create in Xcode)
│   ├── InteractionMetadata.swift ← Helper struct
│   ├── LocalInteraction+CoreDataClass.swift ← Entity class
│   ├── LocalInteraction+CoreDataProperties.swift ← Entity properties
│   └── Settings.swift ← Updated with sync settings
└── Services/
    └── LocalInteractionStorage.swift ← Storage operations
```

### Usage Pattern
```swift
// 1. Get storage instance
let storage = LocalInteractionStorage.shared

// 2. Save interaction
let interaction = storage.saveInteraction(
    transcription: "...",
    refinedText: "...",
    teacherExplanation: nil,
    audioDuration: 25.0,
    metadata: metadata
)

// 3. Fetch interactions
let all = storage.fetchAllInteractions()
let pending = storage.fetchPendingSyncInteractions()

// 4. Update sync status
storage.markAsSynced(interaction: interaction, backendId: uuid)
// or
storage.markSyncFailed(interaction: interaction, error: "...")
```

## 🎉 Once Complete

After successfully setting up Core Data and verifying it works:

**Next:** Move to Phase 2 - Refactor `InteractionStorageService` to use local storage first, then conditionally sync to backend.

See: `/docs/planning/macos-local-first-sync-plan.md` - Phase 2

---

**Need Help?**
- Check Xcode console for detailed error messages
- Look for logs prefixed with `[CoreData]` or `[LocalStorage]`
- Verify all files are properly added to the target
- Make sure model entity matches the Swift properties exactly

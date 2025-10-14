# Local Storage Deep Dive: How MindFlow Stores Data Locally

## Overview

MindFlow uses **Apple's Core Data framework** for local persistence. Core Data is an object-relational mapping (ORM) framework that provides:
- Local SQLite database storage
- Object graph management
- Query optimization
- Background processing
- Data migration support

## Table of Contents
1. [Core Data Stack Architecture](#1-core-data-stack-architecture)
2. [Data Model Definition](#2-data-model-definition)
3. [Entity Classes](#3-entity-classes)
4. [Storage Service Layer](#4-storage-service-layer)
5. [Complete Save Workflow](#5-complete-save-workflow)
6. [Query Operations](#6-query-operations)
7. [Sync Status Management](#7-sync-status-management)
8. [File System Storage](#8-file-system-storage)

---

## 1. Core Data Stack Architecture

### 1.1 CoreDataManager - The Foundation

**Location**: `MindFlow/Managers/CoreDataManager.swift`

```swift
class CoreDataManager {
    static let shared = CoreDataManager()  // Singleton pattern

    // The Core Data container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MindFlow")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()

    // Main thread context for UI operations
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}
```

### 1.2 What Happens During Initialization?

**Step 1: App Launch**
```
App starts
    ↓
CoreDataManager.shared is accessed
    ↓
persistentContainer is initialized (lazy)
    ↓
Looks for "MindFlow.xcdatamodeld" file
    ↓
Reads entity definitions (LocalInteraction)
    ↓
Creates/opens SQLite database at:
~/Library/Application Support/com.yourcompany.MindFlow/MindFlow.sqlite
    ↓
Ready to use
```

**Step 2: Database Files Created**
```
~/Library/Application Support/com.yourcompany.MindFlow/
├── MindFlow.sqlite           # Main database file
├── MindFlow.sqlite-shm       # Shared memory file (for write-ahead logging)
└── MindFlow.sqlite-wal       # Write-ahead log file
```

### 1.3 NSManagedObjectContext

Think of the context as a "scratchpad" for working with Core Data objects:
- **viewContext**: Used on main thread for UI operations
- **backgroundContext**: Used for heavy operations (not yet implemented)

```swift
let context = CoreDataManager.shared.viewContext
// All database operations go through this context
```

---

## 2. Data Model Definition

### 2.1 The .xcdatamodeld File

**Location**: `MindFlow/Models/MindFlow.xcdatamodeld/MindFlow.xcdatamodel/contents`

This is an **XML file** that defines the database schema:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" ...>
    <entity name="LocalInteraction"
            representedClassName="LocalInteraction"
            syncable="YES">

        <!-- Identity Attributes -->
        <attribute name="id"
                   attributeType="UUID"
                   optional="NO"
                   usesScalarValueType="NO"/>

        <attribute name="createdAt"
                   attributeType="Date"
                   optional="NO"
                   usesScalarValueType="NO"/>

        <!-- Content Attributes -->
        <attribute name="originalTranscription"
                   attributeType="String"
                   optional="NO"/>

        <attribute name="refinedText"
                   attributeType="String"
                   optional="YES"/>

        <!-- Sync Status Attributes -->
        <attribute name="syncStatus"
                   attributeType="String"
                   optional="YES"
                   defaultValueString="pending"/>

        <attribute name="backendId"
                   attributeType="UUID"
                   optional="YES"
                   usesScalarValueType="NO"/>

        <!-- ... 13 more attributes ... -->
    </entity>
</model>
```

### 2.2 Complete Attribute List (19 Total)

| Attribute Name | Type | Optional | Default | Purpose |
|----------------|------|----------|---------|---------|
| **Identity** |
| `id` | UUID | No | Auto | Unique local identifier |
| `createdAt` | Date | No | Auto | Creation timestamp |
| `updatedAt` | Date | No | Auto | Last update timestamp |
| **Content** |
| `originalTranscription` | String | No | - | Raw transcription from STT |
| `refinedText` | String | Yes | - | Optimized/refined text |
| `teacherExplanation` | String | Yes | - | Educational explanation |
| **Metadata** |
| `transcriptionApi` | String | No | - | STT provider (OpenAI/ElevenLabs) |
| `transcriptionModel` | String | Yes | - | Model name (whisper-1, scribe_v1) |
| `optimizationModel` | String | Yes | - | LLM model (gpt-4o-mini) |
| `optimizationLevel` | String | Yes | - | Optimization level (light/medium/heavy) |
| `outputStyle` | String | Yes | - | Style (conversational/formal) |
| `userLanguage` | String | Yes | - | User's language |
| `audioDuration` | Double | Yes | 0.0 | Audio length in seconds |
| `audioFileUrl` | String | Yes | - | Path to audio file |
| **Sync Status** |
| `syncStatus` | String | Yes | "pending" | pending/synced/failed |
| `backendId` | UUID | Yes | - | Backend database ID |
| `lastSyncAttempt` | Date | Yes | - | Last sync attempt time |
| `syncRetryCount` | Int16 | No | 0 | Number of retry attempts |
| `syncErrorMessage` | String | Yes | - | Error message if sync failed |

### 2.3 How Core Data Translates to SQLite

Behind the scenes, Core Data creates a SQLite table:

```sql
CREATE TABLE ZLOCALINTERACTION (
    Z_PK INTEGER PRIMARY KEY,
    Z_ENT INTEGER,
    Z_OPT INTEGER,
    ZID BLOB,                          -- UUID stored as BLOB
    ZCREATEDAT TIMESTAMP,
    ZUPDATEDAT TIMESTAMP,
    ZORIGINALTRANSCRIPTION VARCHAR,
    ZREFINEDTEXT VARCHAR,
    ZSYNCSTATUS VARCHAR,
    ZBACKENDID BLOB,                   -- UUID stored as BLOB
    ZAUDIODURATION REAL,
    ZSYNCRETRYCOUNT INTEGER,
    -- ... more columns
);

CREATE INDEX ZLOCALINTERACTION_ZCREATEDAT_INDEX
    ON ZLOCALINTERACTION (ZCREATEDAT);

CREATE INDEX ZLOCALINTERACTION_ZSYNCSTATUS_INDEX
    ON ZLOCALINTERACTION (ZSYNCSTATUS);
```

**Note**: You can inspect the actual SQLite database using:
```bash
sqlite3 ~/Library/Application\ Support/com.yourcompany.MindFlow/MindFlow.sqlite
.tables
.schema ZLOCALINTERACTION
```

---

## 3. Entity Classes

### 3.1 LocalInteraction+CoreDataClass.swift

This defines the **Swift class** with custom logic:

```swift
@objc(LocalInteraction)
public class LocalInteraction: NSManagedObject {

    // MARK: - Sync Status Enum
    enum SyncStatus: String {
        case pending = "pending"
        case synced = "synced"
        case failed = "failed"
    }

    // MARK: - Computed Properties

    /// Check if needs sync (has no backend ID and is pending)
    var needsSync: Bool {
        return syncStatus == SyncStatus.pending.rawValue && backendId == nil
    }

    /// Check if already synced
    var isSynced: Bool {
        return syncStatus == SyncStatus.synced.rawValue && backendId != nil
    }

    /// Check if can retry sync (failed with < 3 attempts)
    var canRetrySync: Bool {
        return syncStatus == SyncStatus.failed.rawValue && syncRetryCount < 3
    }

    // MARK: - Helper Methods

    /// Type-safe sync status getter/setter
    var syncStatusEnum: SyncStatus {
        get {
            return SyncStatus(rawValue: syncStatus ?? "pending") ?? .pending
        }
        set {
            syncStatus = newValue.rawValue
        }
    }
}
```

**Key Points**:
- Inherits from `NSManagedObject` (Core Data base class)
- Provides **computed properties** for business logic
- Doesn't store data itself (data is in Core Data store)

### 3.2 LocalInteraction+CoreDataProperties.swift

This defines the **properties** that map to database columns:

```swift
extension LocalInteraction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalInteraction> {
        return NSFetchRequest<LocalInteraction>(entityName: "LocalInteraction")
    }

    // MARK: - Identity
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // MARK: - Content
    @NSManaged public var originalTranscription: String
    @NSManaged public var refinedText: String?
    @NSManaged public var teacherExplanation: String?

    // MARK: - Metadata
    @NSManaged public var transcriptionApi: String
    @NSManaged public var transcriptionModel: String?
    @NSManaged public var optimizationModel: String?
    // ... more properties

    // MARK: - Sync Status
    @NSManaged public var syncStatus: String?
    @NSManaged public var backendId: UUID?
    @NSManaged public var lastSyncAttempt: Date?
    @NSManaged public var syncRetryCount: Int16
    @NSManaged public var syncErrorMessage: String?
}
```

**Key Points**:
- `@NSManaged` means Core Data manages these properties
- Properties are NOT stored in the Swift object
- They're stored in the Core Data persistent store (SQLite)
- Accessing them triggers Core Data to fetch from database

---

## 4. Storage Service Layer

### 4.1 LocalInteractionStorage.swift

This is the **CRUD interface** for local storage:

```swift
class LocalInteractionStorage {
    static let shared = LocalInteractionStorage()

    private let coreData = CoreDataManager.shared

    private var context: NSManagedObjectContext {
        return coreData.viewContext
    }

    // Save interaction
    func saveInteraction(...) -> LocalInteraction { }

    // Query interactions
    func fetchAllInteractions() -> [LocalInteraction] { }
    func fetchPendingSyncInteractions() -> [LocalInteraction] { }
    func fetchInteractionsSortedByDate(limit: Int?) -> [LocalInteraction] { }

    // Update sync status
    func markAsSynced(interaction: LocalInteraction, backendId: UUID) { }
    func markSyncFailed(interaction: LocalInteraction, error: String) { }
    func resetSyncStatus(interaction: LocalInteraction) { }

    // Delete
    func deleteInteraction(interaction: LocalInteraction) { }
}
```

---

## 5. Complete Save Workflow

Let's trace a recording from start to finish:

### 5.1 User Records Audio

**Trigger**: User speaks into microphone and clicks stop

```
RecordingTabView (UI)
    ↓
RecordingViewModel.handleRecordingComplete()
    ↓
Transcription via OpenAI/ElevenLabs
    ↓
(Optional) Optimization via LLM
    ↓
InteractionStorageService.saveInteraction()
```

### 5.2 InteractionStorageService.saveInteraction()

**Location**: `Services/InteractionStorageService.swift:41-67`

```swift
func saveInteraction(
    transcription: String,
    refinedText: String?,
    audioDuration: Double?
) async throws -> LocalInteraction {

    // STEP 1: Create metadata object
    let metadata = InteractionMetadata(
        transcriptionApi: "OpenAI",           // From settings
        transcriptionModel: "whisper-1",      // From settings
        optimizationModel: "gpt-4o-mini",     // From settings (if optimized)
        optimizationLevel: "medium",          // From settings
        outputStyle: "conversational"         // From settings
    )

    // STEP 2: Save to local Core Data
    let localInteraction = localStorage.saveInteraction(
        transcription: transcription,
        refinedText: refinedText,
        teacherExplanation: nil,
        audioDuration: audioDuration,
        metadata: metadata
    )
    // ↑ This returns immediately - data is now in SQLite

    // STEP 3: Conditionally sync to backend (async, non-blocking)
    await attemptBackendSync(interaction: localInteraction)

    return localInteraction
}
```

### 5.3 LocalInteractionStorage.saveInteraction()

**Location**: `Services/LocalInteractionStorage.swift:30-75`

```swift
func saveInteraction(
    transcription: String,
    refinedText: String?,
    teacherExplanation: String?,
    audioDuration: Double?,
    metadata: InteractionMetadata
) -> LocalInteraction {

    // STEP 1: Get Core Data context (scratchpad)
    let context = coreData.viewContext

    // STEP 2: Create new NSManagedObject
    let interaction = LocalInteraction(context: context)

    // STEP 3: Set identity properties
    interaction.id = UUID()                    // Generate unique ID
    interaction.createdAt = Date()             // Current timestamp
    interaction.updatedAt = Date()

    // STEP 4: Set content properties
    interaction.originalTranscription = transcription
    interaction.refinedText = refinedText
    interaction.teacherExplanation = teacherExplanation

    // STEP 5: Set metadata properties
    interaction.transcriptionApi = metadata.transcriptionApi
    interaction.transcriptionModel = metadata.transcriptionModel
    interaction.optimizationModel = metadata.optimizationModel
    interaction.optimizationLevel = metadata.optimizationLevel
    interaction.outputStyle = metadata.outputStyle
    interaction.audioDuration = audioDuration ?? 0
    interaction.audioFileUrl = nil

    // STEP 6: Set sync status - default to pending
    interaction.syncStatusEnum = .pending      // Sets syncStatus = "pending"
    interaction.backendId = nil                // No backend ID yet
    interaction.lastSyncAttempt = nil
    interaction.syncErrorMessage = nil
    interaction.syncRetryCount = 0

    // STEP 7: Save to persistent store (writes to SQLite)
    coreData.saveContext()

    return interaction
}
```

### 5.4 CoreDataManager.saveContext()

```swift
func saveContext() {
    let context = persistentContainer.viewContext

    if context.hasChanges {
        do {
            try context.save()  // ← Commits to SQLite database
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError)")
        }
    }
}
```

**What happens during `context.save()`?**

```
context.save() called
    ↓
Core Data checks for changes
    ↓
Generates SQL INSERT statement:
    INSERT INTO ZLOCALINTERACTION (
        ZID, ZCREATEDAT, ZUPDATEDAT,
        ZORIGINALTRANSCRIPTION, ZREFINEDTEXT,
        ZSYNCSTATUS, ZAUDIODURATION, ...
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ...)
    ↓
Executes SQL on SQLite database
    ↓
Data is persisted to disk
    ↓
Returns success
```

### 5.5 Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User Records Audio                                       │
│    "Hello, this is a test recording"                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. RecordingViewModel                                       │
│    - Transcribes audio via OpenAI                           │
│    - (Optional) Optimizes with LLM                          │
│    - Calls InteractionStorageService.saveInteraction()      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. InteractionStorageService.saveInteraction()             │
│    - Prepares metadata from settings                        │
│    - Calls LocalInteractionStorage.saveInteraction()        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. LocalInteractionStorage.saveInteraction()               │
│    ┌────────────────────────────────────────────┐          │
│    │ let interaction = LocalInteraction(        │          │
│    │     context: context                       │          │
│    │ )                                          │          │
│    │                                            │          │
│    │ interaction.id = UUID()                    │          │
│    │ interaction.createdAt = Date()             │          │
│    │ interaction.originalTranscription = "..."  │          │
│    │ interaction.syncStatus = "pending"         │          │
│    │                                            │          │
│    │ coreData.saveContext() ← Writes to disk   │          │
│    └────────────────────────────────────────────┘          │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. CoreDataManager.saveContext()                           │
│    - Checks for changes in context                          │
│    - Generates SQL INSERT statement                         │
│    - Executes on SQLite database                            │
│    - Persists to disk                                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. File System                                              │
│                                                             │
│    ~/Library/Application Support/                           │
│        com.yourcompany.MindFlow/                            │
│            MindFlow.sqlite ← Data written here              │
│                                                             │
│    SQLite Row:                                              │
│    ┌──────────────────────────────────────────┐            │
│    │ Z_PK: 1                                  │            │
│    │ ZID: "3652B0A0-93C0-459F-BE82..."        │            │
│    │ ZCREATEDAT: 2025-10-14 08:23:15          │            │
│    │ ZORIGINALTRANSCRIPTION: "Hello, this..." │            │
│    │ ZSYNCSTATUS: "pending"                   │            │
│    │ ZAUDIODURATION: 45.2                     │            │
│    │ ZBACKENDID: NULL                         │            │
│    └──────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Query Operations

### 6.1 Fetch All Interactions

**Code**: `LocalInteractionStorage.fetchAllInteractions()`

```swift
func fetchAllInteractions() -> [LocalInteraction] {
    let request = LocalInteraction.fetchRequest()

    // Sort by creation date, newest first
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \LocalInteraction.createdAt, ascending: false)
    ]

    do {
        return try context.fetch(request)
    } catch {
        print("Failed to fetch: \(error)")
        return []
    }
}
```

**Generated SQL**:
```sql
SELECT * FROM ZLOCALINTERACTION
ORDER BY ZCREATEDAT DESC
```

### 6.2 Fetch Pending Sync Interactions

```swift
func fetchPendingSyncInteractions() -> [LocalInteraction] {
    let request = LocalInteraction.fetchRequest()

    // Filter: syncStatus == "pending" AND backendId == nil
    request.predicate = NSPredicate(
        format: "syncStatus == %@ AND backendId == nil",
        LocalInteraction.SyncStatus.pending.rawValue
    )

    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \LocalInteraction.createdAt, ascending: true)
    ]

    return try context.fetch(request)
}
```

**Generated SQL**:
```sql
SELECT * FROM ZLOCALINTERACTION
WHERE ZSYNCSTATUS = 'pending' AND ZBACKENDID IS NULL
ORDER BY ZCREATEDAT ASC
```

### 6.3 NSPredicate Query Examples

Core Data uses `NSPredicate` for filtering (similar to SQL WHERE clause):

```swift
// Find by ID
NSPredicate(format: "id == %@", someUUID)

// Find synced interactions
NSPredicate(format: "syncStatus == %@", "synced")

// Find failed with retries < 3
NSPredicate(format: "syncStatus == %@ AND syncRetryCount < %d", "failed", 3)

// Find interactions created today
let today = Calendar.current.startOfDay(for: Date())
NSPredicate(format: "createdAt >= %@", today as NSDate)

// Find by transcription API
NSPredicate(format: "transcriptionApi == %@", "OpenAI")

// Find long recordings
NSPredicate(format: "audioDuration >= %f", 30.0)

// Complex query
NSPredicate(format: "syncStatus == %@ AND audioDuration >= %f AND transcriptionApi == %@",
            "pending", 30.0, "OpenAI")
```

---

## 7. Sync Status Management

### 7.1 Marking as Synced

**When**: After successful backend API call

```swift
func markAsSynced(interaction: LocalInteraction, backendId: UUID) {
    interaction.syncStatusEnum = .synced         // Sets syncStatus = "synced"
    interaction.backendId = backendId            // Store backend UUID
    interaction.lastSyncAttempt = Date()         // Record sync time
    interaction.syncErrorMessage = nil           // Clear any error
    interaction.updatedAt = Date()               // Update timestamp

    coreData.saveContext()  // ← Commits to SQLite
}
```

**SQLite Update**:
```sql
UPDATE ZLOCALINTERACTION
SET ZSYNCSTATUS = 'synced',
    ZBACKENDID = 'DEF-456...',
    ZLASTSYNCATTEMPT = '2025-10-14 08:24:30',
    ZSYNCERRORMESSAGE = NULL,
    ZUPDATEDAT = '2025-10-14 08:24:30'
WHERE ZID = '3652B0A0-93C0-459F-BE82...'
```

### 7.2 Marking Sync Failed

**When**: Backend API call fails

```swift
func markSyncFailed(interaction: LocalInteraction, error: String) {
    interaction.syncStatusEnum = .failed         // Sets syncStatus = "failed"
    interaction.syncErrorMessage = error         // Store error message
    interaction.lastSyncAttempt = Date()         // Record attempt time
    interaction.syncRetryCount += 1              // Increment retry counter
    interaction.updatedAt = Date()

    coreData.saveContext()
}
```

### 7.3 State Transitions

```
┌─────────┐
│ pending │  ← Initial state when created
└────┬────┘
     │
     │ Auto-sync or Manual sync triggered
     │
     ├─────────────┐
     │             │
     ▼             ▼
┌─────────┐   ┌────────┐
│ synced  │   │ failed │
└─────────┘   └───┬────┘
                  │
                  │ Retry (if count < 3)
                  │
                  └──────────► back to pending
```

---

## 8. File System Storage

### 8.1 Database Location

```bash
~/Library/Application Support/com.yourcompany.MindFlow/
├── MindFlow.sqlite           # Main database (5-50 MB typical)
├── MindFlow.sqlite-shm       # Shared memory for WAL mode
└── MindFlow.sqlite-wal       # Write-ahead log
```

### 8.2 Inspecting the Database

You can inspect the database directly:

```bash
# Open database
sqlite3 ~/Library/Application\ Support/com.yourcompany.MindFlow/MindFlow.sqlite

# List tables
.tables

# View schema
.schema ZLOCALINTERACTION

# Query data
SELECT ZID, ZORIGINALTRANSCRIPTION, ZSYNCSTATUS, ZCREATEDAT
FROM ZLOCALINTERACTION
ORDER BY ZCREATEDAT DESC
LIMIT 5;

# Count records
SELECT COUNT(*) FROM ZLOCALINTERACTION;

# Count by sync status
SELECT ZSYNCSTATUS, COUNT(*)
FROM ZLOCALINTERACTION
GROUP BY ZSYNCSTATUS;
```

### 8.3 Data Size Considerations

**Per Interaction**:
- Metadata: ~500 bytes
- Transcription (average): 500-2000 bytes
- Refined text: 500-2000 bytes
- Teacher explanation: 1000-5000 bytes
- **Total per interaction**: ~2-10 KB

**Database Size Estimates**:
- 100 interactions: ~0.2-1 MB
- 1,000 interactions: ~2-10 MB
- 10,000 interactions: ~20-100 MB

**Note**: Core Data is efficient and can handle 100,000+ records easily.

---

## Complete Example: From Recording to Display

```swift
// 1. USER RECORDS AUDIO
RecordingViewModel.handleRecordingComplete()

// 2. TRANSCRIPTION
let transcription = await transcribe(audioData)
// Result: "Hello, this is a test recording about local storage"

// 3. OPTIMIZATION
let refined = await optimize(transcription)
// Result: "This test recording explains local storage architecture."

// 4. SAVE LOCALLY
let interaction = try await InteractionStorageService.shared.saveInteraction(
    transcription: transcription,
    refinedText: refined,
    audioDuration: 45.2
)

// Behind the scenes:
// ├── Creates LocalInteraction object
// ├── Sets all properties
// ├── interaction.syncStatus = "pending"
// ├── Saves to SQLite via Core Data
// └── Returns immediately

// 5. CONDITIONAL SYNC (async, non-blocking)
// Checks:
// ✓ Auto-sync enabled? Yes
// ✓ Authenticated? Yes
// ✓ Duration >= 30s? Yes (45.2s)
// → Syncs to backend

// 6. DISPLAY IN UI
LocalHistoryView.loadInteractions()
// ├── Queries Core Data
// ├── Returns array of LocalInteraction objects
// ├── SwiftUI displays in list
// └── Shows "Synced" badge (green)

// 7. USER CLICKS ON INTERACTION
// ├── Expands row
// ├── Shows full transcription
// ├── Shows refined text
// └── Shows sync status
```

---

## Summary

### Key Takeaways:

1. **Core Data** is the persistence framework (ORM layer)
2. **SQLite** is the actual database file on disk
3. **NSManagedObject** is the base class for entities
4. **NSManagedObjectContext** is the scratchpad for changes
5. **LocalInteractionStorage** provides CRUD interface
6. Data is saved **immediately** to SQLite when `saveContext()` is called
7. Queries use **NSFetchRequest** with predicates (like SQL WHERE)
8. Sync status is stored **locally** and tracks backend state
9. Database is located in **Application Support** folder
10. Each interaction is ~2-10 KB, allowing thousands of records

### Performance Notes:

- Core Data is **fast** for CRUD operations
- Queries are optimized with indexes
- Main thread context used for UI operations
- Background contexts can be added for heavy operations
- WAL mode enables concurrent reads during writes
- Typical query time: < 1ms for hundreds of records

This architecture provides:
- ✅ Offline-first capability
- ✅ Fast local access
- ✅ Conditional backend sync
- ✅ Sync status tracking
- ✅ Scalable to 10,000+ records
- ✅ Type-safe Swift API

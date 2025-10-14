# Implementation Plan: Local-First Storage with Manual Sync for MindFlow macOS

**Date:** 2025-10-14
**Platform:** macOS (Swift/SwiftUI)
**Feature:** Local history storage with configurable auto-sync threshold
**Status:** Planning Phase

---

## Executive Summary

Add the same "local-first, sync when valuable" architecture from the browser extension to the MindFlow macOS app. This allows users to:
- Store all interactions locally first
- Auto-sync only recordings above a threshold (default 30s)
- Manually sync any local-only recording later
- View sync status in the interaction history

---

## Current Architecture Analysis

### Current Flow (Direct Backend Sync)
```
Recording → Transcription → Optimization → Save to Backend → Show in History
                                                ↓
                                           (If fails, lost)
```

**Current Implementation:**
- `InteractionStorageService.swift` - Directly saves to backend via API
- `MindFlowAPIClient.swift` - Makes immediate POST to ZMemory
- `InteractionHistoryViewModel.swift` - Fetches from backend only
- No local persistence layer (UserDefaults or Core Data)

**Issues:**
- ❌ No offline support
- ❌ All recordings synced regardless of length
- ❌ Failed syncs = lost data
- ❌ No local history for quick reference

### Target Flow (Local-First with Smart Sync)
```
Recording → Transcription → Optimization → Save Locally
                                                ↓
                                    Check: Duration >= Threshold?
                                           ↙           ↘
                                      YES: Auto-sync    NO: Keep local
                                           ↓              ↓
                                    Mark as Synced   Show "Sync" button
```

---

## Implementation Plan

### Phase 1: Local Storage Layer (Foundation)
**Goal:** Add local persistence before changing sync behavior

#### Step 1.1: Choose Storage Technology
**Decision Matrix:**

| Technology | Pros | Cons | Recommendation |
|-----------|------|------|----------------|
| **UserDefaults** | Simple, fast for small data | Size limits (~1MB), no querying | ❌ Not suitable |
| **Core Data** | Full ORM, robust, efficient | More complex setup | ✅ **Recommended** |
| **SQLite (raw)** | Direct control | Manual SQL, no Swift integration | ❌ Unnecessary complexity |
| **SwiftData** | Modern, declarative | iOS 17+, less mature | ⚠️ Consider for future |

**Recommendation:** Use **Core Data**
- Mature, well-tested
- Efficient querying and filtering
- Background sync support
- Migration tools built-in

#### Step 1.2: Create Core Data Model
**File:** `MindFlow.xcdatamodeld`

**Entity:** `LocalInteraction`

```swift
// Attributes
id: UUID (Primary Key)
createdAt: Date
updatedAt: Date

// Content
originalTranscription: String
refinedText: String?
teacherExplanation: String?

// Metadata
transcriptionApi: String (e.g., "OpenAI", "ElevenLabs")
transcriptionModel: String? (e.g., "whisper-1")
optimizationModel: String? (e.g., "gpt-4o-mini")
optimizationLevel: String? (e.g., "light", "medium", "heavy")
outputStyle: String? (e.g., "conversational", "formal")
audioDuration: Double (in seconds)
audioFileUrl: String?

// Sync Status (NEW)
syncStatus: String (enum: "pending", "synced", "failed")
backendId: UUID? (ID from ZMemory after sync)
syncedAt: Date?
syncError: String? (for retry logic)
syncRetryCount: Int16 (default: 0)
```

**Computed Properties:**
```swift
extension LocalInteraction {
    var needsSync: Bool {
        return syncStatus == "pending" && backendId == nil
    }

    var isSynced: Bool {
        return syncStatus == "synced" && backendId != nil
    }

    var canRetrySync: Bool {
        return syncStatus == "failed" && syncRetryCount < 3
    }
}
```

#### Step 1.3: Create Core Data Manager
**File:** `CoreDataManager.swift`

```swift
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MindFlow")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ [CoreData] Save error: \(error)")
            }
        }
    }
}
```

#### Step 1.4: Create Local Storage Service
**File:** `LocalInteractionStorage.swift`

```swift
import CoreData

class LocalInteractionStorage {
    static let shared = LocalInteractionStorage()
    private let coreData = CoreDataManager.shared

    // MARK: - Create

    func saveInteraction(
        transcription: String,
        refinedText: String?,
        teacherExplanation: String?,
        audioDuration: Double?,
        metadata: InteractionMetadata
    ) -> LocalInteraction {
        let context = coreData.viewContext
        let interaction = LocalInteraction(context: context)

        interaction.id = UUID()
        interaction.createdAt = Date()
        interaction.updatedAt = Date()
        interaction.originalTranscription = transcription
        interaction.refinedText = refinedText
        interaction.teacherExplanation = teacherExplanation
        interaction.audioDuration = audioDuration ?? 0

        // Metadata
        interaction.transcriptionApi = metadata.transcriptionApi
        interaction.transcriptionModel = metadata.transcriptionModel
        interaction.optimizationModel = metadata.optimizationModel
        interaction.optimizationLevel = metadata.optimizationLevel
        interaction.outputStyle = metadata.outputStyle

        // Sync status
        interaction.syncStatus = "pending"
        interaction.syncRetryCount = 0

        coreData.saveContext()

        print("💾 [LocalStorage] Interaction saved locally: \(interaction.id)")
        return interaction
    }

    // MARK: - Read

    func fetchAllInteractions() -> [LocalInteraction] {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            return try coreData.viewContext.fetch(request)
        } catch {
            print("❌ [LocalStorage] Fetch error: \(error)")
            return []
        }
    }

    func fetchPendingSyncInteractions() -> [LocalInteraction] {
        let request: NSFetchRequest<LocalInteraction> = LocalInteraction.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", "pending")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            return try coreData.viewContext.fetch(request)
        } catch {
            print("❌ [LocalStorage] Fetch pending error: \(error)")
            return []
        }
    }

    // MARK: - Update

    func markAsSynced(interaction: LocalInteraction, backendId: UUID) {
        interaction.syncStatus = "synced"
        interaction.backendId = backendId
        interaction.syncedAt = Date()
        interaction.syncError = nil
        interaction.updatedAt = Date()

        coreData.saveContext()

        print("✅ [LocalStorage] Marked as synced: \(interaction.id)")
    }

    func markSyncFailed(interaction: LocalInteraction, error: String) {
        interaction.syncStatus = "failed"
        interaction.syncError = error
        interaction.syncRetryCount += 1
        interaction.updatedAt = Date()

        coreData.saveContext()

        print("❌ [LocalStorage] Sync failed: \(interaction.id) - \(error)")
    }

    // MARK: - Delete

    func deleteInteraction(_ interaction: LocalInteraction) {
        coreData.viewContext.delete(interaction)
        coreData.saveContext()
    }
}
```

---

### Phase 2: Update Storage Service (Smart Sync Logic)
**Goal:** Modify InteractionStorageService to save locally first, then conditionally sync

#### Step 2.1: Add Settings for Sync Threshold
**File:** `Settings.swift` (or preferences model)

```swift
extension Settings {
    // New properties
    @AppStorage("autoSyncToBackend") var autoSyncToBackend: Bool = true
    @AppStorage("autoSyncThreshold") var autoSyncThreshold: Double = 30.0 // seconds
}
```

#### Step 2.2: Refactor InteractionStorageService
**File:** `InteractionStorageService.swift`

```swift
class InteractionStorageService {
    static let shared = InteractionStorageService()

    private let apiClient = MindFlowAPIClient.shared
    private let localStorage = LocalInteractionStorage.shared
    private var settings: Settings { Settings.shared }

    // MARK: - Save with Smart Sync

    func saveInteraction(
        transcription: String,
        refinedText: String?,
        teacherExplanation: String?,
        audioDuration: Double?
    ) async throws -> LocalInteraction {
        print("💾 [Storage] Saving interaction...")

        // 1. Always save locally first
        let metadata = InteractionMetadata(
            transcriptionApi: settings.sttProvider.rawValue,
            transcriptionModel: getTranscriptionModel(),
            optimizationModel: refinedText != nil ? settings.llmModel.rawValue : nil,
            optimizationLevel: refinedText != nil ? settings.optimizationLevel.rawValue : nil,
            outputStyle: refinedText != nil ? settings.outputStyle.rawValue : nil
        )

        let localInteraction = localStorage.saveInteraction(
            transcription: transcription,
            refinedText: refinedText,
            teacherExplanation: teacherExplanation,
            audioDuration: audioDuration,
            metadata: metadata
        )

        print("✅ [Storage] Saved locally: \(localInteraction.id)")

        // 2. Check if should auto-sync
        let shouldAutoSync = checkShouldAutoSync(
            audioDuration: audioDuration,
            isAuthenticated: SupabaseAuthService.shared.isAuthenticated
        )

        if shouldAutoSync {
            print("🔄 [Storage] Auto-syncing to backend...")
            await syncToBackend(localInteraction)
        } else {
            print("⏭️ [Storage] Skipping auto-sync (below threshold or not authenticated)")
        }

        return localInteraction
    }

    // MARK: - Sync Logic

    private func checkShouldAutoSync(audioDuration: Double?, isAuthenticated: Bool) -> Bool {
        guard isAuthenticated else {
            print("⚠️ [Storage] Not authenticated, skipping auto-sync")
            return false
        }

        guard settings.autoSyncToBackend else {
            print("⚠️ [Storage] Auto-sync disabled in settings")
            return false
        }

        let duration = audioDuration ?? 0
        let threshold = settings.autoSyncThreshold

        if duration < threshold {
            print("⏭️ [Storage] Duration \(duration)s < threshold \(threshold)s, skipping auto-sync")
            return false
        }

        return true
    }

    func syncToBackend(_ localInteraction: LocalInteraction) async {
        do {
            let request = CreateInteractionRequest(
                originalTranscription: localInteraction.originalTranscription,
                transcriptionApi: localInteraction.transcriptionApi,
                transcriptionModel: localInteraction.transcriptionModel,
                refinedText: localInteraction.refinedText,
                optimizationModel: localInteraction.optimizationModel,
                optimizationLevel: localInteraction.optimizationLevel,
                outputStyle: localInteraction.outputStyle,
                teacherExplanation: localInteraction.teacherExplanation,
                audioDuration: localInteraction.audioDuration,
                audioFileUrl: localInteraction.audioFileUrl
            )

            let backendRecord = try await apiClient.createInteraction(request)

            // Mark as synced
            localStorage.markAsSynced(interaction: localInteraction, backendId: backendRecord.id!)

            print("✅ [Storage] Synced to backend: \(backendRecord.id!)")

        } catch {
            print("❌ [Storage] Sync failed: \(error.localizedDescription)")
            localStorage.markSyncFailed(interaction: localInteraction, error: error.localizedDescription)
        }
    }

    // MARK: - Manual Sync

    func manualSync(_ localInteraction: LocalInteraction) async throws {
        print("🔄 [Storage] Manual sync requested for: \(localInteraction.id)")
        await syncToBackend(localInteraction)
    }

    // MARK: - Fetch

    func fetchInteractions(limit: Int = 50, offset: Int = 0) async throws -> [LocalInteraction] {
        // Return from local storage
        return localStorage.fetchAllInteractions()
    }
}
```

---

### Phase 3: Update UI Components

#### Step 3.1: Add Settings UI for Sync Configuration
**File:** `SettingsView.swift`

```swift
Section("Backend Sync") {
    Toggle("Automatically sync to ZephyrOS", isOn: $settings.autoSyncToBackend)
        .help("Short recordings can be kept local-only and synced manually later")

    HStack {
        Text("Minimum duration for auto-sync")
        Spacer()
        TextField("Seconds", value: $settings.autoSyncThreshold, format: .number)
            .frame(width: 60)
            .textFieldStyle(.roundedBorder)
        Text("seconds")
            .foregroundColor(.secondary)
    }
    .help("Recordings shorter than this will only be stored locally unless manually synced")
}
```

#### Step 3.2: Update InteractionHistoryView with Sync Status
**File:** `InteractionHistoryView.swift`

```swift
struct InteractionRowView: View {
    let interaction: LocalInteraction
    let onSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing content...
            Text(interaction.refinedText ?? interaction.originalTranscription)
                .lineLimit(3)

            HStack(spacing: 12) {
                // Duration badge
                if interaction.audioDuration > 0 {
                    Label("\(Int(interaction.audioDuration))s", systemImage: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Sync status badge
                syncStatusBadge
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var syncStatusBadge: some View {
        switch interaction.syncStatus {
        case "synced":
            Label("Synced", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)

        case "pending":
            if SupabaseAuthService.shared.isAuthenticated {
                Button(action: onSync) {
                    Label("Sync", systemImage: "arrow.up.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                Label("Local only", systemImage: "laptop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case "failed":
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Failed")
                Button("Retry", action: onSync)
            }
            .font(.caption)

        default:
            EmptyView()
        }
    }
}
```

#### Step 3.3: Update ViewModel to Handle Local Storage
**File:** `InteractionHistoryViewModel.swift`

```swift
@MainActor
class InteractionHistoryViewModel: ObservableObject {
    @Published var interactions: [LocalInteraction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSyncing: [UUID: Bool] = [:] // Track sync status per interaction

    private let storageService = InteractionStorageService.shared

    func loadInteractions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            interactions = try await storageService.fetchInteractions()
            print("✅ [HistoryVM] Loaded \(interactions.count) local interactions")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [HistoryVM] Load error: \(error)")
        }
    }

    func syncInteraction(_ interaction: LocalInteraction) async {
        isSyncing[interaction.id] = true
        defer { isSyncing[interaction.id] = false }

        do {
            try await storageService.manualSync(interaction)
            await loadInteractions() // Refresh to show updated status
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
    }
}
```

---

### Phase 4: Background Sync Queue (Optional Enhancement)

#### Step 4.1: Create Sync Queue Service
**File:** `SyncQueueService.swift`

```swift
import Foundation

class SyncQueueService {
    static let shared = SyncQueueService()

    private let localStorage = LocalInteractionStorage.shared
    private let storageService = InteractionStorageService.shared
    private var isSyncing = false

    // MARK: - Background Sync

    func syncPendingInteractions() async {
        guard !isSyncing else { return }
        guard SupabaseAuthService.shared.isAuthenticated else { return }

        isSyncing = true
        defer { isSyncing = false }

        let pending = localStorage.fetchPendingSyncInteractions()
        print("🔄 [SyncQueue] Found \(pending.count) pending interactions")

        for interaction in pending {
            await storageService.syncToBackend(interaction)

            // Add delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        print("✅ [SyncQueue] Sync complete")
    }

    func startPeriodicSync() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.syncPendingInteractions()
            }
        }
    }
}
```

#### Step 4.2: Add to App Lifecycle
**File:** `MindFlowApp.swift`

```swift
@main
struct MindFlowApp: App {
    init() {
        // Start background sync on app launch
        Task {
            await SyncQueueService.shared.syncPendingInteractions()
        }

        // Enable periodic sync
        SyncQueueService.shared.startPeriodicSync()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

### Phase 5: Data Migration Strategy

#### Step 5.1: Handle Existing Users
**Challenge:** Existing users have no local data, only backend data

**Solution Options:**

**Option A: Fresh Start (Simplest)**
```swift
// On first launch with new version
if !UserDefaults.standard.bool(forKey: "hasLocalStorage") {
    // Show alert: "Starting fresh with local storage"
    // Existing backend data remains accessible on Zflow
    UserDefaults.standard.set(true, forKey: "hasLocalStorage")
}
```

**Option B: One-Time Sync from Backend (Complex)**
```swift
func migrateBackendDataToLocal() async {
    // Fetch recent interactions from backend
    let backendInteractions = try await apiClient.getInteractions(limit: 100)

    // Save to local storage
    for record in backendInteractions {
        let local = localStorage.saveInteraction(
            transcription: record.originalTranscription,
            refinedText: record.refinedText,
            // ... other fields
        )

        // Mark as already synced
        localStorage.markAsSynced(interaction: local, backendId: record.id)
    }
}
```

**Recommendation:** Start with **Option A** for simplicity. Add Option B later if users request it.

---

## Implementation Roadmap

### Sprint 1: Foundation (Week 1-2)
- [ ] Create Core Data model (`LocalInteraction` entity)
- [ ] Implement `CoreDataManager`
- [ ] Implement `LocalInteractionStorage`
- [ ] Write unit tests for local storage
- [ ] Add sync threshold settings to `Settings.swift`

### Sprint 2: Storage Service Refactor (Week 3-4)
- [ ] Refactor `InteractionStorageService` to save locally first
- [ ] Implement auto-sync threshold logic
- [ ] Add manual sync method
- [ ] Update error handling
- [ ] Write integration tests

### Sprint 3: UI Updates (Week 5-6)
- [ ] Add sync settings to Settings view
- [ ] Update `InteractionRowView` with sync status badges
- [ ] Add sync button to interaction rows
- [ ] Update `InteractionHistoryViewModel` for local data
- [ ] Polish UI/UX

### Sprint 4: Background Sync (Week 7-8)
- [ ] Implement `SyncQueueService`
- [ ] Add periodic background sync
- [ ] Handle retry logic for failed syncs
- [ ] Add network reachability check
- [ ] Test offline scenarios

### Sprint 5: Testing & Polish (Week 9-10)
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] Handle migration for existing users
- [ ] Update documentation
- [ ] Beta testing

---

## Technical Considerations

### 1. **Conflict Resolution**
**Scenario:** User edits interaction on web, then syncs from macOS

**Solution:**
- Use `updatedAt` timestamps
- Backend wins (most recent)
- Or: Show conflict resolution UI

### 2. **Storage Limits**
**Core Data:**
- No hard limit (uses SQLite)
- Typical: 100-1000 interactions = ~1-10MB
- Implement cleanup: Delete synced entries older than 90 days

### 3. **Performance**
**Fetch Performance:**
- Use `NSFetchedResultsController` for live updates
- Implement pagination (load 50 at a time)
- Index `createdAt` and `syncStatus` columns

### 4. **Data Privacy**
**Local Storage Security:**
- Core Data SQLite file is encrypted on disk (macOS FileVault)
- Consider adding app-level encryption for sensitive data
- Respect user's "Clear History" preference

---

## Testing Strategy

### Unit Tests
```swift
class LocalInteractionStorageTests: XCTestCase {
    func testSaveInteraction() {
        // Given
        let storage = LocalInteractionStorage.shared

        // When
        let interaction = storage.saveInteraction(
            transcription: "Test",
            refinedText: nil,
            teacherExplanation: nil,
            audioDuration: 25.0,
            metadata: testMetadata
        )

        // Then
        XCTAssertEqual(interaction.syncStatus, "pending")
        XCTAssertNil(interaction.backendId)
    }

    func testAutoSyncThreshold() async throws {
        // Given
        let service = InteractionStorageService.shared
        Settings.shared.autoSyncThreshold = 30.0

        // When: Save 25s recording
        let interaction = try await service.saveInteraction(
            transcription: "Short",
            refinedText: nil,
            teacherExplanation: nil,
            audioDuration: 25.0
        )

        // Then: Should NOT auto-sync
        XCTAssertEqual(interaction.syncStatus, "pending")
        XCTAssertNil(interaction.backendId)
    }
}
```

### Integration Tests
- Test full flow: Record → Save Locally → Auto-Sync
- Test manual sync from history
- Test retry logic for failed syncs
- Test offline mode

---

## Success Metrics

### Functional
- ✅ All recordings save locally first
- ✅ Recordings >30s auto-sync when authenticated
- ✅ Manual sync button works for local-only entries
- ✅ Sync status displayed correctly
- ✅ No data loss on network failures

### Performance
- ✅ Local save completes in <100ms
- ✅ History loads in <200ms for 100 entries
- ✅ Background sync doesn't block UI

### User Experience
- ✅ Clear visual distinction between synced and local-only
- ✅ Easy to manually sync individual recordings
- ✅ Settings are intuitive and discoverable

---

## Related Documentation

- [Browser Extension: Configurable Auto-Sync](../features/configurable-auto-sync-threshold.md)
- [API: ZMemory Integration](../api/zmemory-integration.md)
- [Core Data Best Practices](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)

---

## Summary

This plan brings the same intelligent sync behavior from the browser extension to macOS:

1. **Local-First:** All recordings saved locally immediately
2. **Smart Sync:** Auto-sync only valuable content (>30s by default)
3. **Manual Control:** Users can sync anything manually
4. **Offline Support:** Works without internet
5. **Visual Feedback:** Clear sync status in UI

**Estimated Timeline:** 10 weeks (with testing)
**Complexity:** Medium-High (Core Data setup + refactoring)
**Risk:** Low (local storage is additive, doesn't break existing flow)

The implementation follows iOS/macOS best practices using Core Data for robust local persistence and maintains backward compatibility with the existing backend API.

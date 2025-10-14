# MindFlow Chrome Extension - Permission Justifications

This document explains every permission requested by the MindFlow Chrome Extension and why it's necessary for core functionality. This information is provided for transparency and for Chrome Web Store review purposes.

## Required Permissions

### 1. `storage`

**Purpose**: Store user settings and API keys securely

**Usage Details**:
- Store API keys for OpenAI, ElevenLabs, and ZephyrOS using `chrome.storage.sync`
- `chrome.storage.sync` provides encryption at rest and syncs across user's devices
- Store user preferences (selected API providers, UI settings, recording options)
- Store local transcription history (if enabled by user)
- No user data is collected or transmitted to any MindFlow server

**Code References**:
- `src/lib/storage-manager.js` - Lines 30-65: API key storage and retrieval
- `src/lib/history-manager.js` - Lines 20-45: Local history storage

**Privacy**:
- All data stored locally or synced via Chrome's encrypted sync
- API keys never leave the user's device except for direct API calls to configured providers
- No analytics or tracking data stored

---

### 2. `activeTab`

**Purpose**: Insert transcribed and optimized text into the currently active input field

**Usage Details**:
- Only activates when user explicitly clicks the "Insert" button after transcription
- Allows reading the currently focused input field to insert text at cursor position
- Does not grant access to page content except when user initiates insertion
- No automatic data collection or injection

**Code References**:
- `src/content/content-script.js` - Lines 45-78: Text insertion into active input fields
- `src/popup/popup.js` - Lines 156-189: Handles "Insert Text" button click

**Privacy**:
- Only accesses the active tab when user explicitly requests text insertion
- Does not read or collect any webpage data
- No background access to tabs

---

### 3. `scripting`

**Purpose**: Execute content scripts to detect active input fields and insert text at cursor position

**Usage Details**:
- Required to inject the content script that performs text insertion
- Used to detect the type of input field (textarea, input, contenteditable)
- Inserts text at the correct cursor position, preserving existing content
- Only executes when user explicitly clicks "Insert Text"

**Code References**:
- `src/background/service-worker.js` - Lines 89-112: Content script injection on user action
- `src/content/content-script.js` - Lines 10-95: Input field detection and text insertion

**Privacy**:
- Scripts only execute on explicit user action
- Does not read or modify page content except for text insertion
- No persistent scripts running in background

---

### 4. `offscreen`

**Purpose**: Record audio in the background using the Offscreen API

**Usage Details**:
- Chrome Manifest V3 requires audio recording to occur in an offscreen document
- Service workers cannot access `navigator.mediaDevices` directly
- Offscreen document handles audio capture while user interacts with popup
- Audio is processed immediately and deleted after transcription

**Code References**:
- `src/background/service-worker.js` - Lines 45-67: Offscreen document creation
- `src/offscreen/offscreen.js` - Lines 15-89: Audio recording implementation

**Privacy**:
- Audio is only captured when user explicitly starts recording (button click)
- Audio is temporarily held in memory, never saved to disk
- Audio is deleted immediately after transcription
- Microphone indicator shows when recording is active

---

### 5. `identity`

**Purpose**: Authenticate with ZephyrOS cloud sync service (optional feature)

**Usage Details**:
- Only used if user enables ZephyrOS cloud sync
- Handles OAuth authentication flow for ZephyrOS/Supabase
- Retrieves authentication tokens for syncing transcription history
- Completely optional - extension works without this feature

**Code References**:
- `src/lib/auth-manager.js` - Lines 23-67: OAuth authentication flow
- `src/lib/sync-manager.js` - Lines 34-78: Cloud sync implementation

**Privacy**:
- Only used if user explicitly enables cloud sync
- Authentication handled by Supabase OAuth (secure standard)
- No credentials stored except encrypted tokens in chrome.storage.sync
- User can disable at any time

---

## Host Permissions

### 1. `https://api.openai.com/*`

**Purpose**: Transcribe audio using OpenAI Whisper API and optimize text using GPT API

**Usage Details**:
- Send audio files to Whisper API for speech-to-text transcription
- Send transcribed text to GPT API for grammar correction and filler word removal
- User provides their own OpenAI API key
- Direct connection between extension and OpenAI (no intermediary)

**Data Flow**:
- Audio blob → OpenAI Whisper API → Transcribed text
- Raw text → OpenAI GPT API → Optimized text
- No data sent to any other server

**Privacy**:
- User must provide their own API key
- Data sent directly to OpenAI (no MindFlow server in between)
- Subject to OpenAI's privacy policy: https://openai.com/privacy
- User is responsible for OpenAI account and usage

---

### 2. `https://api.elevenlabs.io/*`

**Purpose**: Alternative speech-to-text transcription provider (optional)

**Usage Details**:
- User can choose ElevenLabs instead of OpenAI for transcription
- Send audio files to ElevenLabs Speech-to-Text API
- User provides their own ElevenLabs API key
- Completely optional feature

**Data Flow**:
- Audio blob → ElevenLabs API → Transcribed text
- No data sent to any other server

**Privacy**:
- Only used if user configures ElevenLabs as STT provider
- User must provide their own API key
- Data sent directly to ElevenLabs (no intermediary)
- Subject to ElevenLabs privacy policy: https://elevenlabs.io/privacy

---

### 3. `https://zmemory.zephyros.app/*`

**Purpose**: Optional cloud sync and history storage via ZephyrOS

**Usage Details**:
- User can enable cloud sync to store transcription history across devices
- Syncs transcribed text and metadata to ZephyrOS backend
- Completely optional feature (local-only mode available)
- User must authenticate with ZephyrOS account

**Data Flow**:
- Transcription metadata → ZephyrOS API → Cloud storage
- Synced history ← ZephyrOS API ← Other user devices

**Privacy**:
- Only used if user explicitly enables cloud sync
- User must create ZephyrOS account and authenticate
- Data encrypted in transit and at rest
- Subject to ZephyrOS privacy policy

---

### 4. `https://*.supabase.co/*`

**Purpose**: Backend infrastructure for ZephyrOS (Supabase-hosted)

**Usage Details**:
- ZephyrOS uses Supabase as its backend platform
- Handles authentication (OAuth), database, and storage
- Only accessed when user enables ZephyrOS integration
- Required for cloud sync feature

**Data Flow**:
- Authentication tokens, transcription history, user preferences
- All communication encrypted with HTTPS

**Privacy**:
- Only used with ZephyrOS cloud sync feature
- Subject to Supabase privacy policy: https://supabase.com/privacy
- User can disable cloud sync and use local-only mode

---

### 5. `<all_urls>` ⚠️

**Purpose**: Allow content script to run on any webpage for text insertion

**Current Status**: This permission is overly broad and needs refinement

**Justification**:
- Content script needs to run on any website where user wants to insert text
- Used for detecting input fields (textarea, input, contenteditable)
- Enables text insertion in Gmail, Google Docs, Twitter, Reddit, etc.

**Limitations**:
- Content script only activates on explicit user action (Insert button)
- Does not read or collect any webpage data
- Does not modify page content except for text insertion at cursor

**Alternative Approach** (Recommended):
- Rely on `activeTab` permission instead of `<all_urls>`
- Inject content script only when user clicks "Insert Text"
- This reduces permission scope while maintaining functionality

**Note**: This permission may trigger Chrome Web Store review concerns. Consider refactoring to use `activeTab` with dynamic script injection instead.

---

## Content Script Matching

### `<all_urls>` in content_scripts

**Current Configuration**:
```json
"content_scripts": [
  {
    "matches": ["<all_urls>"],
    "js": ["src/content/content-script.js"],
    "run_at": "document_idle"
  }
]
```

**Purpose**: Enable text insertion on any website

**Privacy Considerations**:
- Content script runs in "document_idle" mode (after page load)
- Only listens for messages from extension popup
- Does not automatically read or modify page content
- Does not send any page data to external servers

**Recommended Change**:
- Remove content_scripts declaration entirely
- Inject content script dynamically only when user clicks "Insert Text"
- This eliminates the need for `<all_urls>` host permission
- Provides same functionality with minimal permissions

---

## Permission Comparison

| Permission | Required | Optional | User Benefit | Alternative |
|------------|----------|----------|--------------|-------------|
| `storage` | ✅ Required | - | Store settings and API keys securely | None - essential |
| `activeTab` | ✅ Required | - | Insert text into active input field | None - essential |
| `scripting` | ✅ Required | - | Detect input fields and insert text | None - essential |
| `offscreen` | ✅ Required | - | Record audio in Manifest V3 | None - Manifest V3 requirement |
| `identity` | - | ✅ Optional | Cloud sync across devices | Local-only mode |
| `api.openai.com` | ✅ Required | - | Transcribe and optimize text | Use ElevenLabs instead |
| `api.elevenlabs.io` | - | ✅ Optional | Alternative transcription provider | Use OpenAI instead |
| `zmemory.zephyros.app` | - | ✅ Optional | Cloud sync and backup | Local-only mode |
| `*.supabase.co` | - | ✅ Optional | ZephyrOS backend infrastructure | Local-only mode |
| `<all_urls>` | ⚠️ Review | - | Run content script on any page | Use activeTab with dynamic injection |

---

## Minimal Permissions Principle

MindFlow follows the **principle of least privilege**:

1. **Core Permissions**: Only 4 essential permissions for basic functionality
   - `storage`, `activeTab`, `scripting`, `offscreen`

2. **Optional Features**: Cloud sync is completely optional
   - Can be disabled entirely for a local-only experience
   - Extension fully functional without `identity` or ZephyrOS permissions

3. **User Control**: Users choose which API providers to use
   - Can use OpenAI only (no ElevenLabs permission needed)
   - Can use ElevenLabs only (but OpenAI still recommended for text optimization)

4. **No Tracking**: Zero analytics, telemetry, or data collection
   - Permissions are not used to track user behavior
   - No data sent to MindFlow servers (we don't have any)

---

## Chrome Web Store Review Notes

**For Chrome Web Store Reviewers**:

1. **Single Purpose**: Voice-to-text transcription with AI optimization
   - Record voice → Transcribe → Optimize → Insert into input field
   - No secondary purposes or hidden functionality

2. **No Data Collection**: MindFlow has no backend server
   - All data processing happens client-side or directly with user's API providers
   - No analytics, tracking, or telemetry

3. **User Privacy**: Privacy-first architecture
   - API keys stored in encrypted chrome.storage.sync
   - Audio deleted immediately after processing
   - No persistent storage of voice recordings
   - See PRIVACY.md for full privacy policy

4. **Permissions Justification**: Every permission serves core functionality
   - No permissions used for ads, affiliate links, or data harvesting
   - Optional permissions clearly marked (identity, ElevenLabs, ZephyrOS)

5. **Recommended Improvement**: Remove `<all_urls>` permission
   - Use dynamic script injection with `activeTab` instead
   - Reduces permission scope without losing functionality

---

## User Transparency

Users can review:
- This document: Full permission explanations
- PRIVACY.md: Complete privacy policy
- README.md: Feature overview and setup instructions
- Source code: Extension is open source (available on GitHub)

---

## Questions or Concerns

If you have questions about our permission usage:
- Open an issue on GitHub: https://github.com/[your-username]/MindFlow/issues
- Email: [your-email@example.com]
- Review our source code: All permission usage is documented and auditable

---

**Last Updated**: October 14, 2025
**Extension Version**: 0.1.0
**Manifest Version**: 3

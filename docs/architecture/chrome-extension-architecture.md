# MindFlow Chrome Extension Architecture

## Overview

MindFlow Chrome Extension is built using **Manifest V3** with a modular architecture that separates concerns between UI, business logic, and external API integrations.

## Core architecture

### High-level component diagram

```
┌─────────────────────────────────────────────────────┐
│                    Popup UI                         │
│  (User Interface - Recording/Results Display)       │
└──────────────┬──────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│              Service Worker                          │
│  (Background Logic - Message Router)                 │
└──────┬──────────────────────────────────────┬────────┘
       ↓                                      ↓
┌──────────────────┐                  ┌──────────────────┐
│ Offscreen Doc    │                  │  Content Script  │
│                  │                  │                  │
│ • MediaRecorder  │                  │ • Text Insertion │
│ • getUserMedia() │                  │ • Field Detection│
│                  │                  │                  │
└──────┬───────────┘                  └──────────────────┘
       ↓
┌──────────────────┐
│  Core Services   │
│                  │
│ • STTService     │
│ • LLMService     │
│ • StorageManager │
└──────┬───────────┘
       ↓
┌──────────────────────────────────────────────────────┐
│              chrome.storage.sync                     │
│  (Encrypted Storage - Settings & API Keys)           │
└──────────────────────────────────────────────────────┘
       ↓
┌──────────────────────────────────────────────────────┐
│           External APIs                              │
│  • OpenAI Whisper (STT)                              │
│  • OpenAI GPT-4o-mini (Text Optimization)            │
│  • ElevenLabs (Alternative STT)                      │
└──────────────────────────────────────────────────────┘
```

## Component details

### 1. Popup UI (`src/popup/`)

**Purpose**: User-facing interface for recording and viewing results

**Files**:
- `popup.html` - UI structure
- `popup.js` - UI controller with state management
- `popup.css` - Styling (macOS-inspired design)

**Responsibilities**:
- Display recording controls and status
- Show transcription and optimization results
- Handle user interactions (start/stop/copy/insert)
- Manage UI state transitions
- Display errors and loading states

**State machine**:
```
IDLE → RECORDING → PROCESSING → TRANSCRIBING → OPTIMIZING → COMPLETED
         ↓                                                      ↓
       PAUSED                                                 ERROR
```

### 2. Service worker (`src/background/service-worker.js`)

**Purpose**: Background event handler and message router

**Key responsibilities**:
- Route messages between popup and offscreen document
- Handle keyboard shortcuts
- Manage extension lifecycle (install/update/startup)
- Insert text into active tabs via content scripts
- Persist recording state across service worker restarts

**Message routing**:
```javascript
// Audio recording messages → Offscreen document
START_RECORDING
STOP_RECORDING
PAUSE_RECORDING
RESUME_RECORDING
GET_AUDIO_LEVEL
CANCEL_RECORDING

// Other messages → Handled directly
INSERT_TEXT → Content script
GET_SETTINGS → Storage
SAVE_SETTINGS → Storage
```

### 3. Offscreen document (`src/offscreen/`)

**Purpose**: Handle microphone access and audio recording

**Why needed**: Chrome extension popups cannot request microphone permissions. The permission dialog only appears when called from an offscreen document context (Manifest V3 requirement).

**Files**:
- `offscreen.html` - Minimal HTML shell
- `offscreen.js` - Audio recording implementation

**Key features**:
- `getUserMedia()` for microphone access
- MediaRecorder API for audio capture
- Audio level monitoring for waveform visualization
- Blob creation and base64 encoding for message passing

**Lifecycle**:
```
Service worker creates offscreen document
    ↓
Popup sends START_RECORDING message
    ↓
Service worker routes to offscreen (target: 'offscreen')
    ↓
Offscreen calls getUserMedia() - permission prompt appears!
    ↓
Audio recording starts
    ↓
Popup sends STOP_RECORDING
    ↓
Offscreen returns audio blob (as base64)
```

### 4. Content script (`src/content/content-script.js`)

**Purpose**: Insert optimized text into web page input fields

**Injected into**: Active tab when user clicks "Insert"

**Capabilities**:
- Detect active input field (textarea, input, contenteditable)
- Find cursor position
- Insert text at cursor
- Handle various frameworks (React, Vue, Angular)
- Fire change events to trigger app logic

**Supported field types**:
- `<textarea>` elements
- `<input type="text">` elements
- `contenteditable` elements
- Rich text editors (limited support)

### 5. Core services (`src/lib/`)

#### AudioRecorder (`audio-recorder.js`)

**Purpose**: High-level audio recording interface

**Pattern**: Singleton instance, delegates to offscreen document

**Key methods**:
- `startRecording()` - Initiate recording via offscreen
- `stopRecording()` - Stop and retrieve audio blob
- `pauseRecording()` / `resumeRecording()` - Pause/resume
- `getAudioLevel()` - Get current audio level for visualization
- `cleanup()` - Release resources

#### STTService (`stt-service.js`)

**Purpose**: Speech-to-text transcription

**Supported providers**:
- OpenAI Whisper API (primary)
- ElevenLabs STT (alternative)

**Key features**:
- Provider abstraction
- Audio format handling
- Error handling (401, 429, network errors)
- Retry logic with exponential backoff

#### LLMService (`llm-service.js`)

**Purpose**: Text optimization using GPT models

**Features**:
- Three optimization levels (light/medium/heavy)
- Two output styles (casual/formal)
- System prompt engineering
- Token optimization
- Streaming support (future)

#### StorageManager (`storage-manager.js`)

**Purpose**: Wrapper around chrome.storage APIs

**Manages**:
- API keys (encrypted via chrome.storage.sync)
- User settings (optimization level, provider, etc.)
- Recording state persistence
- Optional history (chrome.storage.local)

**Key features**:
- Type-safe getters/setters
- Default value handling
- Migration support
- Storage quota monitoring

## Data flow

### Complete workflow

```
1. User clicks "Start Recording"
     ↓
2. Popup → Service Worker → Offscreen Document
     ↓
3. Offscreen calls getUserMedia() [Permission prompt]
     ↓
4. MediaRecorder starts capturing audio
     ↓
5. Audio level sent back for waveform visualization
     ↓
6. User clicks "Stop & Process"
     ↓
7. Offscreen creates audio blob, converts to base64
     ↓
8. Blob passed back to Popup via Service Worker
     ↓
9. Popup → STTService → OpenAI Whisper API
     ↓
10. Transcribed text received
     ↓
11. Popup → LLMService → OpenAI GPT API
     ↓
12. Optimized text received
     ↓
13. Display both texts in result view
     ↓
14. User clicks "Insert"
     ↓
15. Popup → Service Worker → Content Script
     ↓
16. Content script inserts text into active field
     ↓
17. Done! Popup closes or resets for new recording
```

### Message passing

#### Popup ↔ Service Worker

```javascript
// Popup sends
chrome.runtime.sendMessage({
  type: 'START_RECORDING'
});

// Service worker receives and routes
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (audioMessages.includes(request.type)) {
    routeToOffscreen(request, sendResponse);
  }
});
```

#### Service Worker ↔ Offscreen Document

```javascript
// Service worker adds target flag
request.target = 'offscreen';
chrome.runtime.sendMessage(request, callback);

// Offscreen filters messages
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.target === 'offscreen') {
    handleMessage(message, sendResponse);
    return true;
  }
});
```

#### Service Worker → Content Script

```javascript
// Service worker injects and sends
await chrome.scripting.executeScript({
  target: { tabId: tab.id },
  files: ['src/content/content-script.js']
});

await chrome.tabs.sendMessage(tab.id, {
  type: 'INSERT_TEXT',
  text: optimizedText
});
```

## Storage architecture

### chrome.storage.sync (encrypted)

**Purpose**: Store user settings and API keys, synced across devices

**Storage structure**:
```javascript
{
  // API Keys (encrypted at rest by Chrome)
  'apiKey_openai': 'sk-...',
  'apiKey_elevenlabs': 'xi-...',

  // Settings object
  'settings': {
    sttProvider: 'openai',
    llmModel: 'gpt-4o-mini',
    optimizationLevel: 'medium',
    outputStyle: 'casual',
    autoInsert: true,
    showNotifications: true,
    keepHistory: false,
    theme: 'auto'
  }
}
```

**Limits**:
- Total: 100KB
- Per item: 8KB
- Sufficient for our use case

### chrome.storage.local

**Purpose**: Store optional history (not synced)

**Structure**:
```javascript
{
  'history': [
    {
      id: 'timestamp-uuid',
      timestamp: 1234567890,
      original: 'Um so like...',
      optimized: 'I think we should...',
      level: 'medium',
      provider: 'openai',
      model: 'gpt-4o-mini'
    },
    // ... more entries
  ]
}
```

**Limits**:
- Total: 5MB (10MB with unlimited permission)
- Cleanup old entries when approaching limit

## Security architecture

### API key protection

**Storage**:
- Keys stored in chrome.storage.sync
- Encrypted at rest by Chrome
- Never stored in code or logs

**Usage**:
```javascript
// ✅ CORRECT - Fetch from storage
const apiKey = await storageManager.getAPIKey('openai');

// ❌ NEVER - Hardcoded
const API_KEY = 'sk-1234...'; // NEVER DO THIS
```

**Logging**:
```javascript
// ✅ CORRECT - No sensitive data
logError('API request failed:', error.status);

// ❌ NEVER - Exposes key
console.error('Failed with key:', apiKey); // NEVER DO THIS
```

### Content Security Policy

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'"
  }
}
```

**Rules**:
- No `eval()` or `new Function()`
- No inline scripts
- No remote code execution
- All scripts bundled with extension

### Input validation

```javascript
// All inputs validated before use
function insertText(text) {
  if (typeof text !== 'string') {
    throw new TypeError('Text must be a string');
  }

  if (text.length > 10000) {
    throw new Error('Text too long');
  }

  const sanitized = text.replace(/[<>]/g, '');
  return sanitized;
}
```

## Error handling

### Error propagation

```
Low-level error (API, network, permission)
    ↓
Caught by service layer (STTService, LLMService)
    ↓
Wrapped in user-friendly error message
    ↓
Passed back to Popup
    ↓
Displayed in error view with retry option
```

### Error types

```javascript
// Custom error classes
class RecordingError extends Error {
  constructor(message) {
    super(message);
    this.name = 'RecordingError';
  }
}

class APIError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'APIError';
    this.status = status;
  }
}
```

### User-friendly messages

```javascript
// Map technical errors to user messages
function getUserErrorMessage(error) {
  if (error.message.includes('API key')) {
    return 'Invalid API key. Please check your settings.';
  }

  if (error.status === 429) {
    return 'Rate limit exceeded. Please try again later.';
  }

  if (error.name === 'NotAllowedError') {
    return 'Microphone access denied. Please enable permissions.';
  }

  return 'An error occurred. Please try again.';
}
```

## Performance considerations

### Service worker lifecycle

**Challenge**: Service workers can be terminated by Chrome after ~30 seconds of inactivity

**Solution**: Persist critical state to storage

```javascript
// Save state before termination
async function startRecording() {
  await chrome.storage.local.set({
    recordingState: 'recording',
    startTime: Date.now()
  });
}

// Restore on wake
chrome.runtime.onStartup.addListener(async () => {
  const { recordingState } = await chrome.storage.local.get('recordingState');
  if (recordingState === 'recording') {
    // Clean up interrupted recording
  }
});
```

### Bundle size optimization

- Use ES modules for tree-shaking
- Lazy load non-critical code
- Minify production build
- Target: < 5MB total size

### Audio optimization

```javascript
// Reasonable quality for voice
const mediaRecorder = new MediaRecorder(stream, {
  mimeType: 'audio/webm;codecs=opus',
  audioBitsPerSecond: 128000 // Not overkill for voice
});
```

## Testing strategy

### Unit tests

- Core services (AudioRecorder, STTService, LLMService)
- Storage manager
- Utility functions
- Error handling

### Integration tests

- Full workflow (record → transcribe → optimize)
- Settings persistence
- Message passing between components

### Manual testing

- Test on 10+ websites (Gmail, Docs, Twitter, Reddit)
- Different input field types
- Error scenarios (invalid API key, network errors)
- Permission flows
- Keyboard shortcuts

## Browser compatibility

### Minimum requirements

- Chrome 88+ (Manifest V3 support)
- Edge 88+ (Chromium-based)
- Brave (current version)
- Opera (current version)

### Feature detection

```javascript
// Check MediaRecorder support
if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
  throw new Error('Browser does not support audio recording');
}

// Check clipboard API
if (!navigator.clipboard) {
  // Fall back to execCommand
}
```

## Deployment architecture

### Development

```
src/ → Load unpacked in chrome://extensions
```

### Production

```
src/ → Build (optional minification) → .zip → Chrome Web Store
```

### Auto-updates

Chrome Web Store handles:
- Automatic updates for users
- Gradual rollout (configurable)
- Version management

## Related documentation

- [Implementation Plan](./chrome-extension-plan.md)
- [Chrome Extension Standards](../../spec/coding-regulations/chrome-extension-standards.md)
- [Permission Troubleshooting](../troubleshooting/chrome-extension-permissions.md)
- [User Guide](../guides/chrome-extension-user-guide.md)

---

**Last updated**: 2025-10-13
**Version**: 1.0
**Status**: Implementation in progress

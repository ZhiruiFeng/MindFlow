# Chrome Extension Coding Standards

## Core Principles

All Chrome extension development must adhere to these fundamental standards in addition to [General Standards](./general-standards.md).

---

## 1. Manifest V3 Compliance

### 1.1 No Remote Code Execution

**CRITICAL**: Chrome extensions MUST NOT execute remotely hosted code.

```javascript
// ❌ FORBIDDEN - Remote code execution
eval(remoteCode);
new Function(remoteCode)();
fetch('https://example.com/code.js').then(code => eval(code));

// ✅ ALLOWED - All logic in extension files
import { processText } from './lib/text-processor.js';
const result = processText(input);
```

**Rationale**: Manifest V3 security requirement. All code must be packaged with the extension for review.

### 1.2 Service Worker Pattern (Required)

**Background pages are deprecated. Use service workers.**

```javascript
// ❌ FORBIDDEN - Background pages (Manifest V2)
// background.html, persistent: true

// ✅ REQUIRED - Service workers (Manifest V3)
// service-worker.js
chrome.runtime.onInstalled.addListener(() => {
  console.log('Extension installed');
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  // Handle messages
  return true; // Keep channel open for async response
});
```

**Important**: Service workers are:
- Stateless and event-driven
- Terminated when idle
- Must handle lifecycle properly
- Cannot use DOM APIs directly

### 1.3 Content Security Policy

```json
// manifest.json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'"
  }
}
```

**Rules**:
- No `eval()` or inline scripts
- No external script loading
- All resources must be local

---

## 2. Permission Management

### 2.1 Minimal Permissions

**Request ONLY the narrowest permissions necessary.**

```json
// ✅ GOOD - Minimal, specific permissions
{
  "permissions": [
    "storage",           // For settings
    "activeTab"          // For text insertion
  ],
  "host_permissions": [
    "https://api.openai.com/*"  // Specific API only
  ]
}

// ❌ BAD - Overly broad permissions
{
  "permissions": [
    "storage",
    "tabs",              // Not needed
    "<all_urls>"         // Too broad
  ]
}
```

### 2.2 Permission Justification

**REQUIRED**: Document every permission for Chrome Web Store review.

```javascript
/**
 * PERMISSION JUSTIFICATIONS
 *
 * This documentation MUST be prepared for Chrome Web Store review:
 *
 * - storage: Store user settings and API keys securely using chrome.storage.sync
 *   with encryption at rest. No user data is collected or transmitted.
 *
 * - activeTab: Insert transcribed and optimized text into the currently active
 *   input field when user confirms. Only activates when user explicitly clicks
 *   the "Insert" button. No automatic data collection.
 *
 * - scripting: Execute content script to detect active input fields and insert
 *   text at cursor position. Required for core functionality.
 *
 * HOST PERMISSIONS:
 *
 * - https://api.openai.com/*: Send audio for transcription via Whisper API and
 *   text for optimization via GPT API. User provides their own API key. No data
 *   is sent to any other server.
 *
 * - https://api.elevenlabs.io/*: Alternative STT provider (optional). User
 *   provides their own API key.
 */
```

### 2.3 Optional Permissions

Use optional permissions for non-core features:

```javascript
// Request permission at runtime
chrome.permissions.request({
  permissions: ['clipboardWrite']
}, (granted) => {
  if (granted) {
    // Enable copy feature
  }
});
```

---

## 3. Security Standards

### 3.1 API Key Handling

**CRITICAL**: Never expose or log API keys.

```javascript
// ✅ CORRECT - Never log or expose API keys
async function validateAPIKey(key) {
  try {
    const response = await testAPIConnection(key);
    return response.ok;
  } catch (error) {
    console.error('API validation failed'); // No key in logs
    throw new Error('Invalid API key');
  }
}

// ✅ CORRECT - Sanitize error messages
function handleAPIError(error, context) {
  // Log for debugging (no sensitive data)
  console.error(`API error in ${context}:`, error.status);

  // User-friendly message (no key exposure)
  if (error.status === 401) {
    return 'Invalid API key. Please check your settings.';
  } else if (error.status === 429) {
    return 'Rate limit exceeded. Please try again later.';
  }
  return 'An error occurred. Please try again.';
}

// ❌ FORBIDDEN - Logging sensitive data
console.log('Using API key:', apiKey);              // NEVER
console.error('Failed with key:', key, error);      // NEVER
alert(`Error: ${error.message} for key ${apiKey}`); // NEVER
```

### 3.2 Secure Storage

**Use chrome.storage.sync for encrypted storage.**

```javascript
// ✅ CORRECT - Use chrome.storage.sync (encrypted at rest)
async function saveAPIKey(provider, key) {
  await chrome.storage.sync.set({
    [`apiKey_${provider}`]: key
  });
}

async function getAPIKey(provider) {
  const result = await chrome.storage.sync.get(`apiKey_${provider}`);
  return result[`apiKey_${provider}`];
}

// ❌ FORBIDDEN - localStorage (not encrypted)
localStorage.setItem('apiKey', key);  // INSECURE

// ❌ FORBIDDEN - Plain object (lost on restart)
const config = { apiKey: key };  // NOT PERSISTENT
```

### 3.3 Input Validation

**Validate and sanitize all inputs.**

```javascript
// ✅ CORRECT - Validate before use
function insertText(text) {
  if (typeof text !== 'string') {
    throw new TypeError('Text must be a string');
  }

  if (text.length === 0) {
    throw new Error('Text cannot be empty');
  }

  if (text.length > 10000) {
    throw new Error('Text too long (max 10000 characters)');
  }

  // Sanitize if needed
  const sanitized = text.replace(/[<>]/g, '');
  return sanitized;
}
```

### 3.4 No Credential Exposure

```javascript
// ❌ FORBIDDEN - Never include credentials in code
const API_KEY = 'sk-1234567890abcdef';  // NEVER DO THIS

// ✅ CORRECT - Always get from storage
const apiKey = await chrome.storage.sync.get('apiKey_openai');
```

---

## 4. Code Organization

### 4.1 Module Structure

**Use ES modules for clear separation of concerns.**

```javascript
// audio-recorder.js - Single responsibility
export class AudioRecorder {
  #stream = null;
  #mediaRecorder = null;
  #audioChunks = [];

  async startRecording() {
    this.#stream = await navigator.mediaDevices.getUserMedia({
      audio: { channelCount: 1, sampleRate: 44100 }
    });

    this.#mediaRecorder = new MediaRecorder(this.#stream);
    this.#setupHandlers();
    this.#mediaRecorder.start();
  }

  async stopRecording() {
    return new Promise((resolve) => {
      this.#mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.#audioChunks, {
          type: 'audio/webm'
        });
        this.#cleanup();
        resolve(audioBlob);
      };
      this.#mediaRecorder.stop();
    });
  }

  #setupHandlers() {
    this.#mediaRecorder.ondataavailable = (event) => {
      this.#audioChunks.push(event.data);
    };
  }

  #cleanup() {
    if (this.#stream) {
      this.#stream.getTracks().forEach(track => track.stop());
    }
    this.#audioChunks = [];
  }
}
```

### 4.2 Error Handling

**Comprehensive error handling with user-friendly messages.**

```javascript
// ✅ CORRECT - Specific error handling
async function transcribeAudio(audioBlob) {
  try {
    const apiKey = await getAPIKey('openai');
    if (!apiKey) {
      throw new Error('API key not configured');
    }

    const formData = new FormData();
    formData.append('file', audioBlob, 'recording.webm');
    formData.append('model', 'whisper-1');

    const response = await fetch(
      'https://api.openai.com/v1/audio/transcriptions',
      {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}` },
        body: formData
      }
    );

    if (!response.ok) {
      throw new APIError(response.status, await response.text());
    }

    const result = await response.json();
    return result.text;

  } catch (error) {
    if (error instanceof APIError) {
      if (error.status === 401) {
        throw new Error('Invalid API key. Please check your settings.');
      } else if (error.status === 429) {
        throw new Error('Rate limit exceeded. Please try again later.');
      }
    }

    throw new Error('Transcription failed. Please try again.');
  }
}

// Custom error class
class APIError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'APIError';
    this.status = status;
  }
}
```

### 4.3 Async/Await Pattern

**Use async/await consistently, avoid callback hell.**

```javascript
// ✅ CORRECT - Clean async/await
async function handleRecording() {
  try {
    updateUI({ state: 'recording' });

    const audioBlob = await recorder.stopRecording();
    updateUI({ state: 'transcribing' });

    const text = await sttService.transcribe(audioBlob);
    updateUI({ state: 'optimizing' });

    const optimized = await llmService.optimize(text);
    updateUI({ state: 'completed', text, optimized });

  } catch (error) {
    updateUI({ state: 'error', message: error.message });
  }
}

// ❌ BAD - Callback hell
recorder.stopRecording(function(audioBlob) {
  transcribe(audioBlob, function(text) {
    optimize(text, function(optimized) {
      updateUI(optimized);
    }, function(error) {
      handleError(error);
    });
  });
});
```

---

## 5. Chrome Web Store Compliance

### 5.1 Single Purpose Policy

**Extension must have ONE clear purpose.**

```javascript
/**
 * EXTENSION PURPOSE STATEMENT
 *
 * For Chrome Web Store listing - must be clear and focused:
 *
 * "MindFlow is a voice-to-text transcription tool with AI-powered text
 * optimization. It provides exactly ONE function:
 *
 * 1. Record voice input via browser microphone
 * 2. Transcribe audio to text using OpenAI Whisper API
 * 3. Optimize text by removing filler words and improving grammar
 * 4. Insert refined text into active input fields
 *
 * NO other features, tracking, ads, or data collection."
 */
```

### 5.2 Privacy Policy (REQUIRED)

**Must disclose data handling practices.**

```markdown
## Privacy Policy for MindFlow Chrome Extension

### Data Collection
- **None**: MindFlow does not collect, store, or transmit any user data.

### API Keys
- **Storage**: Stored locally using chrome.storage.sync (encrypted at rest).
- **Usage**: Used only to authenticate with user-chosen API providers.
- **Access**: Never transmitted to any server except the configured API.

### Audio Data
- **Recording**: Captured locally via browser MediaRecorder API.
- **Processing**: Sent directly to user's configured API (OpenAI/ElevenLabs).
- **Storage**: Temporarily held in memory, deleted after processing.
- **No Server**: MindFlow has no backend server. All data goes to user's API.

### Third-Party Services
- **OpenAI**: Audio transcription and text optimization (user must provide API key).
- **ElevenLabs**: Optional alternative for audio transcription (user must provide API key).

Users are responsible for their own API usage and should review the privacy
policies of their chosen API providers.

### Analytics
- **None**: No analytics, tracking, telemetry, or usage statistics.

### Contact
Report issues: [GitHub Issues](https://github.com/username/mindflow-extension)
```

### 5.3 User Data Disclosure

**Complete transparency required for Store listing.**

```json
// Chrome Web Store Developer Dashboard - Privacy Practices
{
  "dataUsage": {
    "dataCollection": false,
    "personallyIdentifiableInfo": false,
    "healthInfo": false,
    "financialInfo": false,
    "authenticationInfo": true,  // API keys
    "personalCommunications": false,
    "location": false,
    "webHistory": false,
    "userActivity": false,
    "websiteContent": false
  },
  "authenticationInfo": {
    "purpose": "API authentication only",
    "storage": "Local encrypted storage",
    "sharing": "Not shared with any third party"
  }
}
```

### 5.4 Affiliate Program Compliance

**NO undisclosed affiliate links (Chrome policy - June 2025).**

```javascript
// ✅ ALLOWED - Direct functionality, no affiliate injection
function insertText(text) {
  document.activeElement.value = text;
}

// ❌ FORBIDDEN - Injecting affiliate links
function insertText(text) {
  // Adding affiliate links when not providing value
  const withAffiliates = text.replace(
    /amazon\.com/g,
    'amazon.com?tag=myaffiliate'
  );
  document.activeElement.value = withAffiliates;
}
```

---

## 6. Performance Standards

### 6.1 Service Worker Lifecycle

**Handle service worker termination gracefully.**

```javascript
// ✅ CORRECT - State persisted to storage
let recordingState = null;

async function startRecording() {
  recordingState = 'recording';
  await chrome.storage.local.set({ recordingState });
  // ... start recording
}

// Restore state on wake
chrome.runtime.onStartup.addListener(async () => {
  const { recordingState } = await chrome.storage.local.get('recordingState');
  if (recordingState === 'recording') {
    // Resume or clean up
  }
});

// ❌ BAD - State lost when service worker terminates
let recordingState = null;  // Lost on termination
```

### 6.2 Minimize Resource Usage

```javascript
// ✅ CORRECT - Efficient audio recording
const mediaRecorder = new MediaRecorder(stream, {
  mimeType: 'audio/webm;codecs=opus',
  audioBitsPerSecond: 128000  // Reasonable quality
});

// ❌ BAD - Excessive resource usage
const mediaRecorder = new MediaRecorder(stream, {
  mimeType: 'audio/wav',  // Uncompressed, huge files
  audioBitsPerSecond: 320000  // Overkill for voice
});
```

### 6.3 Lazy Loading

```javascript
// ✅ CORRECT - Load heavy modules on demand
async function optimize(text) {
  const { LLMService } = await import('./lib/llm-service.js');
  const llm = new LLMService();
  return await llm.optimize(text);
}
```

---

## 7. Testing Requirements

### 7.1 Unit Tests

```javascript
// test/audio-recorder.test.js
import { AudioRecorder } from '../src/lib/audio-recorder.js';

describe('AudioRecorder', () => {
  let recorder;

  beforeEach(() => {
    recorder = new AudioRecorder();
  });

  afterEach(() => {
    recorder.cleanup();
  });

  it('should start recording', async () => {
    await recorder.startRecording();
    expect(recorder.isRecording).toBe(true);
  });

  it('should return audio blob on stop', async () => {
    await recorder.startRecording();
    const blob = await recorder.stopRecording();
    expect(blob).toBeInstanceOf(Blob);
    expect(blob.type).toBe('audio/webm');
  });
});
```

### 7.2 Integration Tests

```javascript
// test/integration/voice-to-text.test.js
describe('Voice-to-Text Flow', () => {
  it('should complete full workflow', async () => {
    // 1. Record
    await recorder.startRecording();
    await delay(2000);
    const audioBlob = await recorder.stopRecording();

    // 2. Transcribe
    const text = await sttService.transcribe(audioBlob);
    expect(text).toBeTruthy();

    // 3. Optimize
    const optimized = await llmService.optimize(text);
    expect(optimized).toBeTruthy();
    expect(optimized).not.toBe(text);
  });
});
```

### 7.3 Manual Testing Checklist

Before each release:

- [ ] Test on multiple websites (Gmail, Google Docs, Twitter, Reddit)
- [ ] Verify text insertion in various input types (textarea, input, contenteditable)
- [ ] Test with invalid API keys (proper error messages)
- [ ] Test with rate limiting (graceful degradation)
- [ ] Verify settings persistence across browser restarts
- [ ] Test keyboard shortcuts
- [ ] Check extension popup UI on different screen sizes
- [ ] Verify no console errors in production mode
- [ ] Test service worker lifecycle (termination/restart)
- [ ] Verify audio cleanup after recording

---

## 8. Documentation Requirements

### 8.1 Code Documentation

```javascript
/**
 * Speech-to-Text service for transcribing audio to text.
 *
 * Supports multiple providers:
 * - OpenAI Whisper API
 * - ElevenLabs Speech-to-Text
 *
 * @example
 * const stt = new STTService();
 * await stt.setAPIKey('openai', 'sk-...');
 * const text = await stt.transcribe(audioBlob);
 *
 * @module stt-service
 */
export class STTService {
  /**
   * Transcribe audio blob to text.
   *
   * @param {Blob} audioBlob - Audio data in webm format
   * @param {Object} options - Transcription options
   * @param {string} options.language - Language code (optional, auto-detect)
   * @returns {Promise<string>} Transcribed text
   * @throws {Error} If API key not configured or request fails
   */
  async transcribe(audioBlob, options = {}) {
    // Implementation
  }
}
```

### 8.2 User Documentation

Required files:
- `README.md` - Overview and quick start
- `PRIVACY.md` - Privacy policy (required for Store)
- `docs/user-guide.md` - Complete usage instructions
- `docs/setup.md` - Installation and configuration

---

## 9. Chrome Web Store Submission Checklist

Before submitting to Chrome Web Store:

### Code Quality
- [ ] All code follows these standards
- [ ] No `eval()` or remote code execution
- [ ] No hardcoded credentials or API keys
- [ ] All console.logs removed from production build
- [ ] Error messages are user-friendly (no technical details)
- [ ] Service worker lifecycle handled properly

### Security & Privacy
- [ ] API keys stored securely in chrome.storage.sync
- [ ] No sensitive data in logs or error messages
- [ ] Privacy policy created and linked in manifest
- [ ] User data disclosure accurate and complete
- [ ] No data sent to any server except configured APIs

### Permissions
- [ ] Minimal permissions requested
- [ ] Each permission justified in documentation
- [ ] Optional permissions used where appropriate
- [ ] Host permissions limited to specific APIs

### Testing
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed on multiple sites
- [ ] Tested with invalid/expired API keys
- [ ] Keyboard shortcuts work correctly

### Documentation
- [ ] README.md complete with screenshots
- [ ] Privacy policy included (PRIVACY.md)
- [ ] User guide written (docs/user-guide.md)
- [ ] Permission justifications documented
- [ ] Setup instructions clear and complete

### Store Listing
- [ ] Extension name clear and descriptive
- [ ] Short description under 132 characters
- [ ] Detailed description explains functionality
- [ ] Screenshots prepared (1280x800 or 640x400)
- [ ] Store icon created (128x128)
- [ ] Promo tiles created (optional but recommended)
- [ ] Single purpose clearly stated
- [ ] No prohibited content or functionality

### Assets
- [ ] Icons: 16x16, 48x48, 128x128 (all required)
- [ ] Screenshots: At least 1, max 5
- [ ] Store icon: 128x128
- [ ] Small promo tile: 440x280 (optional)
- [ ] Large promo tile: 1400x560 (optional)

### Build
- [ ] Production build created
- [ ] Code minified (optional but recommended)
- [ ] Source maps removed from production
- [ ] Extension size reasonable (< 5MB recommended)
- [ ] manifest.json version incremented
- [ ] Zip file created (not including development files)

---

## 10. Version Control

### 10.1 .gitignore

```gitignore
# Chrome Extension - .gitignore

# Build output
dist/
build/
*.zip

# Environment variables
.env
.env.local

# API keys (NEVER commit)
**/config.js
**/secrets.js

# Node modules
node_modules/

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Testing
coverage/
.nyc_output/

# Logs
*.log
```

### 10.2 Commit Messages

```bash
# ✅ GOOD - Clear, descriptive commits
git commit -m "Add API key validation for OpenAI"
git commit -m "Fix text insertion in contenteditable fields"
git commit -m "Update privacy policy for Store compliance"

# ❌ BAD - Vague commits
git commit -m "Fix bug"
git commit -m "Update code"
git commit -m "WIP"
```

---

## 11. References

- [Chrome Extension Documentation](https://developer.chrome.com/docs/extensions/)
- [Manifest V3 Migration Guide](https://developer.chrome.com/docs/extensions/mv3/intro/)
- [Chrome Web Store Developer Policies](https://developer.chrome.com/docs/webstore/program-policies/)
- [General Coding Standards](./general-standards.md)
- [Documentation Standards](./documentation-standards.md)

---

## Enforcement

Violations of these standards will result in:
1. Code review rejection
2. Extension Store rejection
3. Required refactoring before merge

All code must pass review checklist before being merged to main branch.

# Privacy Policy for MindFlow

**Last Updated**: October 14, 2025

## Overview

MindFlow is committed to protecting your privacy. This policy explains how we handle data in both our Chrome Extension and macOS application.

## Data Collection

**MindFlow does NOT collect, store, or transmit any user data to our servers.**

- **No analytics**: We do not track usage, behavior, or any statistics
- **No telemetry**: We do not collect diagnostic or performance data
- **No user accounts**: We do not require registration or store user information
- **No backend servers**: MindFlow has no proprietary backend infrastructure

## API Keys and Authentication

### Storage
- **Chrome Extension**: API keys are stored locally using `chrome.storage.sync`, which provides encryption at rest through Chrome's built-in security mechanisms
- **macOS Application**: API keys are stored securely in the system Keychain using `kSecAttrAccessibleWhenUnlocked` protection

### Usage
- API keys are used **only** to authenticate with your chosen third-party API providers (OpenAI, ElevenLabs, ZephyrOS)
- Keys are **never** transmitted to any server except the configured API provider
- Keys remain on your device and are never shared with MindFlow or any third parties

### Access Control
- Only the MindFlow application/extension can access the stored credentials
- Keys are protected by your system's security mechanisms (Chrome sync encryption or macOS Keychain)

## Audio and Text Data

### Recording
- Audio is captured locally using your device's microphone via browser MediaRecorder API (Extension) or AVFoundation (macOS)
- Recordings are held temporarily in memory during processing
- **No recordings are saved to disk** unless explicitly configured by you

### Processing
- Audio data is sent directly to your configured API provider (OpenAI Whisper or ElevenLabs) for transcription
- Text is sent to your configured LLM provider (OpenAI GPT) for optimization
- **Data flow**: Your device → API provider (direct connection, no intermediary)
- **MindFlow never sees your data**: All processing happens between your device and the API provider

### Storage
- Audio and text are **not stored** by MindFlow
- Temporary data is cleared from memory immediately after processing
- Local history (if enabled) stores text locally on your device only

## Third-Party Services

MindFlow integrates with the following third-party services. You must provide your own API keys for these services:

### OpenAI (api.openai.com)
- **Purpose**: Audio transcription (Whisper API) and text optimization (GPT API)
- **Data sent**: Audio files and text content
- **Privacy policy**: https://openai.com/privacy

### ElevenLabs (api.elevenlabs.io)
- **Purpose**: Alternative audio transcription service (optional)
- **Data sent**: Audio files
- **Privacy policy**: https://elevenlabs.io/privacy

### ZephyrOS (zmemory.zephyros.app, *.supabase.co)
- **Purpose**: Optional cloud sync and storage (if enabled by user)
- **Data sent**: Transcribed text and metadata
- **Privacy policy**: Contact ZephyrOS provider for details

**You are responsible for reviewing and accepting the privacy policies of any third-party services you choose to use with MindFlow.**

## Local Data Storage

### What We Store Locally
- **Settings and preferences**: UI configuration, selected API providers
- **API keys**: Encrypted in chrome.storage.sync (Extension) or Keychain (macOS)
- **Local history** (optional): Transcribed text stored in Chrome local storage or CoreData (macOS)

### What We DON'T Store
- Audio recordings (deleted after processing)
- Personal information
- Usage statistics
- Diagnostic data

## Permissions Explained

### Chrome Extension Permissions

- **`storage`**: Store user settings and API keys securely in encrypted chrome.storage.sync
- **`activeTab`**: Insert transcribed text into the currently active input field when you click "Insert"
- **`scripting`**: Execute content scripts to detect active input fields and insert text at cursor position

### macOS Application Permissions

- **Microphone**: Required to record voice input for transcription
- **Accessibility** (optional): If enabled, allows insertion of text into any application

All permissions are used **only** for core functionality. No permissions are used for data collection or tracking.

## Data Retention

- **No server-side retention**: MindFlow has no servers, so no data is retained server-side
- **Local history**: If enabled, stored indefinitely on your device until you delete it
- **API keys**: Stored until you remove them from settings
- **Temporary data**: Audio and text are deleted from memory after processing (typically within seconds)

## Data Sharing

**MindFlow does NOT share any data with third parties**, except:

- Direct transmission of audio/text to API providers you configure (OpenAI, ElevenLabs, ZephyrOS)
- This is necessary for core functionality (transcription and optimization)
- You control which providers are used by providing API keys

**We have no access to:**
- Your API keys
- Your audio recordings
- Your transcribed text
- Any usage data

## Security

### Encryption
- API keys encrypted at rest (chrome.storage.sync, Keychain)
- All API communications use HTTPS/TLS
- No plain-text storage of sensitive data

### Access Control
- Chrome Extension: Follows Manifest V3 security requirements
- macOS App: Follows Apple's security best practices with sandboxing
- No remote code execution
- No eval() or dynamic code loading

### Best Practices
- We follow OWASP security guidelines
- Regular security audits of dependencies
- Minimal permissions principle
- Input validation and sanitization

## Your Rights

### Access
- All your data is stored locally on your device
- You can view/export local history at any time through the application

### Deletion
- Delete local history: Use the "Clear History" function in settings
- Delete API keys: Remove them from settings
- Complete removal: Uninstall the extension/application

### Portability
- Local history can be exported to JSON format
- No vendor lock-in, as all data is stored locally

## Children's Privacy

MindFlow does not knowingly collect data from anyone, including children under 13. Since we don't collect any personal information, COPPA requirements are satisfied.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be noted by updating the "Last Updated" date at the top of this document. Continued use of MindFlow after changes constitutes acceptance of the updated policy.

## Compliance

This privacy policy is designed to comply with:
- General Data Protection Regulation (GDPR)
- California Consumer Privacy Act (CCPA)
- Chrome Web Store Developer Program Policies
- Apple App Store Guidelines

## Contact

For questions, concerns, or to report privacy issues:

- **GitHub Issues**: https://github.com/[your-username]/MindFlow/issues
- **Email**: [your-email@example.com]

## Transparency

This is a privacy-first application:
- ✅ No data collection
- ✅ No analytics or tracking
- ✅ No advertisements
- ✅ No affiliate links
- ✅ Open source (code available for review)
- ✅ Local-first architecture
- ✅ Your data stays on your device

## Jurisdiction

This privacy policy is governed by the laws of [Your Jurisdiction].

---

**Summary**: MindFlow is designed with privacy as a core principle. We don't collect your data because we don't have any way to receive it. Your audio, text, and API keys stay on your device or go directly to the API providers you configure. We never see, store, or transmit your personal information.

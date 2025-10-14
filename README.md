# 🎤 MindFlow

> An intelligent macOS voice-to-text assistant that makes text input more efficient

MindFlow is a system-level macOS application that quickly converts speech to text in any text input scenario. It uses AI to intelligently optimize content by removing filler words and verbal tics, making your text expression clearer and smoother.

---

## ✨ Core Features

- 🎯 **Global Hotkey Activation** - Invoke in any app with a single keystroke, seamlessly integrated into your workflow
- 🎤 **High-Quality Speech Recognition** - Powered by OpenAI Whisper and ElevenLabs STT technology
- ✨ **Intelligent Text Optimization** - Automatically removes filler words like "um", "uh", "like" and optimizes sentence structure
- 💾 **Local-First Storage** - All interactions stored locally with Core Data, works offline
- 🔄 **Smart Sync** - Configurable auto-sync threshold (default 30s) with manual sync option
- 🌐 **ZephyrOS Integration** - Optional cloud sync to ZephyrOS for cross-platform access
- 🧩 **Chrome Extension** - Browser companion for web-based voice input
- 🔒 **Privacy-First Design** - API keys encrypted locally in Keychain, no account required
- ⚡ **Auto-Paste** - Direct insertion into active input field after processing
- 🎨 **Native macOS Experience** - Built with SwiftUI, perfectly integrated with the system

---

## 🚀 Quick Start

### System Requirements

- macOS 13.0 (Ventura) or later
- Microphone access permission
- Accessibility permission (for global hotkeys and auto-paste)

### Installation

**Option 1: Download DMG**
1. Download the latest `.dmg` file from [Releases](https://github.com/yourusername/MindFlow/releases)
2. Open the DMG file and drag MindFlow to Applications folder
3. Right-click → Open (to bypass Gatekeeper) on first launch

**Option 2: Homebrew**
```bash
brew install --cask mindflow
```

**Detailed Steps**: See [Quick Start Guide](./docs/guides/quick-start.md)

### Configuration

1. **Launch MindFlow**
   Click the 🎤 icon in the menu bar

2. **Configure API Keys**
   - Click menu bar icon → Settings
   - Enter your OpenAI API Key
   - (Optional) Enter ElevenLabs API Key

3. **Set Permissions**
   - System will request microphone and accessibility permissions on first use
   - Go to System Settings → Privacy & Security to grant permissions

4. **Customize Hotkey** (Optional)
   - Default hotkey: `⌘ Shift V`
   - Can be customized in Settings

5. **Configure Sync** (Optional)
   - Enable/disable auto-sync to ZephyrOS
   - Adjust auto-sync threshold (default: 30 seconds)
   - Shorter recordings stay local-only unless manually synced

---

## 📖 How to Use

### Basic Workflow

1. **Start Recording**
   Press the global hotkey (default `⌘ Shift V`), or click menu bar icon → Start Recording

2. **Speak**
   Speak into your microphone. The interface shows real-time audio waveform and recording duration

3. **Stop and Process**
   Click "Stop and Process" button. The app will:
   - Convert speech to text
   - Use AI to optimize text content
   - Display comparison between original and optimized text

4. **Use the Result**
   - **Auto-paste**: Click "Paste" button to insert text into active input field
   - **Manual copy**: Click "Copy" button to save text to clipboard
   - **Re-optimize**: Adjust optimization level and reprocess if needed
   - **Manual sync**: For short recordings, click "Sync" to upload to ZephyrOS

### Local Storage & Sync

- **All recordings are saved locally first** using Core Data
- **Auto-sync threshold**: Recordings longer than 30 seconds (configurable) automatically sync to ZephyrOS
- **Short recordings**: Stay local-only and show a "Sync" button for manual upload
- **Sync status**: Visual badges show whether each recording is synced, pending, or failed
- **Offline mode**: Works completely offline; sync when reconnected

### Optimization Levels

- **Light**: Remove obvious filler words only, preserve conversational tone
- **Medium** (Recommended): Remove fillers + optimize sentence structure
- **Heavy**: Deep rewrite, convert to formal written expression

---

## 🛠 Development

### 📚 Documentation

**Complete Documentation Index**: [Documentation](./docs/README.md)

**Quick Links**:
- [Design Plan](./docs/architecture/design-plan.md) - System design and tech stack
- [Project Structure](./docs/reference/project-structure.md) - Code organization
- [Setup Guide](./docs/guides/setup-guide.md) - Development environment setup
- [API Integration](./docs/reference/api-integration.md) - API integration details
- [Local Storage Deep Dive](./docs/architecture/local-storage-deep-dive.md) - Core Data architecture
- [Coding Standards](./spec/coding-regulations/) - Coding regulations

### Tech Stack

**macOS Application:**
- **Framework**: SwiftUI + Swift
- **Audio**: AVFoundation
- **System Integration**: Carbon (hotkeys), CGEvent (auto-paste)
- **Local Storage**: Core Data (SQLite)
- **Security**: Keychain Services
- **Backend**: Supabase (Authentication & PostgreSQL)
- **API**: OpenAI Whisper, OpenAI GPT, ElevenLabs

**Chrome Extension:**
- **Framework**: Vanilla JavaScript (ES6+)
- **Storage**: Chrome Storage API
- **Messaging**: Chrome Extension API
- **UI**: Custom CSS with dark mode

### Contributing

```bash
# Clone the repository
git clone https://github.com/yourusername/MindFlow.git

# Open macOS project in Xcode
cd MindFlow
open MindFlow.xcodeproj

# For Chrome Extension development
cd MindFlow-Extension
# See MindFlow-Extension/README.md for setup instructions
```

See [Setup Guide](./docs/guides/setup-guide.md) for detailed steps.

---

## 🗺 Roadmap

### Phase 1: Core Features ✅ COMPLETED
- [x] SwiftUI UI framework
- [x] Audio recording with AVFoundation
- [x] OpenAI & ElevenLabs API integration
- [x] Global hotkey support
- [x] Auto-paste functionality
- [x] Real-time waveform display
- [x] Multiple optimization modes

### Phase 2: Storage & Sync ✅ COMPLETED
- [x] Local storage with Core Data
- [x] Interaction history view
- [x] ZephyrOS cloud integration
- [x] Supabase authentication
- [x] Configurable auto-sync threshold
- [x] Manual sync for short recordings
- [x] Sync status visualization

### Phase 3: Multi-Platform ✅ COMPLETED
- [x] Chrome extension
- [x] Cross-platform sync between macOS and browser
- [x] Unified API integration

### Phase 4: Polish & Release (In Progress)
- [x] Error handling improvements
- [x] Comprehensive documentation
- [ ] App signing and notarization
- [ ] DMG installer creation
- [ ] Website development
- [ ] App Store submission

### Future (V2.0+)
- [ ] Local AI model support (Core ML)
- [ ] Multi-language UI
- [ ] iOS companion app
- [ ] Safari extension
- [ ] Spotlight integration
- [ ] Voice commands

---

## 💰 Pricing

**Application**: Completely free and open-source

**API Usage Costs** (you pay directly to providers):
- **OpenAI Whisper**: ~$0.006/minute
- **OpenAI GPT-4o-mini**: ~$0.0001/request
- **Estimated cost**: < $0.01 per use on average

**ZephyrOS Backend** (Optional):
- Free tier available
- Optional cloud sync for cross-device access

💡 **Tip**: Set monthly budget limits on your OpenAI account

---

## 🔒 Privacy & Security

- ✅ All API keys encrypted and stored in macOS Keychain
- ✅ No user data collection
- ✅ Audio files sent directly to your configured APIs (not uploaded to our servers)
- ✅ Local-first: all recordings stored on your device
- ✅ Optional cloud sync (disabled by default)
- ✅ No account required for local use
- ✅ Works completely offline (except for API calls and optional sync)

---

## ❓ FAQ

**Q: Why does MindFlow need Accessibility permission?**
A: For global hotkey monitoring and auto-paste functionality. You can decline this permission, but you'll need to manually copy text.

**Q: Are my API keys secure?**
A: Keys are stored in macOS Keychain, which is Apple's recommended and most secure credential storage method.

**Q: What languages are supported?**
A: OpenAI Whisper supports 99+ languages including English, Chinese, Japanese, Spanish, etc. Text optimization works best for English and Chinese.

**Q: Can I use it offline?**
A: The app stores all recordings locally and works offline. However, transcription and optimization require API calls. Future versions will support local AI models.

**Q: What's the difference from macOS dictation?**
A: MindFlow's key advantage is AI-powered text optimization that automatically cleans up filler words and improves clarity, making your text more professional.

**Q: What is the auto-sync threshold?**
A: By default, recordings longer than 30 seconds automatically sync to ZephyrOS (if authenticated). Shorter recordings stay local-only and can be manually synced later. This threshold is configurable in Settings.

---

## 📄 License

MIT License - See [LICENSE](./LICENSE) for details

---

## 🙏 Acknowledgments

- [OpenAI](https://openai.com/) - Whisper and GPT APIs
- [ElevenLabs](https://elevenlabs.io/) - Speech-to-text technology
- [Supabase](https://supabase.com/) - Backend infrastructure and authentication
- Apple - Excellent development tools and system APIs

---

## 📧 Contact

- **Bug Reports**: [GitHub Issues](https://github.com/yourusername/MindFlow/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/yourusername/MindFlow/discussions)
- **Documentation**: [docs/](./docs/)

---

## 🌟 Project Status

**Current Version**: 1.0 (MVP Complete)

**Key Stats**:
- ~2,260 lines of Swift code (macOS app)
- Core Data local storage implementation
- Chrome extension with full feature parity
- 30+ documentation files
- ZephyrOS backend integration

---

<div align="center">

**If this project helps you, please give it a ⭐️**

Made with ❤️ for productivity enthusiasts

[Documentation](./docs/README.md) • [Quick Start](./docs/guides/quick-start.md) • [Contributing](./docs/guides/setup-guide.md)

</div>

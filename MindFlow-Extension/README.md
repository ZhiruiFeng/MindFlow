# MindFlow Chrome Extension

> Intelligent voice-to-text transcription with AI-powered text optimization for your browser

Transform your voice into clean, polished text with AI. Record in any browser tab, get instant transcription, and insert optimized text into any input field.

---

## ✨ Features

- 🎤 **Voice Recording** - High-quality audio capture in your browser
- 🔤 **Speech-to-Text** - Powered by OpenAI Whisper or ElevenLabs
- ✨ **AI Text Optimization** - Remove filler words, fix grammar, improve clarity
- ⚡ **Instant Insertion** - Insert directly into active input fields
- 🔒 **Privacy First** - Your API keys stay local, no data collection
- 🌐 **Works Everywhere** - Gmail, Google Docs, Twitter, and more

---

## 🚀 Quick Start

### Installation

**Option 1: Chrome Web Store** (Coming Soon)
```
Visit Chrome Web Store and click "Add to Chrome"
```

**Option 2: Developer Mode** (For Testing)
```bash
1. Download or clone this repository
2. Open Chrome and go to chrome://extensions/
3. Enable "Developer mode" (top right)
4. Click "Load unpacked"
5. Select the MindFlow-Extension directory
```

### Setup

1. **Click the MindFlow extension icon** in your browser toolbar
2. **Go to Settings** (gear icon)
3. **Add your OpenAI API Key**
   - Get your key from [OpenAI Platform](https://platform.openai.com/api-keys)
   - Paste it into the API Key field
   - Click "Test" to validate
4. **Start using!** Click the extension icon or press `Ctrl+Shift+V` (Windows/Linux) or `Cmd+Shift+V` (Mac)

---

## 📖 Usage

### Basic Workflow

1. **Start Recording**
   - Click extension icon → "Start Recording"
   - Or use keyboard shortcut: `Ctrl/Cmd+Shift+V`

2. **Speak Your Message**
   - The popup shows recording timer and waveform
   - Click "Pause" if you need a break

3. **Stop and Process**
   - Click "Stop & Process"
   - Wait for transcription and optimization (usually 5-10 seconds)

4. **Review and Insert**
   - See original transcription vs. optimized text
   - Click "Insert" to add to active input field
   - Or "Copy" to clipboard for manual paste

### Optimization Levels

- **Light**: Remove obvious filler words only
- **Medium**: Remove fillers + improve grammar (recommended)
- **Heavy**: Full rewrite to formal, polished text

---

## 🔧 Configuration

### Settings

Access settings via the gear icon in the popup:

- **API Configuration**
  - OpenAI API Key (required)
  - ElevenLabs API Key (optional alternative)
  - Provider selection

- **Optimization Preferences**
  - Level: Light / Medium / Heavy
  - Style: Casual / Formal
  - Model: gpt-4o-mini (default)

- **Behavior**
  - Auto-insert after optimization
  - Show notifications
  - Keep local history (optional)

### Keyboard Shortcuts

- `Ctrl/Cmd+Shift+V` - Start recording
- Customize in `chrome://extensions/shortcuts`

---

## 💰 Cost

**Extension**: Free and open source

**API Usage** (you provide your own keys):
- OpenAI Whisper: ~$0.006/minute
- OpenAI GPT-4o-mini: ~$0.0001/request
- **Average cost per use: ~$0.003** (less than a penny!)

💡 Tip: Set a monthly spending limit in your OpenAI account dashboard

---

## 🔒 Privacy & Security

- ✅ **No data collection** - We don't collect any usage data
- ✅ **Local storage** - API keys stored securely in Chrome's encrypted storage
- ✅ **No tracking** - No analytics, telemetry, or third-party scripts
- ✅ **Direct API calls** - Audio goes straight to your configured API
- ✅ **No backend** - We don't have servers; everything is client-side

Read our full [Privacy Policy](../docs/privacy-policy.md) (coming soon)

---

## 🛠️ Development

### Prerequisites

- Chrome/Edge browser (version 88+)
- Node.js (optional, for testing)
- OpenAI API key for testing

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/MindFlow.git
cd MindFlow/MindFlow-Extension

# Install development dependencies (optional)
npm install

# Load extension in Chrome
# 1. Go to chrome://extensions/
# 2. Enable "Developer mode"
# 3. Click "Load unpacked"
# 4. Select this directory
```

### Project Structure

```
MindFlow-Extension/
├── manifest.json           # Extension manifest
├── src/
│   ├── background/        # Service worker
│   ├── popup/            # Main UI
│   ├── settings/         # Settings page
│   ├── content/          # Content scripts
│   ├── lib/              # Core services
│   └── common/           # Utilities
├── assets/               # Icons and images
└── tests/                # Unit and integration tests
```

### Testing

```bash
# Run unit tests (if configured)
npm test

# Manual testing checklist
# - Test recording on different websites
# - Test text insertion in various input types
# - Test error scenarios (invalid API key, network issues)
# - Test settings persistence
```

---

## 📋 Roadmap

### Phase 1: MVP (Current)
- [x] Project structure and manifest
- [ ] Audio recording functionality
- [ ] STT integration (OpenAI Whisper)
- [ ] LLM optimization (GPT-4o-mini)
- [ ] Text insertion
- [ ] Settings page

### Phase 2: Enhancement
- [ ] ElevenLabs STT support
- [ ] History feature (local storage)
- [ ] Improved UI/UX
- [ ] Keyboard shortcuts customization
- [ ] Chrome Web Store publication

### Phase 3: Advanced
- [ ] Offline mode (local Whisper model)
- [ ] Multi-language support
- [ ] Voice commands
- [ ] Export/import settings

---

## ❓ FAQ

**Q: Why do I need to provide my own API key?**
A: This keeps the extension free and puts you in control of your data and costs. Your API keys never leave your browser except to call the APIs directly.

**Q: Which browsers are supported?**
A: Chrome, Edge, Brave, and other Chromium-based browsers. Firefox support coming soon.

**Q: Does it work offline?**
A: Not currently. We're exploring local AI models for offline support in future versions.

**Q: Where is my data stored?**
A: API keys are stored in Chrome's encrypted sync storage. Recordings are processed in memory and immediately discarded. No data is sent to our servers (we don't have any!).

**Q: Can I use it on mobile?**
A: Not yet. Chrome extensions on mobile have limited support. We're exploring options.

---

## 🤝 Contributing

Contributions are welcome! Please see [Contributing Guidelines](../docs/guides/contributing.md) (coming soon) for guidelines.

### Areas for Contribution
- 🐛 Bug fixes and testing
- 🎨 UI/UX improvements
- 📖 Documentation
- 🌍 Internationalization
- ✨ Feature development

---

## 📄 License

MIT License - see [LICENSE](../LICENSE) for details

---

## 🙏 Acknowledgments

- [OpenAI](https://openai.com/) - Whisper and GPT APIs
- [ElevenLabs](https://elevenlabs.io/) - Alternative STT
- Chrome Extension community for excellent documentation

---

## 📧 Support

- **Quick Start**: [3-Minute Setup Guide](./docs/guides/quick-start.md)
- **Troubleshooting**: [Common Errors and Solutions](./docs/troubleshooting/troubleshooting.md)
- **Documentation**: [Extension Docs](./docs/README.md) | [Project Docs](../docs/README.md)
- **Issues**: [GitHub Issues](https://github.com/yourusername/MindFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/MindFlow/discussions)

---

**MindFlow Chrome Extension** - Turn your voice into elegant text ✨

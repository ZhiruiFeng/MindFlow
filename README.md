# 🎤 MindFlow

> 一款智能的 macOS 语音转文字助手，让文字输入更高效

MindFlow 是一个系统级的 macOS 应用程序，能够在任何文本输入场景下快速将语音转换为文字，并通过 AI 智能优化内容，去除填充词和语气词，让你的文字表达更加清晰流畅。

---

## ✨ 核心特性

- 🎯 **全局快捷键触发** - 在任何应用中一键唤起，无缝融入工作流
- 🎤 **高质量语音识别** - 基于 OpenAI Whisper 和 ElevenLabs 的 STT 技术
- ✨ **智能文本优化** - 自动去除"嗯""啊""那个"等填充词，优化语句结构
- 🔒 **隐私优先设计** - API 密钥本地加密存储，无需账户登录
- ⚡ **自动粘贴** - 处理完成后直接粘贴到活动输入框
- 🎨 **原生 macOS 体验** - 使用 SwiftUI 打造，完美融入系统

---

## 🚀 快速开始

### 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 麦克风访问权限
- 辅助功能权限（用于全局热键和自动粘贴）

### 安装

**方式 1: 下载安装包**
1. 从 [Releases](https://github.com/yourusername/MindFlow/releases) 下载最新的 `.dmg` 文件
2. 打开 DMG 文件，将 MindFlow 拖入应用程序文件夹
3. 首次打开时，右键点击 -> 打开（以绕过 Gatekeeper）

**方式 2: 通过 Homebrew**
```bash
brew install --cask mindflow
```

### 配置

1. **启动 MindFlow**  
   点击菜单栏中的 🎤 图标

2. **配置 API 密钥**  
   - 点击菜单栏图标 -> 设置
   - 输入你的 OpenAI API Key
   - （可选）输入 ElevenLabs API Key

3. **设置权限**  
   - 首次使用时，系统会请求麦克风和辅助功能权限
   - 前往系统设置 -> 隐私与安全性授予相应权限

4. **自定义快捷键**（可选）  
   - 默认快捷键：`⌘ Shift V`
   - 可在设置中自定义

---

## 📖 使用方法

### 基本流程

1. **触发录音**  
   按下全局快捷键（默认 `⌘ Shift V`），或点击菜单栏图标 -> 开始录音

2. **录制语音**  
   对着麦克风说话，界面会显示实时音频波形和录制时长

3. **停止并处理**  
   点击"停止并处理"按钮，应用将：
   - 将语音转换为文字
   - 使用 AI 优化文本内容
   - 显示原始文本和优化后的文本对比

4. **确认并使用**  
   - **自动粘贴**：点击"粘贴"按钮，文本将自动插入到当前活动的输入框
   - **手动复制**：点击"复制"按钮，文本将保存到剪贴板
   - **重新优化**：如果不满意，可以调整优化级别后重新处理

### 优化级别说明

- **轻度**：仅去除明显的填充词，保留口语化表达
- **中度**（推荐）：去除填充词 + 优化语句结构
- **重度**：深度改写，转换为书面化表达

---

## 🛠 开发

本项目目前处于**规划阶段**。

### 查看设计文档

详细的设计计划请参考：[DESIGN_PLAN.md](./DESIGN_PLAN.md)

包含内容：
- 完整的技术架构设计
- UI/UX 设计方案
- API 集成方案
- 开发路线图（4-6周）
- 技术实现细节

### 技术栈（计划）

- **框架**: SwiftUI + Swift
- **音频**: AVFoundation
- **系统集成**: Carbon (热键), CGEvent (自动粘贴)
- **安全存储**: Keychain Services
- **API**: OpenAI Whisper, OpenAI GPT, ElevenLabs

### 参与开发

欢迎贡献！项目将在 Phase 1 完成后开放贡献。

```bash
# 克隆仓库
git clone https://github.com/yourusername/MindFlow.git

# 用 Xcode 打开项目
cd MindFlow
open MindFlow.xcodeproj

# 或者如果使用 Tauri
npm install
npm run tauri dev
```

---

## 🗺 Roadmap

### Phase 1: MVP (进行中)
- [ ] 基础 UI 框架
- [ ] 音频录制
- [ ] OpenAI API 集成
- [ ] 全局热键
- [ ] 自动粘贴

### Phase 2: 优化
- [ ] 历史记录
- [ ] 多种优化模式
- [ ] 实时波形显示
- [ ] 错误处理优化

### Phase 3: 发布
- [ ] 应用签名和公证
- [ ] 安装包制作
- [ ] 文档完善
- [ ] 官网搭建

### Future (V2.0+)
- 本地 AI 模型支持
- 多语言界面
- 云端同步
- iOS 版本
- 浏览器扩展

---

## 💰 费用说明

**应用本身**：完全免费，开源

**API 使用费用**（需自行承担）：
- **OpenAI Whisper**: ~$0.006/分钟
- **OpenAI GPT-4o-mini**: ~$0.0001/次请求
- **估算**：平均每次使用 < $0.01

💡 **建议**：设置 OpenAI 账户月度预算限制

---

## 🔒 隐私与安全

- ✅ 所有 API 密钥使用 macOS Keychain 加密存储
- ✅ 不收集任何用户数据
- ✅ 不上传任何录音文件（直接发送到你配置的 API）
- ✅ 无需注册账户
- ✅ 完全离线工作（除 API 调用外）

---

## ❓ 常见问题

**Q: 为什么需要辅助功能权限？**  
A: 用于实现全局热键监听和自动粘贴功能。你可以选择不授予此权限，但需要手动复制文本。

**Q: 我的 API 密钥安全吗？**  
A: 密钥使用 macOS Keychain 存储，这是 Apple 推荐的最安全的凭证存储方式。

**Q: 支持哪些语言？**  
A: OpenAI Whisper 支持 99+ 种语言，包括中文、英文、日文等。文本优化对中英文效果最好。

**Q: 可以离线使用吗？**  
A: 目前需要网络连接来调用 API。未来版本计划支持本地 AI 模型。

**Q: 和系统自带的听写功能有什么区别？**  
A: MindFlow 的优势在于 AI 智能优化，能自动清理口语化表达，使文本更加专业易读。

---

## 📄 License

MIT License - 详见 [LICENSE](./LICENSE)

---

## 🙏 致谢

- [OpenAI](https://openai.com/) - Whisper 和 GPT API
- [ElevenLabs](https://elevenlabs.io/) - 语音技术
- Apple - 优秀的开发工具和系统 API

---

## 📧 联系

- **问题反馈**: [GitHub Issues](https://github.com/yourusername/MindFlow/issues)
- **功能建议**: [GitHub Discussions](https://github.com/yourusername/MindFlow/discussions)

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐️**

Made with ❤️ for productivity enthusiasts

</div>

# MindFlow - macOS 语音转文字助手设计计划

## 📋 项目概述

**MindFlow** 是一个 macOS 原生应用程序，旨在提供系统级的语音转文字功能，并通过 LLM 智能清理和优化文本内容。应用程序可以在任何文本输入场景下被快速唤起，提升用户的文字输入效率。

### 核心价值主张
- 🎤 快速语音输入：在任何应用中一键触发语音输入
- ✨ 智能文本优化：自动去除填充词、语气词，优化语句结构
- 🔒 隐私优先：本地存储 API 密钥，无需账户登录
- ⚡ 无缝集成：全局热键触发，自动粘贴到当前输入框

---

## 🎯 核心功能

### 1. 语音识别（STT）
- **录音控制**
  - 按住录音 / 点击录音两种模式
  - 实时音频波形显示
  - 录音时长显示
  - 支持暂停和继续
  
- **API 集成**
  - OpenAI Whisper API
  - ElevenLabs Speech-to-Text API
  - 可扩展的 API 提供商架构

### 2. 文本智能优化
- **LLM 处理**
  - 去除填充词（嗯、啊、那个、这个等）
  - 修正语法错误
  - 优化句子结构
  - 添加标点符号
  - 分段优化

- **可配置选项**
  - 优化强度（轻度/中度/重度）
  - 保留原意程度
  - 语言风格（口语化/书面化）

### 3. 全局快捷访问
- **触发方式**
  - 全局热键（如 ⌘ + Shift + V）
  - 菜单栏图标点击
  - 可选：文本输入框右键菜单集成

- **输出方式**
  - 自动粘贴到当前活动输入框
  - 复制到剪贴板
  - 显示预览并确认

### 4. 设置管理
- **API 配置**
  - OpenAI API Key 存储
  - ElevenLabs API Key 存储
  - API 提供商选择
  - 密钥验证

- **应用设置**
  - 全局热键自定义
  - 默认优化模式
  - 自动粘贴开关
  - 启动时运行

---

## 🛠 技术栈

### 前端框架
**推荐：SwiftUI + Swift**
- ✅ 原生性能和体验
- ✅ 完美的 macOS 系统集成
- ✅ 简洁的声明式 UI
- ✅ 无需额外依赖

**备选：Tauri + React/Vue**
- ✅ Web 技术栈，开发快速
- ✅ 较小的应用体积
- ⚠️ 性能略逊于原生
- ⚠️ 系统集成需要额外工作

### 关键技术组件

#### 1. 音频录制
**Swift 方案：**
```
AVFoundation (AVAudioRecorder/AVAudioEngine)
- 音频采集
- 实时音频监控
- 格式转换
```

#### 2. 全局热键监听
**Swift 方案：**
```
CGEventTap API
- 系统级热键监听
- 需要辅助功能权限
```

**Tauri 方案：**
```
global-hotkey crate (Rust)
- 跨平台热键支持
```

#### 3. 密钥安全存储
```
Keychain Services (macOS)
- 系统级加密存储
- 安全的凭证管理
```

#### 4. 剪贴板操作
```
NSPasteboard (Swift)
or
tauri-plugin-clipboard (Tauri)
```

#### 5. 自动粘贴
```
CGEvent API (模拟键盘 Cmd+V)
- 需要辅助功能权限
```

### API 服务

#### STT 服务
1. **OpenAI Whisper API**
   - 端点：`https://api.openai.com/v1/audio/transcriptions`
   - 支持多语言
   - 高准确率

2. **ElevenLabs STT API**
   - 端点：`https://api.elevenlabs.io/v1/speech-to-text`
   - 支持实时流式识别（如果提供）

#### LLM 服务
1. **OpenAI GPT-4o-mini**
   - 成本效益高
   - 快速响应
   - 文本清理效果好

2. **GPT-4（可选）**
   - 更高质量
   - 更贵

---

## 🏗 架构设计

### 应用架构

```
┌─────────────────────────────────────────────┐
│           MindFlow 应用                      │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │        UI Layer (SwiftUI)            │  │
│  │  - 悬浮窗口                           │  │
│  │  - 设置面板                           │  │
│  │  - 菜单栏图标                         │  │
│  └──────────────────────────────────────┘  │
│                   ↓                         │
│  ┌──────────────────────────────────────┐  │
│  │      Service Layer                   │  │
│  │                                      │  │
│  │  ┌─────────────┐  ┌───────────────┐ │  │
│  │  │ Audio       │  │ STT Service   │ │  │
│  │  │ Recorder    │→ │               │ │  │
│  │  └─────────────┘  └───────────────┘ │  │
│  │                          ↓           │  │
│  │                   ┌───────────────┐ │  │
│  │                   │ LLM Service   │ │  │
│  │                   └───────────────┘ │  │
│  │                          ↓           │  │
│  │                   ┌───────────────┐ │  │
│  │                   │ Clipboard     │ │  │
│  │                   │ Manager       │ │  │
│  │                   └───────────────┘ │  │
│  └──────────────────────────────────────┘  │
│                   ↓                         │
│  ┌──────────────────────────────────────┐  │
│  │      Data Layer                      │  │
│  │  - Keychain (API Keys)               │  │
│  │  - UserDefaults (Settings)           │  │
│  │  - File System (History - optional)  │  │
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

### 数据流

```
用户触发 (热键/按钮)
    ↓
显示录音 UI
    ↓
录制音频
    ↓
音频文件 → STT API → 原始文本
    ↓
显示原始文本预览
    ↓
原始文本 → LLM API → 优化后文本
    ↓
显示优化文本
    ↓
用户确认 → 复制/粘贴到目标应用
```

---

## 🎨 UI/UX 设计

### 1. 主悬浮窗口

**录音界面（Compact Mode）**
```
┌─────────────────────────────────┐
│  🎤  MindFlow                   │
├─────────────────────────────────┤
│                                 │
│      ●  录音中...               │
│   [===========>    ]            │
│      00:05                      │
│                                 │
│  [⏸ 暂停]  [⏹ 停止并处理]       │
│                                 │
└─────────────────────────────────┘
```

**文本预览界面**
```
┌─────────────────────────────────────┐
│  📝  MindFlow                       │
├─────────────────────────────────────┤
│                                     │
│  原始文本：                          │
│  ┌───────────────────────────────┐  │
│  │ 嗯，那个，我想说的是，就是    │  │
│  │ 这个项目嗯需要在下周完成...   │  │
│  └───────────────────────────────┘  │
│                                     │
│  优化后：                            │
│  ┌───────────────────────────────┐  │
│  │ 我想说的是，这个项目需要在    │  │
│  │ 下周完成。                    │  │
│  └───────────────────────────────┘  │
│                                     │
│  优化级别: [轻 ● 中 ○ 重]          │
│                                     │
│  [📋 复制]  [✨ 重新优化]  [✓ 粘贴] │
│                                     │
└─────────────────────────────────────┘
```

### 2. 设置面板

```
┌─────────────────────────────────────────┐
│  ⚙️  MindFlow 设置                      │
├─────────────────────────────────────────┤
│                                         │
│  【API 配置】                            │
│                                         │
│  STT 提供商: [OpenAI ▼]                 │
│  OpenAI API Key:                        │
│  [********************************]      │
│  [验证] ✓ 有效                          │
│                                         │
│  ElevenLabs API Key:                    │
│  [********************************]      │
│  [验证] - 未配置                        │
│                                         │
│  【LLM 配置】                            │
│  OpenAI API Key:                        │
│  [********************************]      │
│  模型: [gpt-4o-mini ▼]                  │
│                                         │
│  【快捷键】                              │
│  全局触发: [⌘ Shift V]  [录制...]      │
│                                         │
│  【行为】                                │
│  ☑ 处理完成后自动粘贴                    │
│  ☑ 登录时启动                            │
│  ☐ 显示桌面通知                          │
│                                         │
│  【默认优化】                            │
│  优化强度: [轻 ○ 中 ● 重]              │
│  输出风格: [口语化 ● 书面化]            │
│                                         │
│         [保存设置]  [取消]              │
│                                         │
└─────────────────────────────────────────┘
```

### 3. 菜单栏图标

```
菜单栏: [🎤]

点击展开:
├─ 开始录音
├─ 历史记录 →
├─ 设置...
├─ ──────────
└─ 退出
```

---

## 🔌 API 集成详细设计

### 1. OpenAI Whisper API

**请求示例：**
```bash
POST https://api.openai.com/v1/audio/transcriptions
Content-Type: multipart/form-data
Authorization: Bearer YOUR_API_KEY

file: audio.m4a
model: whisper-1
language: zh (可选，可自动检测)
response_format: json
```

**响应：**
```json
{
  "text": "这是转录的文本内容"
}
```

### 2. OpenAI Chat API (文本优化)

**请求示例：**
```json
POST https://api.openai.com/v1/chat/completions
Authorization: Bearer YOUR_API_KEY

{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "你是一个专业的文本编辑助手。请去除以下文本中的填充词（如'嗯'、'啊'、'那个'、'这个'等），修正语法错误，优化句子结构，使其更加流畅易读。保持原意不变。"
    },
    {
      "role": "user",
      "content": "嗯，那个，我想说的是，就是这个项目嗯需要在下周完成"
    }
  ],
  "temperature": 0.3
}
```

**响应：**
```json
{
  "choices": [{
    "message": {
      "content": "我想说的是，这个项目需要在下周完成。"
    }
  }]
}
```

### 3. ElevenLabs API (备选)

**文档参考：** https://elevenlabs.io/docs/api-reference/speech-to-text

---

## 🚀 开发路线图

### Phase 1: MVP 核心功能（2-3周）

**Week 1: 基础架构**
- [x] 项目初始化（Swift/Xcode 或 Tauri）
- [ ] 基础 UI 框架搭建
- [ ] 菜单栏应用结构
- [ ] 设置面板实现
- [ ] Keychain 密钥存储实现

**Week 2: 核心功能**
- [ ] 音频录制功能
- [ ] OpenAI Whisper API 集成
- [ ] OpenAI Chat API 集成（文本优化）
- [ ] 基础 UI 交互流程

**Week 3: 系统集成**
- [ ] 全局热键监听
- [ ] 剪贴板操作
- [ ] 自动粘贴功能（CGEvent）
- [ ] 权限请求处理（麦克风、辅助功能）

### Phase 2: 优化与完善（1-2周）

**Week 4: 用户体验**
- [ ] UI 动画和过渡效果
- [ ] 实时音频波形显示
- [ ] 错误处理和用户反馈
- [ ] Loading 状态和进度显示

**Week 5: 高级功能**
- [ ] 历史记录功能
- [ ] 多种优化模式切换
- [ ] ElevenLabs API 集成（可选）
- [ ] 快捷键自定义

### Phase 3: 测试与发布（1周）

**Week 6: 测试与打包**
- [ ] 功能测试
- [ ] 性能优化
- [ ] 应用签名和公证（notarization）
- [ ] DMG 安装包制作
- [ ] 文档编写

---

## 🎯 技术实现重点

### 1. 权限管理

macOS 应用需要请求以下权限：

**麦克风权限**
```xml
<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>MindFlow 需要访问麦克风以录制您的语音</string>
```

**辅助功能权限**（用于全局热键和自动粘贴）
```swift
// 检查并请求辅助功能权限
let options: NSDictionary = [
    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
]
let accessEnabled = AXIsProcessTrustedWithOptions(options)
```

### 2. 全局热键实现

**Swift 示例：**
```swift
import Carbon

class HotKeyManager {
    var hotKeyRef: EventHotKeyRef?
    
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: 0x4D464C57, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, 
                          GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
```

### 3. 音频录制

**Swift 示例：**
```swift
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record)
        try? audioSession.setActive(true)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
    }
}
```

### 4. Keychain 存储

**Swift 示例：**
```swift
import Security

class KeychainManager {
    func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        return nil
    }
}
```

---

## ⚠️ 挑战与解决方案

### 挑战 1: 系统权限
**问题：** macOS 对系统级操作有严格的权限控制

**解决方案：**
- 友好的权限请求引导
- 清晰的权限说明文案
- 降级方案（无自动粘贴权限时，仅复制到剪贴板）

### 挑战 2: API 成本
**问题：** 频繁调用 OpenAI API 可能产生较高费用

**解决方案：**
- 显示 API 使用统计
- 提供本地缓存机制
- 可配置的自动优化开关
- 支持多个 API 提供商

### 挑战 3: 实时性能
**问题：** API 调用延迟影响用户体验

**解决方案：**
- 异步处理，显示进度
- 本地音频预处理（降噪、格式转换）
- 流式处理（如果 API 支持）
- 离线模式（使用本地 Whisper 模型 - 高级功能）

### 挑战 4: 多语言支持
**问题：** 不同语言的填充词不同

**解决方案：**
- 语言检测
- 针对不同语言定制 LLM Prompt
- 用户可选语言模式

### 挑战 5: 应用分发
**问题：** macOS 应用需要签名和公证

**解决方案：**
- 注册 Apple Developer 账号
- 配置代码签名
- 使用 Xcode 或 `codesign` 工具
- 通过 `notarytool` 进行公证

---

## 📦 交付物

### 代码仓库结构
```
MindFlow/
├── README.md
├── DESIGN_PLAN.md (本文档)
├── LICENSE
├── .gitignore
├── MindFlow/              # 主应用代码
│   ├── App/
│   │   ├── MindFlowApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── RecordingView.swift
│   │   ├── PreviewView.swift
│   │   └── SettingsView.swift
│   ├── Services/
│   │   ├── AudioRecorder.swift
│   │   ├── STTService.swift
│   │   ├── LLMService.swift
│   │   ├── ClipboardManager.swift
│   │   └── HotKeyManager.swift
│   ├── Models/
│   │   ├── Settings.swift
│   │   └── TranscriptionResult.swift
│   ├── Managers/
│   │   ├── KeychainManager.swift
│   │   └── PermissionManager.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Info.plist
│   └── Utils/
│       └── Extensions.swift
├── MindFlow.xcodeproj
└── docs/
    ├── API_INTEGRATION.md
    └── USER_GUIDE.md
```

### 应用发布
- **GitHub Releases**: 提供 DMG 安装包
- **Homebrew Cask**: `brew install --cask mindflow`（可选）
- **Mac App Store**: （需要额外适配和审核）

---

## 💡 未来扩展方向

### V2.0 功能
- 🎯 多语言界面
- 📝 富文本格式支持
- 🔄 云端同步历史记录
- 🎨 自定义 UI 主题
- 📊 使用统计和分析
- 🔌 浏览器扩展支持

### V3.0 功能
- 🤖 本地 AI 模型（Whisper Core ML）
- 🎙️ 实时流式转录
- 👥 多用户配置文件
- 🌐 更多 API 提供商集成
- 📱 iOS 配套应用
- 🔗 与其他生产力工具集成（Notion, Obsidian 等）

---

## 📊 预估工作量

| 阶段 | 时间 | 人力 |
|------|------|------|
| Phase 1 (MVP) | 2-3 周 | 1 开发者 |
| Phase 2 (优化) | 1-2 周 | 1 开发者 |
| Phase 3 (发布) | 1 周 | 1 开发者 |
| **总计** | **4-6 周** | **1 开发者** |

---

## 🎓 学习资源

### Swift/SwiftUI
- [Apple SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com/)

### macOS 开发
- [Apple macOS Developer](https://developer.apple.com/macos/)
- [Ray Wenderlich macOS Tutorials](https://www.raywenderlich.com/macos)

### API 文档
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [ElevenLabs API Documentation](https://elevenlabs.io/docs)

---

## ✅ 下一步行动

1. **确认技术栈选择**
   - [ ] 决定使用 Swift (推荐) 还是 Tauri
   
2. **环境准备**
   - [ ] 安装 Xcode (Swift) 或配置 Tauri 环境
   - [ ] 获取 OpenAI API Key 用于测试
   
3. **项目初始化**
   - [ ] 创建项目基础结构
   - [ ] 配置项目依赖
   
4. **开始开发 Phase 1**
   - [ ] 从菜单栏应用骨架开始
   - [ ] 实现设置面板
   - [ ] 集成第一个 API 调用

---

**文档版本：** 1.0  
**创建日期：** 2025-10-10  
**作者：** AI Assistant  
**项目状态：** 规划阶段


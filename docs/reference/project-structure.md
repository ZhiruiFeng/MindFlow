# MindFlow 项目结构

本文档说明 MindFlow 项目的完整文件结构和各模块职责。

---

## 📁 目录结构

```
MindFlow/
├── README.md                    # 项目介绍和使用指南
├── LICENSE                      # MIT 许可证
├── .gitignore                  # Git 忽略文件配置
│
├── docs/                        # 文档目录
│   ├── README.md               # 文档索引
│   ├── guides/                 # 用户和开发指南
│   ├── reference/              # 技术参考文档（包含本文件）
│   ├── architecture/           # 架构和设计文档
│   └── troubleshooting/        # 问题排查指南
│
├── spec/                        # 规范和标准
│   └── coding-regulations/     # 编码规范
│
├── MindFlow/                   # 主应用代码目录
│   │
│   ├── App/                    # 应用入口
│   │   ├── MindFlowApp.swift          # SwiftUI App 入口
│   │   └── AppDelegate.swift          # AppDelegate - 菜单栏管理
│   │
│   ├── Views/                  # UI 视图层
│   │   ├── SettingsView.swift         # 设置面板
│   │   ├── RecordingView.swift        # 录音界面
│   │   └── PreviewView.swift          # 文本预览界面
│   │
│   ├── Services/               # 业务服务层
│   │   ├── AudioRecorder.swift        # 音频录制服务
│   │   ├── STTService.swift           # 语音转文字服务（OpenAI Whisper）
│   │   ├── LLMService.swift           # LLM 文本优化服务（OpenAI GPT）
│   │   └── ClipboardManager.swift     # 剪贴板管理
│   │
│   ├── Models/                 # 数据模型
│   │   ├── Settings.swift             # 应用设置模型
│   │   └── TranscriptionResult.swift  # 转录结果模型
│   │
│   ├── Managers/               # 管理器
│   │   ├── KeychainManager.swift      # Keychain 安全存储
│   │   ├── PermissionManager.swift    # 系统权限管理
│   │   └── HotKeyManager.swift        # 全局热键管理
│   │
│   ├── Utils/                  # 工具类
│   │   └── Extensions.swift           # Swift 扩展
│   │
│   ├── Resources/              # 资源文件
│   │   └── Assets.xcassets            # 图片资源（需在 Xcode 中创建）
│   │
│   └── Info.plist              # 应用配置文件
│
└── docs/                       # 文档目录
    ├── SETUP_GUIDE.md                 # 开发环境搭建指南
    └── API_INTEGRATION.md             # API 集成文档
```

---

## 🏗 架构层次

### 1. 应用层 (App/)

**MindFlowApp.swift**
- SwiftUI 应用入口
- 使用 `@NSApplicationDelegateAdaptor` 桥接到 AppDelegate

**AppDelegate.swift**
- 菜单栏图标管理
- 全局热键注册
- 窗口管理（设置窗口、录音窗口）
- 应用生命周期管理

### 2. 视图层 (Views/)

**SettingsView.swift**
- API 密钥配置
- 权限状态显示
- 优化参数设置
- 快捷键配置

**RecordingView.swift**
- 录音控制界面
- 实时录音状态显示
- 音频波形动画
- 处理进度提示

**PreviewView.swift**
- 原始文本显示
- 优化后文本显示
- 优化级别调整
- 复制/粘贴操作

### 3. 服务层 (Services/)

**AudioRecorder.swift**
- 使用 AVFoundation 录制音频
- 支持暂停/继续
- 音频电平监控
- 临时文件管理

**STTService.swift**
- OpenAI Whisper API 集成
- 音频文件上传
- 转录结果解析
- ElevenLabs API 预留接口

**LLMService.swift**
- OpenAI Chat API 集成
- 多级优化策略
- Prompt 工程
- 错误处理和重试

**ClipboardManager.swift**
- NSPasteboard 剪贴板操作
- CGEvent 自动粘贴
- 键盘事件模拟

### 4. 模型层 (Models/)

**Settings.swift**
- 单例模式
- ObservableObject for SwiftUI
- API 密钥管理
- 用户偏好设置
- Keychain + UserDefaults 持久化

**TranscriptionResult.swift**
- 转录结果数据结构
- 包含原始文本、优化文本、时长等
- Codable for 序列化（可选的历史记录功能）

### 5. 管理器层 (Managers/)

**KeychainManager.swift**
- macOS Keychain Services 封装
- 安全存储 API 密钥
- CRUD 操作

**PermissionManager.swift**
- 麦克风权限管理
- 辅助功能权限检查
- 系统设置跳转

**HotKeyManager.swift**
- Carbon 框架封装
- 全局热键注册
- 事件处理回调

### 6. 工具层 (Utils/)

**Extensions.swift**
- Color 扩展（主题色）
- String 扩展（文本处理）
- TimeInterval 扩展（时间格式化）
- Date 扩展（日期格式化）
- View 扩展（UI 辅助）
- URL 扩展（文件信息）

---

## 🔄 数据流

### 完整的语音转文字流程

```
1. 用户触发
   ↓
2. AppDelegate.startRecording()
   ↓
3. 创建 RecordingView 窗口
   ↓
4. RecordingViewModel.startRecording()
   ↓
5. AudioRecorder.startRecording()
   ↓
6. 用户说话（录音中）
   ↓
7. 用户点击"停止"
   ↓
8. AudioRecorder.stopRecording() → 返回音频文件 URL
   ↓
9. STTService.transcribe(audioURL)
   ├─→ OpenAI Whisper API 调用
   └─→ 返回原始文本
   ↓
10. LLMService.optimizeText(originalText)
    ├─→ OpenAI Chat API 调用
    └─→ 返回优化后文本
    ↓
11. 创建 TranscriptionResult
    ↓
12. 更新 RecordingViewModel.state = .completed
    ↓
13. 显示 PreviewView（在 RecordingView 内）
    ↓
14. 用户点击"粘贴"
    ↓
15. ClipboardManager.copy() + paste()
    ↓
16. 文本插入到活动应用
    ↓
17. 完成 ✅
```

---

## 🔐 安全性

### API 密钥存储

- **存储位置**: macOS Keychain
- **加密**: 系统级加密
- **访问控制**: 仅当前应用可访问
- **实现**: `KeychainManager.swift`

### 权限控制

1. **麦克风权限**
   - 用途: 录制音频
   - 请求时机: 首次启动
   - Info.plist 说明: `NSMicrophoneUsageDescription`

2. **辅助功能权限**
   - 用途: 全局热键 + 自动粘贴
   - 可选权限: 不授予也能使用（手动复制）
   - 请求时机: 按需提示

### 隐私保护

- ✅ 不收集任何用户数据
- ✅ 录音文件临时存储，处理后删除
- ✅ API 调用直接发送到 OpenAI（不经过中间服务器）
- ✅ 无第三方追踪
- ✅ 无网络分析

---

## 📦 依赖项

### 系统框架

| 框架 | 用途 | 导入位置 |
|------|------|----------|
| SwiftUI | UI 框架 | 所有 View 文件 |
| AppKit | macOS UI 组件 | AppDelegate, ClipboardManager |
| AVFoundation | 音频录制 | AudioRecorder |
| Security | Keychain 访问 | KeychainManager |
| Carbon | 全局热键 | HotKeyManager |
| ApplicationServices | 辅助功能 API | PermissionManager, ClipboardManager |
| Foundation | 基础功能 | 所有文件 |

### 第三方依赖

**当前**: 无（纯系统框架实现）

**未来可能添加**:
- Sparkle（自动更新）
- KeyboardShortcuts（更好的热键 UI）

---

## 🧪 测试策略

### 单元测试

建议为以下模块编写测试：

1. **KeychainManager**
   - 保存/读取/删除测试
   - 边界情况测试

2. **Settings**
   - 默认值测试
   - 持久化测试

3. **Extensions**
   - 字符串处理测试
   - 时间格式化测试

### 集成测试

1. **API 集成测试**
   - STTService 与 OpenAI Whisper
   - LLMService 与 OpenAI Chat
   - Mock API 响应

2. **录音流程测试**
   - 录音开始/暂停/停止
   - 临时文件清理

### UI 测试

1. **SwiftUI Previews**
   - 所有 View 都有 Preview
   - 不同状态的 UI 展示

2. **手动测试清单**
   - [ ] 菜单栏图标显示
   - [ ] 全局热键触发
   - [ ] 录音功能
   - [ ] 文本转录
   - [ ] 文本优化
   - [ ] 复制/粘贴
   - [ ] 权限请求
   - [ ] 设置保存

---

## 🚀 性能优化

### 已实现的优化

1. **异步操作**
   - 所有 API 调用使用 async/await
   - 不阻塞主线程

2. **资源管理**
   - 录音文件自动清理
   - 使用临时目录

3. **网络优化**
   - 音频文件压缩（m4a, 128kbps）
   - 合理的 max_tokens 设置

### 未来优化方向

1. **本地缓存**
   - 缓存常见的优化结果
   - 减少重复 API 调用

2. **批处理**
   - 支持多段录音合并

3. **本地模型**
   - 集成 Core ML Whisper 模型
   - 离线使用

---

## 🐛 调试技巧

### 日志输出

代码中使用表情符号前缀区分日志类型：

- ✅ 成功操作
- ❌ 错误
- ⚠️ 警告
- 📤 发送请求
- 📥 收到响应
- 🔥 热键触发

### 常用调试点

1. **录音问题**
   - 检查 AudioRecorder 日志
   - 验证麦克风权限

2. **API 调用问题**
   - 打印请求 URL 和 Headers
   - 打印响应状态码和内容

3. **UI 问题**
   - 使用 SwiftUI Preview
   - 检查 @Published 属性更新

### Xcode 技巧

```swift
// 断点调试
po audioURL
po settings.openAIKey

// 条件断点
// 在断点上右键 -> Edit Breakpoint -> Condition
// 例如: error != nil

// 日志断点
// 不暂停执行，只打印日志
// Action: Log Message
```

---

## 📝 代码规范

### Swift 风格

- 使用 4 空格缩进
- 类型名使用 PascalCase
- 变量/函数名使用 camelCase
- 使用 `// MARK: -` 分隔代码段

### 注释规范

```swift
/// 功能简述
///
/// 详细说明
///
/// - Parameters:
///   - param1: 参数1说明
///   - param2: 参数2说明
/// - Returns: 返回值说明
/// - Throws: 可能抛出的错误
func exampleFunction(param1: String, param2: Int) throws -> Bool {
    // 实现
}
```

### Git Commit 规范

```
feat: 新增功能
fix: 修复 Bug
docs: 文档更新
style: 代码格式（不影响功能）
refactor: 重构
test: 测试相关
chore: 构建/配置相关
```

---

## 🔗 相关文档

- [README.md](README.md) - 项目介绍
- [DESIGN_PLAN.md](DESIGN_PLAN.md) - 详细设计文档
- [SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - 开发环境搭建
- [API_INTEGRATION.md](docs/API_INTEGRATION.md) - API 集成说明

---

**文档版本**: 1.0  
**更新日期**: 2025-10-10  
**维护者**: MindFlow Team


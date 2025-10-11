# Xcode 项目配置指南

文件已经移动到正确位置！现在需要在 Xcode 中进行配置。

---

## ✅ 当前项目结构

```
MindFlow/
├── MindFlow/                      # Xcode 项目源代码目录
│   ├── App/                       ✅ 应用入口
│   │   ├── MindFlowApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/                     ✅ UI 视图
│   │   ├── SettingsView.swift
│   │   ├── RecordingView.swift
│   │   └── PreviewView.swift
│   ├── Services/                  ✅ 业务服务
│   │   ├── AudioRecorder.swift
│   │   ├── STTService.swift
│   │   ├── LLMService.swift
│   │   └── ClipboardManager.swift
│   ├── Models/                    ✅ 数据模型
│   │   ├── Settings.swift
│   │   └── TranscriptionResult.swift
│   ├── Managers/                  ✅ 管理器
│   │   ├── KeychainManager.swift
│   │   ├── PermissionManager.swift
│   │   └── HotKeyManager.swift
│   ├── Utils/                     ✅ 工具类
│   │   └── Extensions.swift
│   ├── Assets.xcassets/           ✅ 资源文件
│   ├── Info.plist                 ✅ 配置文件
│   └── MindFlow.entitlements
├── MindFlow.xcodeproj/            # Xcode 项目文件
├── MindFlowTests/
└── MindFlowUITests/
```

---

## 🔧 在 Xcode 中配置（重要！）

### Step 1: 打开项目

```bash
open /Users/zhiruifeng/Workspace/dev/MindFlow/MindFlow/MindFlow.xcodeproj
```

或者在 Xcode 中：`File` → `Open` → 选择 `MindFlow.xcodeproj`

### Step 2: 添加文件到 Xcode（如果文件没有显示在左侧）

如果你在 Xcode 左侧的 Project Navigator 中看不到我们创建的文件夹，需要手动添加：

1. **选中 MindFlow 项目根节点**（蓝色图标）
2. **右键点击 MindFlow 文件夹**（黄色图标，在项目下面）
3. **选择 "Add Files to MindFlow..."**
4. **导航到** `/Users/zhiruifeng/Workspace/dev/MindFlow/MindFlow/MindFlow/`
5. **选择以下文件夹**（按住 Cmd 多选）：
   - App
   - Views
   - Services
   - Models
   - Managers
   - Utils
6. **确保勾选**：
   - ✅ `Copy items if needed`（如果提示的话）
   - ✅ `Create groups`（而不是 Create folder references）
   - ✅ `Add to targets: MindFlow`（勾选 MindFlow target）
7. **点击 Add**

### Step 3: 配置 Info.plist

1. **选中项目**（蓝色图标）
2. **选择 MindFlow Target**
3. **切换到 Info 标签页**
4. **添加以下键值**（点击 + 号）：

   **权限描述：**
   
   | Key | Type | Value |
   |-----|------|-------|
   | Privacy - Microphone Usage Description | String | MindFlow 需要访问麦克风以录制您的语音并转换为文字。 |
   | Privacy - AppleEvents Sending Usage Description | String | MindFlow 需要发送键盘事件以实现自动粘贴功能。 |
   
   **菜单栏应用配置：**
   
   | Key | Type | Value |
   |-----|------|-------|
   | Application is agent (UIElement) | Boolean | YES |
   
   或者在 Info.plist 的 **Raw Values** 视图中：
   
   | Key | Value |
   |-----|-------|
   | NSMicrophoneUsageDescription | MindFlow 需要访问麦克风以录制您的语音并转换为文字。 |
   | NSAppleEventsUsageDescription | MindFlow 需要发送键盘事件以实现自动粘贴功能。 |
   | LSUIElement | YES |

### Step 4: 配置项目设置

1. **选择 General 标签页**
   - **Minimum Deployments**: macOS 13.0
   - **Bundle Identifier**: com.yourname.MindFlow（可以保持默认）

2. **选择 Signing & Capabilities 标签页**
   - **Automatically manage signing**: 勾选
   - **Team**: 选择你的 Apple ID 或 None

### Step 5: 添加必要的 Frameworks

虽然代码中已经 import，但确认一下 Frameworks：

1. **选择 General 标签页**
2. **Frameworks, Libraries, and Embedded Content**
3. 确认已包含（应该是自动的）：
   - SwiftUI.framework
   - AppKit.framework
   - AVFoundation.framework
   - Security.framework
   - Carbon.framework
   - ApplicationServices.framework

如果缺少，点击 `+` 添加。

### Step 6: 编译检查

1. **选择运行目标**: `My Mac`
2. **点击 Build** (⌘B)
3. **检查错误**：
   - 如果有 "Cannot find type" 错误，确认所有文件都已添加到 target
   - 右键点击文件 → `File Inspector` → 检查 `Target Membership` 是否勾选了 MindFlow

---

## 🚀 运行应用

### 首次运行

1. **点击 Run 按钮** ▶️ 或按 `⌘R`
2. **授予麦克风权限**（会弹出系统提示）
3. **查看菜单栏**：你应该会看到一个 🎤 图标

### 配置 API Key

1. **点击菜单栏图标**
2. **选择 "设置..."**
3. **输入 OpenAI API Key**
4. **点击 "保存"**

### 测试功能

1. **点击菜单栏图标 → "开始录音"**
2. **或按全局热键**: `⌘ Shift V`
3. **对着麦克风说话**
4. **点击 "停止并处理"**
5. **查看转录和优化结果**

---

## 🐛 常见问题解决

### 问题 1: 文件显示为灰色或找不到

**解决方案**：
1. 选中文件
2. 打开右侧的 `File Inspector`（⌘⌥1）
3. 检查 `Target Membership`
4. 勾选 `MindFlow`

### 问题 2: 编译错误 "Cannot find type 'XXX'"

**解决方案**：
1. 确认所有 Swift 文件都已添加到项目
2. 检查每个文件的 Target Membership
3. Clean Build Folder: `Product` → `Clean Build Folder` (⌘⇧K)
4. 重新 Build

### 问题 3: Info.plist 配置没生效

**解决方案**：
1. 确认 Info.plist 在项目根目录
2. 在 Build Settings 中搜索 "Info.plist"
3. 确认 `Info.plist File` 指向正确路径：`MindFlow/Info.plist`

### 问题 4: 运行时找不到图标

**解决方案**：
1. 图标会使用系统内置的 SF Symbols
2. 代码中使用 `Image(systemName: "mic.fill")`
3. 不需要额外导入图片资源

### 问题 5: 权限请求没弹出

**解决方案**：
1. 检查 Info.plist 中的权限描述是否添加
2. 删除应用后重新运行
3. 或手动前往 `系统设置` → `隐私与安全性` 添加权限

---

## ✅ 验证清单

运行前检查：

- [ ] 所有 Swift 文件都显示在 Project Navigator 中
- [ ] 所有文件的 Target Membership 包含 MindFlow
- [ ] Info.plist 配置完成（3 个权限描述）
- [ ] Deployment Target 设置为 macOS 13.0
- [ ] 项目能成功编译（⌘B）
- [ ] 已准备好 OpenAI API Key

运行后检查：

- [ ] 菜单栏出现 🎤 图标
- [ ] 点击图标能看到菜单
- [ ] 能打开设置窗口
- [ ] 能打开录音窗口
- [ ] 麦克风权限已授予

---

## 📖 下一步

配置完成后，查看这些文档：

- **[QUICK_START.md](../QUICK_START.md)** - 快速使用指南
- **[DESIGN_PLAN.md](../DESIGN_PLAN.md)** - 了解设计思路
- **[PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md)** - 代码结构说明

---

## 💡 提示

### Xcode 快捷键

- `⌘B` - Build
- `⌘R` - Run
- `⌘.` - Stop
- `⌘⇧K` - Clean Build Folder
- `⌘0` - 显示/隐藏 Navigator
- `⌘⌥1` - File Inspector
- `⌘⇧Y` - 显示/隐藏 Console

### 调试技巧

1. **查看控制台日志**：运行时按 `⌘⇧Y` 打开 Console
2. **设置断点**：点击行号左侧添加断点
3. **查看变量**：断点处悬停鼠标或使用 Debug Area

---

## 🎉 完成

恭喜！如果以上步骤都完成了，你的 MindFlow 应该可以正常运行了！

**享受智能语音转文字的便利吧！** 🚀


# MindFlow 开发环境搭建指南

本文档将指导你如何在本地搭建 MindFlow 的开发环境并运行应用。

---

## 📋 前置要求

### 系统要求
- **macOS**: 13.0 (Ventura) 或更高版本
- **Xcode**: 14.0 或更高版本
- **Swift**: 5.7 或更高版本

### API 密钥
- **OpenAI API Key** (必需)
  - 注册地址: https://platform.openai.com/signup
  - 获取 API Key: https://platform.openai.com/api-keys
  - 建议设置月度预算限制

- **ElevenLabs API Key** (可选)
  - 注册地址: https://elevenlabs.io/

---

## 🛠 步骤 1: 安装 Xcode

1. 从 Mac App Store 安装 Xcode
2. 打开 Xcode，接受许可协议
3. 安装命令行工具：
   ```bash
   xcode-select --install
   ```

---

## 📁 步骤 2: 创建 Xcode 项目

由于 GitHub 仓库中只包含源代码文件，你需要手动创建 Xcode 项目：

### 方式 1: 使用 Xcode 图形界面（推荐）

1. **打开 Xcode**

2. **创建新项目**
   - 选择 `File` → `New` → `Project`
   - 选择 `macOS` → `App`
   - 点击 `Next`

3. **配置项目**
   - **Product Name**: MindFlow
   - **Team**: 选择你的开发者账号（或 None）
   - **Organization Identifier**: com.yourname（替换为你的）
   - **Bundle Identifier**: com.yourname.MindFlow
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Use Core Data**: 不勾选
   - **Include Tests**: 可选
   - 点击 `Next`

4. **选择保存位置**
   - 选择 `/Users/zhiruifeng/Workspace/dev/` 目录
   - 项目会创建在 `MindFlow` 文件夹中
   - 点击 `Create`

5. **删除默认文件**
   - 删除自动生成的 `ContentView.swift`
   - 保留 `MindFlowApp.swift` 和 `Assets.xcassets`

6. **导入项目文件**
   - 将仓库中的文件结构导入到 Xcode 项目中：
     ```
     MindFlow/
     ├── App/
     │   ├── MindFlowApp.swift
     │   └── AppDelegate.swift
     ├── Views/
     │   ├── SettingsView.swift
     │   ├── RecordingView.swift
     │   └── PreviewView.swift
     ├── Services/
     │   ├── AudioRecorder.swift
     │   ├── STTService.swift
     │   ├── LLMService.swift
     │   └── ClipboardManager.swift
     ├── Models/
     │   ├── Settings.swift
     │   └── TranscriptionResult.swift
     ├── Managers/
     │   ├── KeychainManager.swift
     │   ├── PermissionManager.swift
     │   └── HotKeyManager.swift
     ├── Utils/
     │   └── Extensions.swift
     └── Resources/
         └── Info.plist
     ```
   
   **操作方法**：
   - 在 Xcode 的 Project Navigator 中右键点击 `MindFlow` 文件夹
   - 选择 `Add Files to "MindFlow"...`
   - 选择对应的文件和文件夹
   - 确保勾选 `Copy items if needed`

7. **配置 Info.plist**
   - 在 Xcode 中选择项目根节点
   - 选择 `MindFlow` Target
   - 切换到 `Info` 标签
   - 手动添加以下权限描述：
     - **Privacy - Microphone Usage Description**
       - 值: `MindFlow 需要访问麦克风以录制您的语音并转换为文字。`
     - **Privacy - AppleEvents Sending Usage Description**
       - 值: `MindFlow 需要发送键盘事件以实现自动粘贴功能。`
   
   - 切换到 `General` 标签，设置：
     - **Deployment Target**: macOS 13.0
     - 取消勾选 **Supports Document Browser**

8. **配置菜单栏应用**
   - 在 `Info` 标签中添加：
     - **Application is agent (UIElement)**: YES
   - 这将使应用成为后台菜单栏应用（不显示在 Dock 中）

### 方式 2: 使用 Swift Package Manager（高级）

如果你熟悉 SPM，也可以创建 `Package.swift`：

```swift
// Package.swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MindFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MindFlow", targets: ["MindFlow"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MindFlow",
            dependencies: [],
            path: "MindFlow"
        )
    ]
)
```

---

## 🔑 步骤 3: 配置 API 密钥

应用首次运行时需要配置 API 密钥：

1. 运行应用
2. 点击菜单栏中的 🎤 图标
3. 选择 `设置...`
4. 输入你的 OpenAI API Key
5. 点击 `保存`

API 密钥会被安全地存储在 macOS Keychain 中。

---

## 🚀 步骤 4: 运行应用

### 在 Xcode 中运行

1. 选择 `My Mac` 作为运行目标
2. 点击 `Run` 按钮（或按 `⌘R`）
3. 首次运行时，系统会请求以下权限：
   - **麦克风权限** (必需)
   - **辅助功能权限** (可选，用于全局热键和自动粘贴)

### 授予权限

**麦克风权限**：
- 应用会自动弹出请求
- 点击 `允许`

**辅助功能权限**：
1. 打开 `系统设置` → `隐私与安全性` → `辅助功能`
2. 点击左下角的 🔒 解锁
3. 找到 `MindFlow` 并勾选
4. 重启应用

---

## ✅ 步骤 5: 测试功能

### 基础测试

1. **测试录音**
   - 点击菜单栏图标 → `开始录音`
   - 对着麦克风说话
   - 点击 `停止并处理`

2. **测试 API 集成**
   - 等待应用转录语音
   - 查看原始文本和优化后的文本
   - 测试复制和粘贴功能

3. **测试全局热键**
   - 按 `⌘ Shift V`
   - 应该会弹出录音窗口

### 调试日志

在 Xcode 的控制台中，你可以看到详细的日志输出：

```
✅ MindFlow 启动成功
✅ 全局热键注册成功: keyCode=9, modifiers=768
✅ 开始录音: recording_ABC123.m4a
✅ 转录成功: 嗯，那个，我想说的是...
✅ 文本优化成功
✅ 已复制到剪贴板
```

---

## 🔧 常见问题

### Q1: 编译错误 "Cannot find type 'XXX' in scope"

**解决方案**：
- 确保所有文件都已正确添加到 Xcode 项目中
- 检查文件的 `Target Membership`（选中文件，在右侧面板查看）
- 清理构建缓存：`Product` → `Clean Build Folder` (`⌘ Shift K`)

### Q2: 运行时崩溃

**解决方案**：
- 检查控制台日志，查看错误信息
- 确保已配置 OpenAI API Key
- 确认麦克风权限已授予

### Q3: 全局热键不工作

**解决方案**：
- 检查辅助功能权限是否已授予
- 尝试更换热键组合（在代码中修改）
- 重启应用

### Q4: API 调用失败

**解决方案**：
- 检查网络连接
- 验证 API Key 是否有效
- 检查 OpenAI 账户余额
- 查看控制台错误日志

### Q5: 音频录制失败

**解决方案**：
- 确认麦克风权限已授予
- 检查是否有其他应用占用麦克风
- 在系统设置中测试麦克风是否正常工作

---

## 📦 步骤 6: 打包发布（可选）

### 创建 Archive

1. 在 Xcode 中选择 `Product` → `Archive`
2. 等待构建完成
3. 在 Organizer 中选择刚创建的 Archive
4. 点击 `Distribute App`

### 导出应用

1. 选择 `Copy App`
2. 选择导出位置
3. 应用会被导出为 `.app` 文件

### 创建 DMG 安装包

使用以下命令创建 DMG：

```bash
# 创建临时文件夹
mkdir -p MindFlow_DMG
cp -r MindFlow.app MindFlow_DMG/

# 创建 DMG
hdiutil create -volname "MindFlow" -srcfolder MindFlow_DMG -ov -format UDZO MindFlow.dmg

# 清理
rm -rf MindFlow_DMG
```

### 代码签名和公证

如果要分发给其他用户，需要：

1. 注册 Apple Developer Program
2. 配置代码签名证书
3. 使用 `codesign` 签名应用
4. 使用 `notarytool` 公证应用

详细步骤参考：https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

---

## 🎯 下一步

恭喜！你已经成功搭建了 MindFlow 的开发环境。

接下来你可以：

- ⭐ 阅读源代码，了解实现细节
- 🔧 根据自己的需求修改和扩展功能
- 🐛 发现 Bug？欢迎提交 Issue
- 💡 有新想法？欢迎提交 Pull Request
- 📖 完善文档和示例

---

## 💬 获取帮助

如果遇到问题：

1. 查看 [README.md](../README.md)
2. 查看 [DESIGN_PLAN.md](../DESIGN_PLAN.md)
3. 查看 GitHub Issues
4. 提交新的 Issue

---

**祝你开发愉快！** 🚀


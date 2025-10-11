# 🔧 修复 MindFlow 权限配置

## 问题说明

应用启动后没有弹出麦克风权限请求对话框，因为 Info.plist 没有被正确打包到应用中。

---

## ✅ 快速修复（5分钟）

### Step 1: 在 Xcode 中打开项目

```bash
open /Users/zhiruifeng/Workspace/dev/MindFlow/MindFlow/MindFlow.xcodeproj
```

### Step 2: 配置 Build Settings

1. **点击左侧蓝色项目图标 "MindFlow"**
2. **选择 TARGETS 下的 "MindFlow"**（不是 PROJECT）
3. **点击 "Build Settings" 标签**
4. **搜索 `info.plist`** （右上角搜索框）
5. **找到 "Info.plist File" 这一行**
6. **双击值部分**，输入：
   ```
   MindFlow/Info.plist
   ```
7. **按 Enter 确认**

### Step 3: 验证 Info 标签

1. **点击 "Info" 标签**（与 Build Settings 同一行）
2. **查看是否有以下条目**：

如果**有**这些条目，说明配置正确：
- ✅ Privacy - Microphone Usage Description
- ✅ Privacy - Apple Events Sending Usage Description  
- ✅ Application is agent (UIElement)

如果**没有**，继续 Step 4。

### Step 4: 手动添加权限描述（如果 Step 3 中没有）

在 Info 标签页中：

1. **点击任意一行右侧的 ＋ 按钮**

2. **添加麦克风权限**：
   - 从下拉菜单选择：`Privacy - Microphone Usage Description`
   - 或直接输入：`NSMicrophoneUsageDescription`
   - Type: String
   - Value: `MindFlow 需要访问麦克风以录制您的语音并转换为文字。`

3. **再次点击 ＋ 添加 AppleEvents 权限**：
   - 选择：`Privacy - Apple Events Sending Usage Description`
   - 或输入：`NSAppleEventsUsageDescription`
   - Type: String
   - Value: `MindFlow 需要发送键盘事件以实现自动粘贴功能。`

4. **再次点击 ＋ 添加菜单栏应用设置**：
   - 选择：`Application is agent (UIElement)`
   - 或输入：`LSUIElement`
   - Type: Boolean
   - Value: **YES**（打勾）

### Step 5: 清理并重新构建

在 Xcode 菜单栏：

1. **Product** → **Clean Build Folder** (或按 `⌘⇧K`)
2. 等待清理完成
3. **Product** → **Build** (或按 `⌘B`)
4. 等待构建成功

### Step 6: 运行应用

1. **Product** → **Run** (或按 `⌘R`)
2. **应该会弹出权限请求对话框**！
3. **点击 "OK"** 授予麦克风权限

---

## 🔍 如果还是没有弹出权限对话框

### 检查 1: 验证 Info.plist 是否被打包

在终端运行：

```bash
cd /Users/zhiruifeng/Library/Developer/Xcode/DerivedData/MindFlow-*/Build/Products/Debug/

# 查看应用的 Info.plist
/usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" MindFlow.app/Contents/Info.plist
```

**期望输出**：
```
MindFlow 需要访问麦克风以录制您的语音并转换为文字。
```

**如果输出错误**：说明 Info.plist 还没正确配置，重复 Step 2-5。

### 检查 2: Bundle Identifier 是否正确

在 Xcode 中：

1. **General 标签**
2. **查看 Bundle Identifier**，例如：`com.yourname.MindFlow`
3. **记住这个 ID**

### 检查 3: 系统权限设置

1. 打开 **系统设置**（System Settings）
2. 点击 **隐私与安全性**（Privacy & Security）
3. 点击 **麦克风**（Microphone）
4. 查看列表中是否有 **MindFlow**
   - **如果有但未勾选**：勾选它
   - **如果没有**：说明应用还没请求权限，回到 Step 2 检查配置

### 检查 4: 重置权限（最后手段）

如果之前不小心点了"拒绝"，需要重置权限：

```bash
# 将 com.yourname.MindFlow 替换为你的 Bundle Identifier
tccutil reset Microphone com.yourname.MindFlow

# 然后重新运行应用
```

---

## 📸 截图参考

### Build Settings 应该看到：

```
All | Combined | Levels

搜索: info.plist

Packaging
  ▼ Info.plist File
    MindFlow/Info.plist
```

### Info 标签应该看到：

```
Custom macOS Application Target Properties

▼ Information Property List
  Privacy - Microphone Usage Description       String    MindFlow 需要访问麦克风...
  Privacy - Apple Events Sending Usage...      String    MindFlow 需要发送键盘事件...
  Application is agent (UIElement)             Boolean   YES
```

---

## 🎯 最终验证

运行应用后，应该看到：

1. **菜单栏**出现 🎤 图标
2. **系统弹出对话框**：
   ```
   "MindFlow" would like to access the microphone.
   
   MindFlow 需要访问麦克风以录制您的语音并转换为文字。
   
   [Don't Allow]  [OK]
   ```
3. 点击 **OK** 后，可以正常录音

---

## 💡 常见错误

### 错误 1: "Info.plist File not found"
**解决**：确保路径是 `MindFlow/Info.plist`，不是 `./MindFlow/Info.plist` 或绝对路径。

### 错误 2: Info 标签页是空的
**解决**：说明 Info.plist 路径不对，重新设置 Build Settings。

### 错误 3: 构建成功但没有权限对话框
**解决**：
1. Clean Build Folder (⌘⇧K)
2. 删除 DerivedData：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/MindFlow-*
   ```
3. 重新构建

### 错误 4: 权限对话框是英文的
**原因**：系统语言设置。
**不影响**：功能正常，只是显示语言不同。

---

## ✅ 成功标志

配置成功后，你会看到：

- ✅ Xcode 编译无错误
- ✅ 应用启动时弹出权限请求
- ✅ 系统设置 → 隐私 → 麦克风 中出现 MindFlow
- ✅ 点击"开始录音"后可以正常录制

---

## 🆘 需要帮助？

如果按照以上步骤还是不行，运行以下诊断命令：

```bash
cd /Users/zhiruifeng/Workspace/dev/MindFlow/MindFlow

# 1. 检查源文件 Info.plist
echo "=== 源 Info.plist ==="
/usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" MindFlow/Info.plist

# 2. 检查构建的应用 Info.plist
echo -e "\n=== 应用 Info.plist ==="
find ~/Library/Developer/Xcode/DerivedData/MindFlow-*/Build/Products/Debug -name "MindFlow.app" -exec /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" {}/Contents/Info.plist \;

# 3. 检查 Xcode 项目配置
echo -e "\n=== Xcode 项目配置 ==="
grep -A 2 "INFOPLIST_FILE" MindFlow.xcodeproj/project.pbxproj | head -5
```

将输出结果发给我，我可以帮你进一步诊断！

---

**祝你成功！** 🚀


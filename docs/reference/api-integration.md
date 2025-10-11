# API 集成文档

本文档详细说明 MindFlow 如何集成 OpenAI 和 ElevenLabs 的 API。

---

## 📋 目录

- [OpenAI Whisper API（STT）](#openai-whisper-api-stt)
- [OpenAI Chat API（LLM）](#openai-chat-api-llm)
- [ElevenLabs API（可选）](#elevenlabs-api-可选)
- [错误处理](#错误处理)
- [成本估算](#成本估算)

---

## OpenAI Whisper API (STT)

### 端点

```
POST https://api.openai.com/v1/audio/transcriptions
```

### 认证

```
Authorization: Bearer YOUR_API_KEY
```

### 请求格式

使用 `multipart/form-data` 格式上传音频文件：

```http
POST /v1/audio/transcriptions HTTP/1.1
Host: api.openai.com
Authorization: Bearer sk-...
Content-Type: multipart/form-data; boundary=----Boundary

------Boundary
Content-Disposition: form-data; name="model"

whisper-1
------Boundary
Content-Disposition: form-data; name="language"

zh
------Boundary
Content-Disposition: form-data; name="file"; filename="audio.m4a"
Content-Type: audio/m4a

[音频文件二进制数据]
------Boundary--
```

### 参数说明

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `file` | file | 是 | 音频文件（支持 m4a, mp3, wav 等） |
| `model` | string | 是 | 固定为 `whisper-1` |
| `language` | string | 否 | 语言代码（如 `zh` 中文，`en` 英文），留空则自动检测 |
| `response_format` | string | 否 | 响应格式：`json`（默认）、`text`、`srt`、`vtt` |
| `temperature` | number | 否 | 0-1 之间，默认 0（更确定的输出） |
| `prompt` | string | 否 | 可选的上下文提示 |

### 响应格式

**成功响应 (200 OK)**:

```json
{
  "text": "这是转录的文本内容"
}
```

**错误响应**:

```json
{
  "error": {
    "message": "错误描述",
    "type": "invalid_request_error",
    "param": null,
    "code": null
  }
}
```

### Swift 实现

在 `STTService.swift` 中的实现：

```swift
private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
    let endpoint = "https://api.openai.com/v1/audio/transcriptions"
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
    
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    // 构建请求体
    var body = Data()
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.append("whisper-1\r\n")
    
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
    body.append("zh\r\n")
    
    let audioData = try Data(contentsOf: audioURL)
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
    body.append("Content-Type: audio/m4a\r\n\r\n")
    body.append(audioData)
    body.append("\r\n")
    body.append("--\(boundary)--\r\n")
    
    request.httpBody = body
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 解析响应...
}
```

### 注意事项

1. **文件大小限制**: 最大 25 MB
2. **支持的格式**: mp3, mp4, mpeg, mpga, m4a, wav, webm
3. **最佳实践**:
   - 使用 m4a 格式（兼容性好，文件小）
   - 采样率 44.1kHz，单声道
   - 比特率 128 kbps
4. **速率限制**:
   - 每分钟请求数：50 RPM（根据你的账户等级）
   - 每天请求数：根据配额

---

## OpenAI Chat API (LLM)

### 端点

```
POST https://api.openai.com/v1/chat/completions
```

### 请求格式

```http
POST /v1/chat/completions HTTP/1.1
Host: api.openai.com
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "你是一个专业的文本编辑助手..."
    },
    {
      "role": "user",
      "content": "嗯，那个，我想说的是..."
    }
  ],
  "temperature": 0.3,
  "max_tokens": 1000
}
```

### 参数说明

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `model` | string | 是 | 模型名称（`gpt-4o-mini`、`gpt-4o`、`gpt-4`） |
| `messages` | array | 是 | 对话消息数组 |
| `temperature` | number | 否 | 0-2，默认 1。越低越确定，越高越随机 |
| `max_tokens` | number | 否 | 生成的最大 token 数 |
| `top_p` | number | 否 | 0-1，nucleus sampling 参数 |
| `n` | number | 否 | 生成多少个回复，默认 1 |
| `stream` | boolean | 否 | 是否流式返回 |

### 响应格式

**成功响应 (200 OK)**:

```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gpt-4o-mini",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "我想说的是，这个项目需要在下周完成。"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 56,
    "completion_tokens": 31,
    "total_tokens": 87
  }
}
```

### Swift 实现

在 `LLMService.swift` 中的实现：

```swift
private func optimizeWithOpenAI(
    text: String,
    level: OptimizationLevel,
    style: OutputStyle
) async throws -> String {
    let endpoint = "https://api.openai.com/v1/chat/completions"
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let systemPrompt = """
    \(level.systemPrompt)
    \(style.additionalPrompt)
    
    重要规则：
    1. 直接输出优化后的文本，不要添加任何解释或说明
    2. 保持原文的核心意思和关键信息
    """
    
    let requestBody: [String: Any] = [
        "model": settings.llmModel.rawValue,
        "messages": [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ],
        "temperature": 0.3,
        "max_tokens": 1000
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 解析响应...
}
```

### Prompt 工程

#### 轻度优化 Prompt

```
你是一个文本编辑助手。请去除以下文本中明显的填充词（如'嗯'、'啊'、'那个'、'这个'、'就是'等），但保留口语化的表达风格。保持原意不变。
```

#### 中度优化 Prompt

```
你是一个专业的文本编辑助手。请去除以下文本中的填充词（如'嗯'、'啊'、'那个'、'这个'、'就是'等），修正语法错误，优化句子结构，使其更加流畅易读。保持原意不变。
```

#### 重度优化 Prompt

```
你是一个专业的文本编辑助手。请深度优化以下文本：
1) 去除所有填充词和冗余表达
2) 修正语法错误
3) 重组句子结构
4) 转换为书面化表达
5) 确保逻辑清晰
保持原意不变。
```

### 注意事项

1. **Temperature 设置**: 使用 0.3 确保输出稳定性
2. **Token 限制**: 
   - 输入 + 输出总计不能超过模型上下文窗口
   - gpt-4o-mini: 128K tokens
   - gpt-4o: 128K tokens
3. **速率限制**: 根据账户等级，通常是 3,500 RPM（gpt-4o-mini）

---

## ElevenLabs API (可选)

### 端点

```
POST https://api.elevenlabs.io/v1/speech-to-text
```

### 请求格式

```http
POST /v1/speech-to-text HTTP/1.1
Host: api.elevenlabs.io
xi-api-key: YOUR_API_KEY
Content-Type: multipart/form-data

[音频文件]
```

### 参数说明

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `audio` | file | 是 | 音频文件 |
| `model_id` | string | 否 | 模型 ID |
| `language` | string | 否 | 语言代码 |

### 响应格式

```json
{
  "text": "转录的文本",
  "detected_language": "zh-CN"
}
```

### 注意事项

1. ElevenLabs 主要以语音合成（TTS）闻名
2. STT 功能可能需要企业计划
3. 目前代码中标记为 `notImplemented`

---

## 错误处理

### 常见错误码

#### OpenAI Whisper API

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 401 | 无效的 API Key | 检查 API Key 是否正确 |
| 413 | 文件太大 | 压缩音频或分段处理 |
| 429 | 速率限制 | 降低请求频率，稍后重试 |
| 500 | 服务器错误 | 稍后重试 |

#### OpenAI Chat API

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 400 | 请求参数错误 | 检查请求格式 |
| 401 | 认证失败 | 检查 API Key |
| 429 | 超出配额或速率限制 | 检查账户余额，降低请求频率 |
| 503 | 服务器过载 | 稍后重试 |

### 错误处理代码

```swift
enum STTError: LocalizedError {
    case missingAPIKey(String)
    case invalidAudioFile
    case invalidResponse
    case apiError(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidAudioFile:
            return "无效的音频文件"
        case .invalidResponse:
            return "服务器响应无效"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .notImplemented(let message):
            return message
        }
    }
}
```

### 重试策略

```swift
func retryWithExponentialBackoff<T>(
    maxAttempts: Int = 3,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            
            if attempt < maxAttempts {
                let delay = pow(2.0, Double(attempt)) // 2^attempt 秒
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    throw lastError ?? NSError(domain: "RetryError", code: -1)
}
```

---

## 成本估算

### OpenAI Whisper API

**定价**: $0.006 / 分钟

示例：
- 30 秒录音 = $0.003
- 1 分钟录音 = $0.006
- 5 分钟录音 = $0.030

### OpenAI Chat API

**GPT-4o-mini 定价** (推荐):
- 输入: $0.15 / 1M tokens
- 输出: $0.60 / 1M tokens

示例（文本优化）：
- 平均输入: ~200 tokens (system prompt + 原文)
- 平均输出: ~100 tokens (优化后文本)
- 单次成本: ~$0.00009 ≈ $0.0001

**GPT-4o 定价**:
- 输入: $2.50 / 1M tokens
- 输出: $10.00 / 1M tokens
- 单次成本: ~$0.0015

### 总成本估算

**平均每次完整使用** (1 分钟录音 + 文本优化):
- Whisper: $0.006
- GPT-4o-mini: $0.0001
- **总计**: ~$0.0061 ≈ **$0.01 / 次**

**月度估算** (每天使用 10 次):
- 每天: $0.06
- 每月: ~$1.80

### 成本优化建议

1. **使用 GPT-4o-mini**: 成本是 GPT-4 的 1/15，质量足够好
2. **本地音频预处理**: 
   - 降噪、去除静音
   - 减少音频文件大小
3. **缓存结果**: 相同音频不重复转录
4. **设置 max_tokens**: 避免生成过长文本
5. **监控用量**: 
   ```swift
   // 在响应中获取 token 使用情况
   struct ChatResponse: Codable {
       struct Usage: Codable {
           let prompt_tokens: Int
           let completion_tokens: Int
           let total_tokens: Int
       }
       let usage: Usage
   }
   ```

---

## 调试和测试

### 使用 curl 测试 API

#### 测试 Whisper API

```bash
curl https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F file="@/path/to/audio.m4a" \
  -F model="whisper-1" \
  -F language="zh"
```

#### 测试 Chat API

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [
      {
        "role": "system",
        "content": "你是一个文本编辑助手。"
      },
      {
        "role": "user",
        "content": "嗯，那个，我想说的是，就是这个项目需要完成"
      }
    ],
    "temperature": 0.3
  }'
```

### 在代码中启用详细日志

```swift
// 在请求前
print("📤 发送请求到: \(endpoint)")
print("📝 请求体: \(String(data: requestBody, encoding: .utf8) ?? "")")

// 在收到响应后
print("📥 响应状态: \(httpResponse.statusCode)")
print("📄 响应内容: \(String(data: data, encoding: .utf8) ?? "")")
```

---

## 参考链接

- [OpenAI API 文档](https://platform.openai.com/docs/api-reference)
- [OpenAI Whisper](https://platform.openai.com/docs/guides/speech-to-text)
- [OpenAI Chat Completions](https://platform.openai.com/docs/guides/text-generation)
- [OpenAI 定价](https://openai.com/pricing)
- [ElevenLabs 文档](https://elevenlabs.io/docs)

---

**文档版本**: 1.0  
**更新日期**: 2025-10-10


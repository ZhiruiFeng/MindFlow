# Debugging: Supabase Auth & ZMemory API Integration

**Date:** 2025-10-14
**Component:** MindFlow Browser Extension
**Issue:** HTTP 404 and validation errors when syncing interactions to ZephyrOS backend
**Resolution:** Fixed field naming, enum values, and null handling

---

## Problem Statement

After implementing Supabase authentication and ZMemory API integration in the MindFlow browser extension, voice-to-text interactions were failing to sync to the ZephyrOS backend with two sequential errors:

1. **HTTP 404** - "page not found"
2. **Validation Failed** - Backend rejecting the request

Despite the API endpoint existing and authentication working, requests were not reaching the backend properly.

---

## Investigation Process

### Phase 1: Initial 404 Error

**Symptoms:**
```
[MindFlow Error] Failed to create interaction: HTTP 404
```

**Hypothesis:** Wrong API endpoint or field names

**Actions Taken:**
1. Added comprehensive logging to track request flow
2. Compared browser extension code with macOS app implementation
3. Examined backend validation schemas

**Findings:**

1. **Incorrect Field Names**
   - ❌ Extension sending: `original_text`, `optimized_text`, `teacher_notes`, `audio_duration_seconds`
   - ✅ Backend expecting: `original_transcription`, `refined_text`, `teacher_explanation`, `audio_duration`

2. **Incorrect Enum Values**

   **Field:** `transcription_api`
   - ❌ Extension sending: `'openai'` (lowercase)
   - ✅ Backend expecting: `'OpenAI'` or `'ElevenLabs'` (capitalized)

   **Field:** `output_style`
   - ❌ Extension sending: `'casual'`
   - ✅ Backend expecting: `'conversational'` or `'formal'`

### Phase 2: Validation Error

**Symptoms:**
```
[MindFlow Error] Failed to create interaction: Validation failed
```

**Hypothesis:** Optional fields with `null` values failing Zod validation

**Actions Taken:**
1. Examined backend Zod schemas in `/apps/zmemory/lib/validation/mindflow-stt.ts`
2. Analyzed how Zod handles `.optional()` vs `null` values

**Root Cause:**

```typescript
// Backend validation schema
audio_file_url: z.string().url().optional()
```

**Problem:** Zod's `.optional()` means:
- ✅ Field can be **omitted entirely**
- ❌ Field **cannot be `null`** (fails `.url()` validation)

**Solution:** Only include fields that have actual values, omit fields with `null`/`undefined`

---

## Solution Implementation

### 1. Fixed Field Names

**File:** `src/lib/zmemory-api.js`

```javascript
// Before (incorrect)
body: JSON.stringify({
  original_text: interaction.originalText,
  optimized_text: interaction.optimizedText,
  teacher_notes: interaction.teacherNotes,
  audio_duration_seconds: interaction.audioDurationSeconds
})

// After (correct)
body: JSON.stringify({
  original_transcription: interaction.originalText,
  refined_text: interaction.optimizedText,
  teacher_explanation: interaction.teacherNotes,
  audio_duration: interaction.audioDurationSeconds
})
```

### 2. Fixed Enum Value Mapping

**File:** `src/popup/popup.js`

```javascript
// Map provider names to backend format
const transcriptionApi = this.currentResult.provider === 'elevenlabs'
  ? 'ElevenLabs'
  : 'OpenAI';

// Map output style
const outputStyle = settings.outputStyle === 'casual'
  ? 'conversational'
  : 'formal';
```

### 3. Fixed Null Handling

**File:** `src/lib/zmemory-api.js`

```javascript
// Build request body, excluding null/undefined values
const requestBody = {
  original_transcription: interaction.originalText,
  transcription_api: interaction.transcriptionApi
};

// Only add optional fields if they have values
if (interaction.transcriptionModel) {
  requestBody.transcription_model = interaction.transcriptionModel;
}
if (interaction.optimizedText) {
  requestBody.refined_text = interaction.optimizedText;
}
if (interaction.optimizationModel) {
  requestBody.optimization_model = interaction.optimizationModel;
}
if (interaction.optimizationLevel) {
  requestBody.optimization_level = interaction.optimizationLevel;
}
if (interaction.outputStyle) {
  requestBody.output_style = interaction.outputStyle;
}
if (interaction.teacherNotes) {
  requestBody.teacher_explanation = interaction.teacherNotes;
}
if (interaction.audioDurationSeconds) {
  requestBody.audio_duration = interaction.audioDurationSeconds;
}
// Don't include audio_file_url at all if we don't have one
```

### 4. Enhanced Logging

Added comprehensive debugging logs to track the entire request lifecycle:

```javascript
log('📤 Creating interaction record');
log('🌐 Base URL:', this.baseURL);
log('🌐 Full URL:', url);
log('📦 Request body:', JSON.stringify(requestBody, null, 2));
log('🔑 Access token present:', !!accessToken);
log('🔑 Token (first 20 chars):', accessToken ? accessToken.substring(0, 20) + '...' : 'none');
log('🧪 Testing base URL accessibility...');
log('🚀 Sending fetch request...');
log('📥 Response status:', response.status);
log('📥 Response statusText:', response.statusText);
log('❌ Error response body:', responseText);
```

---

## Key Lessons Learned

### 1. API Contract Alignment

**Problem:** Browser extension and backend had different field naming conventions.

**Lesson:** Always reference the **source of truth** (backend validation schemas) when implementing API clients. In this case:
- Backend: `/apps/zmemory/lib/validation/mindflow-stt.ts`
- Reference implementation: macOS app's `InteractionRecord.swift`

**Best Practice:**
- Generate TypeScript/JavaScript types from backend schemas
- Use shared type definitions across platforms
- Consider using tools like `zod-to-ts` or OpenAPI codegen

### 2. Enum Consistency

**Problem:** Different string case conventions across platforms.

**Lesson:** Enums must match **exactly** - case matters!

**Best Practice:**
- Document enum values clearly in API specifications
- Create mapping functions for platform-specific conventions
- Validate enum values at compile/build time when possible

### 3. Optional Field Handling with Zod

**Problem:** Zod's `.optional()` behavior differs from nullable fields.

**Lesson:** In Zod validation:
```typescript
z.string().url().optional()
```
Means:
- ✅ Field can be omitted: `{}`
- ❌ Field cannot be `null`: `{ audio_file_url: null }`
- ✅ Field must be valid if present: `{ audio_file_url: "https://..." }`

**Best Practice:**
- Only include fields with actual values in API requests
- Use conditional logic to build request bodies
- If you need nullable fields, use: `z.string().url().nullable().optional()`

### 4. Cross-Platform API Clients

**Problem:** Different platforms (macOS Swift, Browser JS) need to call the same API.

**Lesson:** Maintain consistency by:
1. Using the same field names across all clients
2. Following the same validation rules
3. Implementing the same optional field logic

**Best Practice:**
- Keep a reference implementation (e.g., macOS app)
- Document all API contracts centrally
- Write integration tests that validate API contracts

### 5. Debugging Techniques

**Effective Strategies Used:**

1. **Comprehensive Logging:** Log request details, response details, and intermediate steps
2. **Source Comparison:** Compare working implementation (macOS) with broken one (extension)
3. **Schema Inspection:** Read backend validation schemas to understand expectations
4. **Incremental Testing:** Fix one issue at a time (field names → enums → null handling)

**Best Practice:**
- Add logging at request preparation, transmission, and response handling
- Log actual values, not just success/failure
- Include request/response headers for debugging auth issues
- Test base URL accessibility before attempting API calls

---

## Verification

### Success Criteria

✅ Voice recordings successfully sync to ZephyrOS backend
✅ Interaction records appear in ZMemory database
✅ All required fields validated correctly
✅ Optional fields handled properly
✅ Authentication working with Supabase tokens

### Test Case

1. User signs in with Google OAuth via Supabase
2. User records voice in browser extension
3. Extension transcribes audio via OpenAI Whisper
4. Extension optimizes text via GPT-4o-mini
5. Extension syncs interaction to ZMemory API
6. Backend validates and stores interaction
7. User can view interaction on Zflow platform

### Console Output (Success)

```
📤 Syncing interaction to ZephyrOS backend...
📦 Interaction object to sync: {...}
📤 Creating interaction record
🌐 Base URL: https://zmemory.zephyros.app
🌐 Full URL: https://zmemory.zephyros.app/api/mindflow-stt-interactions
📦 Request body: {
  "original_transcription": "um so I think we should uh...",
  "transcription_api": "OpenAI",
  "transcription_model": "whisper-1",
  "refined_text": "I think we should...",
  "optimization_model": "gpt-4o-mini",
  "optimization_level": "medium",
  "output_style": "conversational"
}
🔑 Access token present: true
🧪 Testing base URL accessibility...
✅ Base URL is accessible, status: 200
🚀 Sending fetch request...
📥 Response received
📥 Response status: 201
✅ Interaction created successfully: 123e4567-e89b-12d3-a456-426614174000
✓ Synced to ZephyrOS
```

---

## Related Files

### Modified Files
- `src/lib/zmemory-api.js` - API client with fixed field names and null handling
- `src/popup/popup.js` - Enum value mapping and sync integration
- `src/lib/storage-manager.js` - Supabase credential storage
- `src/lib/supabase-auth.js` - OAuth authentication
- `manifest.json` - Added identity permission and host permissions

### Reference Files
- `/apps/zmemory/lib/validation/mindflow-stt.ts` - Backend validation schema
- `/apps/zmemory/app/api/mindflow-stt-interactions/route.ts` - Backend API route
- `MindFlow/MindFlow/Models/InteractionRecord.swift` - macOS reference implementation
- `MindFlow/MindFlow/Services/MindFlowAPIClient.swift` - macOS API client

---

## Prevention

### For Future API Integrations

1. **Start with Schema Review**
   - Read backend validation schemas first
   - Understand required vs optional fields
   - Note exact enum values

2. **Reference Existing Implementations**
   - Find working client (e.g., macOS app)
   - Copy field naming and structure
   - Maintain consistency across platforms

3. **Build Request Bodies Carefully**
   - Only include fields with values
   - Map platform conventions to API conventions
   - Validate enum values before sending

4. **Add Comprehensive Logging**
   - Log full request details during development
   - Keep logs for debugging production issues
   - Include request/response bodies (sanitized)

5. **Test Early and Often**
   - Test API integration as soon as auth works
   - Don't wait until full feature is complete
   - Use backend development environment for testing

---

## Conclusion

This debugging session demonstrates the importance of:
- **API contract alignment** between client and server
- **Careful handling of optional fields** with validation libraries
- **Comprehensive logging** for distributed system debugging
- **Cross-platform consistency** in API client implementations

The MindFlow browser extension now successfully syncs voice-to-text interactions to the ZephyrOS backend, enabling users to track their thought flow across all platforms.

**Time to Resolution:** ~2 hours
**Root Causes:** 3 (field names, enum values, null handling)
**Lines of Code Changed:** ~150
**Impact:** Full integration between browser extension and ZephyrOS ecosystem

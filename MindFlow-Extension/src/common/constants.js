/**
 * @fileoverview Application constants and configuration
 * @module constants
 */

// Storage keys
export const STORAGE_KEYS = {
  // API Configuration
  OPENAI_API_KEY: 'apiKey_openai',
  ELEVENLABS_API_KEY: 'apiKey_elevenlabs',

  // Supabase Authentication
  SUPABASE_CONFIG: 'supabase_config',
  SUPABASE_ACCESS_TOKEN: 'supabase_access_token',
  SUPABASE_REFRESH_TOKEN: 'supabase_refresh_token',
  SUPABASE_USER_INFO: 'supabase_user_info',

  // Settings
  SETTINGS: 'settings',

  // State
  RECORDING_STATE: 'recordingState',

  // History (optional feature)
  HISTORY: 'history',

  // Vocabulary
  VOCABULARY: 'vocabulary',
  VOCABULARY_STATS: 'vocabularyStats'
};

// Default settings
export const DEFAULT_SETTINGS = {
  // STT Configuration
  sttProvider: 'openai', // 'openai' | 'elevenlabs'

  // LLM Configuration
  llmModel: 'gpt-4o-mini',
  optimizationLevel: 'medium', // 'light' | 'medium' | 'heavy'
  outputStyle: 'casual', // 'casual' | 'formal'
  showTeacherNotes: false, // Show teacher notes/feedback

  // Behavior
  autoInsert: true,
  showNotifications: true,
  keepHistory: false,

  // Sync Configuration
  autoSyncToBackend: true, // Automatically sync to ZephyrOS backend
  autoSyncThreshold: 30, // Minimum duration (seconds) to auto-sync

  // UI
  theme: 'auto' // 'light' | 'dark' | 'auto'
};

// Optimization levels
export const OPTIMIZATION_LEVELS = {
  LIGHT: 'light',
  MEDIUM: 'medium',
  HEAVY: 'heavy'
};

// Output styles
export const OUTPUT_STYLES = {
  CASUAL: 'casual',
  FORMAL: 'formal'
};

// STT Providers
export const STT_PROVIDERS = {
  OPENAI: 'openai',
  ELEVENLABS: 'elevenlabs'
};

// LLM Models
export const LLM_MODELS = {
  GPT_4O_MINI: 'gpt-4o-mini',
  GPT_4O: 'gpt-4o',
  GPT_4: 'gpt-4'
};

// API Endpoints
export const API_ENDPOINTS = {
  OPENAI_TRANSCRIPTION: 'https://api.openai.com/v1/audio/transcriptions',
  OPENAI_CHAT: 'https://api.openai.com/v1/chat/completions',
  ELEVENLABS_STT: 'https://api.elevenlabs.io/v1/speech-to-text',
  ELEVENLABS_TTS: 'https://api.elevenlabs.io/v1/text-to-speech'
};

// TTS Configuration
export const TTS_CONFIG = {
  // Rachel voice - clear American female, good for pronunciation
  DEFAULT_VOICE_ID: '21m00Tcm4TlvDq8ikWAM',
  // Multilingual model for better pronunciation
  MODEL_ID: 'eleven_multilingual_v2',
  // Voice settings
  VOICE_SETTINGS: {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
    use_speaker_boost: true
  }
};

// Recording states
export const RECORDING_STATES = {
  IDLE: 'idle',
  RECORDING: 'recording',
  PAUSED: 'paused',
  PROCESSING: 'processing',
  TRANSCRIBING: 'transcribing',
  OPTIMIZING: 'optimizing',
  COMPLETED: 'completed',
  ERROR: 'error'
};

// Audio settings
export const AUDIO_CONFIG = {
  MIME_TYPE: 'audio/webm;codecs=opus',
  SAMPLE_RATE: 44100,
  CHANNEL_COUNT: 1,
  BITS_PER_SECOND: 128000
};

// Validation limits
export const VALIDATION = {
  MIN_RECORDING_DURATION: 1000, // 1 second in ms
  MAX_RECORDING_DURATION: 300000, // 5 minutes in ms
  MAX_TEXT_LENGTH: 10000, // Maximum characters for optimization
  API_KEY_MIN_LENGTH: 20
};

// Error messages
export const ERROR_MESSAGES = {
  NO_API_KEY: 'API key not configured. Please add your API key in settings.',
  INVALID_API_KEY: 'Invalid API key. Please check your settings.',
  RECORDING_TOO_SHORT: 'Recording too short. Please speak for at least 1 second.',
  RECORDING_TOO_LONG: 'Recording exceeded maximum duration of 5 minutes.',
  TRANSCRIPTION_FAILED: 'Transcription failed. Please try again.',
  OPTIMIZATION_FAILED: 'Optimization failed. Using original transcription.',
  NO_MICROPHONE: 'Microphone access denied. Please click "Allow" when Chrome asks for microphone permission, then try recording again.',
  NETWORK_ERROR: 'Network error. Please check your connection and try again.',
  RATE_LIMIT: 'Rate limit exceeded. Please wait a moment and try again.',
  NO_ACTIVE_INPUT: 'No active input field found. Please click in a text field first.',
  UNKNOWN_ERROR: 'An unexpected error occurred. Please try again.'
};

// System prompts for different optimization levels
export const SYSTEM_PROMPTS = {
  light: `You are a professional text editor. Your task is to:
1. Remove obvious filler words (um, uh, er, ah)
2. Add basic punctuation
3. Keep everything else exactly as spoken, including casual language and minor grammatical quirks

Preserve the original tone and style. Make minimal changes.`,

  medium: `You are a professional text editor. Your task is to:
1. Remove all filler words (um, uh, like, you know, I mean, etc.)
2. Fix grammar errors
3. Improve sentence structure for clarity
4. Add proper punctuation
5. Keep the casual, conversational tone

Preserve the original meaning and personality while making the text more readable.`,

  heavy: `You are a professional text editor. Your task is to:
1. Remove all filler words and verbal tics
2. Fix all grammar and punctuation errors
3. Restructure sentences for maximum clarity and impact
4. Improve word choice and eliminate redundancy
5. Transform casual speech into polished, professional writing

Create formal, publication-ready text while preserving all key information and intent.`
};

// Message types for chrome.runtime messaging
export const MESSAGE_TYPES = {
  START_RECORDING: 'startRecording',
  STOP_RECORDING: 'stopRecording',
  TRANSCRIBE_AUDIO: 'transcribeAudio',
  OPTIMIZE_TEXT: 'optimizeText',
  INSERT_TEXT: 'insertText',
  GET_SETTINGS: 'getSettings',
  SAVE_SETTINGS: 'saveSettings',
  VALIDATE_API_KEY: 'validateApiKey',

  // Vocabulary
  VOCABULARY_LOOKUP: 'vocabularyLookup',
  VOCABULARY_ADD: 'vocabularyAdd',
  VOCABULARY_GET_DUE: 'vocabularyGetDue'
};

// Chrome storage limits
export const STORAGE_LIMITS = {
  SYNC_QUOTA_BYTES: 102400, // 100KB
  SYNC_QUOTA_BYTES_PER_ITEM: 8192, // 8KB
  LOCAL_QUOTA_BYTES: 5242880 // 5MB
};

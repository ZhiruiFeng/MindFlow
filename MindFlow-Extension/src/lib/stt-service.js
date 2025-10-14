/**
 * @fileoverview Speech-to-Text service for transcribing audio
 * @module stt-service
 *
 * Supports multiple STT providers:
 * - OpenAI Whisper API
 * - ElevenLabs Speech-to-Text API
 *
 * @example
 * const stt = new STTService();
 * const result = await stt.transcribe(audioBlob);
 * console.log(result.text, result.provider);
 */

import {
  API_ENDPOINTS,
  STT_PROVIDERS,
  ERROR_MESSAGES
} from '../common/constants.js';
import { APIError, ConfigurationError } from '../common/errors.js';
import { log, logError } from '../common/utils.js';
import storageManager from './storage-manager.js';

export class STTService {
  constructor() {
    this.provider = null;
    this.apiKey = null;
  }

  /**
   * Initialize service with settings
   * @returns {Promise<void>}
   */
  async initialize() {
    const settings = await storageManager.getSettings();
    this.provider = settings.sttProvider || STT_PROVIDERS.OPENAI;

    // Get appropriate API key
    this.apiKey = await storageManager.getAPIKey(this.provider);

    if (!this.apiKey) {
      throw new ConfigurationError(ERROR_MESSAGES.NO_API_KEY);
    }

    log('STTService initialized with provider:', this.provider);
  }

  /**
   * Transcribe audio blob to text
   * @param {Blob} audioBlob - Audio data
   * @param {Object} options - Transcription options
   * @param {string} options.language - Language code (optional)
   * @returns {Promise<Object>} Transcription result with text and metadata
   * @throws {APIError} If transcription fails
   */
  async transcribe(audioBlob, options = {}) {
    if (!audioBlob || !(audioBlob instanceof Blob)) {
      throw new Error('Invalid audio blob');
    }

    // Ensure initialized
    if (!this.apiKey) {
      await this.initialize();
    }

    log(`Transcribing with ${this.provider}...`);

    try {
      let result;

      if (this.provider === STT_PROVIDERS.OPENAI) {
        result = await this.transcribeWithOpenAI(audioBlob, options);
      } else if (this.provider === STT_PROVIDERS.ELEVENLABS) {
        result = await this.transcribeWithElevenLabs(audioBlob, options);
      } else {
        throw new Error(`Unsupported provider: ${this.provider}`);
      }

      log('Transcription completed:', result.text.substring(0, 50) + '...');

      return {
        text: result.text,
        provider: this.provider,
        model: result.model || 'unknown',
        language: result.language
      };
    } catch (error) {
      logError('Transcription failed:', error);

      if (error instanceof APIError) {
        throw error;
      }

      throw new APIError(
        ERROR_MESSAGES.TRANSCRIPTION_FAILED,
        error.status || 500,
        this.provider
      );
    }
  }

  /**
   * Transcribe using OpenAI Whisper API
   * @private
   */
  async transcribeWithOpenAI(audioBlob, options = {}) {
    const formData = new FormData();

    // Convert blob to file (Whisper expects a file)
    const audioFile = new File([audioBlob], 'recording.webm', {
      type: audioBlob.type
    });

    formData.append('file', audioFile);
    formData.append('model', 'whisper-1');

    // Optional language parameter
    if (options.language) {
      formData.append('language', options.language);
    }

    // Optional response format
    formData.append('response_format', 'json');

    const response = await fetch(API_ENDPOINTS.OPENAI_TRANSCRIPTION, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: formData
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = errorData.error?.message || response.statusText;

      logError('OpenAI API error:', response.status, errorMessage);

      if (response.status === 401) {
        throw new APIError(ERROR_MESSAGES.INVALID_API_KEY, 401, 'openai');
      } else if (response.status === 429) {
        throw new APIError(ERROR_MESSAGES.RATE_LIMIT, 429, 'openai');
      } else if (response.status === 413) {
        throw new APIError('Audio file too large (max 25MB)', 413, 'openai');
      }

      throw new APIError(errorMessage, response.status, 'openai');
    }

    const data = await response.json();

    return {
      text: data.text,
      model: 'whisper-1',
      language: data.language
    };
  }

  /**
   * Transcribe using ElevenLabs API
   * @private
   */
  async transcribeWithElevenLabs(audioBlob, options = {}) {
    const formData = new FormData();
    formData.append('audio', audioBlob);

    // Optional model parameter
    if (options.model) {
      formData.append('model', options.model);
    }

    const response = await fetch(API_ENDPOINTS.ELEVENLABS_STT, {
      method: 'POST',
      headers: {
        'xi-api-key': this.apiKey
      },
      body: formData
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = errorData.detail || errorData.message || response.statusText;

      logError('ElevenLabs API error:', response.status, errorMessage);

      if (response.status === 401) {
        throw new APIError(ERROR_MESSAGES.INVALID_API_KEY, 401, 'elevenlabs');
      } else if (response.status === 429) {
        throw new APIError(ERROR_MESSAGES.RATE_LIMIT, 429, 'elevenlabs');
      }

      throw new APIError(errorMessage, response.status, 'elevenlabs');
    }

    const data = await response.json();

    return {
      text: data.text,
      model: data.model || 'elevenlabs-stt',
      language: data.language
    };
  }

  /**
   * Validate API key by making a test request
   * @param {string} provider - Provider name
   * @param {string} apiKey - API key to validate
   * @returns {Promise<boolean>} True if valid
   */
  async validateAPIKey(provider, apiKey) {
    // Create a very small silent audio blob for testing
    const silentBlob = await this.createSilentAudioBlob();

    const originalProvider = this.provider;
    const originalKey = this.apiKey;

    try {
      this.provider = provider;
      this.apiKey = apiKey;

      await this.transcribe(silentBlob);
      return true;
    } catch (error) {
      if (error instanceof APIError && error.status === 401) {
        return false;
      }
      // Other errors might indicate the key is valid but there's another issue
      return true;
    } finally {
      this.provider = originalProvider;
      this.apiKey = originalKey;
    }
  }

  /**
   * Create a small silent audio blob for testing
   * @private
   * @returns {Promise<Blob>} Silent audio blob
   */
  async createSilentAudioBlob() {
    // Create a 1-second silent audio blob
    const sampleRate = 44100;
    const duration = 1;
    const numChannels = 1;
    const numSamples = sampleRate * duration;

    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const audioBuffer = audioContext.createBuffer(numChannels, numSamples, sampleRate);

    // Create a silent buffer (all zeros)
    for (let channel = 0; channel < numChannels; channel++) {
      const channelData = audioBuffer.getChannelData(channel);
      for (let i = 0; i < numSamples; i++) {
        channelData[i] = 0;
      }
    }

    // Convert to blob (this is a simplified version, may not work for all APIs)
    // For production, you might want to use a proper audio encoding library
    const blob = new Blob([new Uint8Array(1024)], { type: 'audio/webm' });

    await audioContext.close();

    return blob;
  }

  /**
   * Set provider
   * @param {string} provider - Provider name
   */
  setProvider(provider) {
    if (!Object.values(STT_PROVIDERS).includes(provider)) {
      throw new Error(`Invalid provider: ${provider}`);
    }
    this.provider = provider;
  }

  /**
   * Get current provider
   * @returns {string} Current provider
   */
  getProvider() {
    return this.provider;
  }
}

// Export singleton instance
export default new STTService();

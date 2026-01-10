/**
 * @fileoverview Text-to-Speech service using ElevenLabs API
 * @module tts-service
 *
 * Provides pronunciation playback for vocabulary words using the ElevenLabs TTS API.
 * Uses Web Audio API for playback and implements in-memory caching.
 *
 * @example
 * import ttsService from './tts-service.js';
 * await ttsService.pronounce('eloquent');
 */

import storageManager from './storage-manager.js';
import { log, logError } from '../common/utils.js';
import { TTS_CONFIG } from '../common/constants.js';

/**
 * TTS Service class for pronunciation playback
 */
class TTSService {
  constructor() {
    /** @type {AudioContext|null} */
    this.audioContext = null;

    /** @type {AudioBufferSourceNode|null} */
    this.currentSource = null;

    /** @type {boolean} */
    this.isPlaying = false;

    /** @type {boolean} */
    this.isLoading = false;

    /** @type {Map<string, AudioBuffer>} - In-memory cache for audio buffers */
    this.cache = new Map();

    /** @type {number} - Maximum cache size */
    this.maxCacheSize = 100;
  }

  /**
   * Initialize or resume audio context
   * Must be called after user interaction due to browser autoplay policies
   * @private
   */
  initAudioContext() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }

    // Resume if suspended (browser autoplay policy)
    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume();
    }
  }

  /**
   * Pronounce a word using ElevenLabs TTS
   * @param {string} word - Word to pronounce
   * @returns {Promise<void>}
   * @throws {Error} If TTS fails
   */
  async pronounce(word) {
    if (!word || typeof word !== 'string') {
      throw new Error('Invalid word');
    }

    const normalizedWord = word.toLowerCase().trim();
    if (!normalizedWord) return;

    // Stop any current playback
    this.stop();

    this.isLoading = true;

    try {
      // Check cache first
      const cachedBuffer = this.cache.get(normalizedWord);
      if (cachedBuffer) {
        log(`TTS cache hit for: ${word}`);
        await this.playAudioBuffer(cachedBuffer);
        return;
      }

      // Get API key
      const apiKey = await storageManager.getAPIKey('elevenlabs');
      if (!apiKey) {
        throw new Error('ElevenLabs API key not configured. Please add it in Settings.');
      }

      // Synthesize audio
      const audioData = await this.synthesize(word, apiKey);

      // Initialize audio context (must be after user interaction)
      this.initAudioContext();

      // Decode audio data
      const audioBuffer = await this.audioContext.decodeAudioData(audioData);

      // Cache the buffer
      this.cacheBuffer(normalizedWord, audioBuffer);

      // Play the audio
      await this.playAudioBuffer(audioBuffer);

      log(`TTS played pronunciation for: ${word}`);
    } catch (error) {
      logError('TTS error:', error);
      throw error;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Call ElevenLabs TTS API
   * @param {string} text - Text to synthesize
   * @param {string} apiKey - ElevenLabs API key
   * @returns {Promise<ArrayBuffer>} Audio data
   * @private
   */
  async synthesize(text, apiKey) {
    const voiceId = TTS_CONFIG?.DEFAULT_VOICE_ID || '21m00Tcm4TlvDq8ikWAM';
    const modelId = TTS_CONFIG?.MODEL_ID || 'eleven_multilingual_v2';
    const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg'
      },
      body: JSON.stringify({
        text: text,
        model_id: modelId,
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          style: 0.0,
          use_speaker_boost: true
        }
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`ElevenLabs TTS API error: HTTP ${response.status} - ${errorText}`);
    }

    return await response.arrayBuffer();
  }

  /**
   * Play audio buffer using Web Audio API
   * @param {AudioBuffer} audioBuffer - Audio buffer to play
   * @returns {Promise<void>}
   * @private
   */
  async playAudioBuffer(audioBuffer) {
    return new Promise((resolve, reject) => {
      try {
        this.initAudioContext();

        // Create source node
        this.currentSource = this.audioContext.createBufferSource();
        this.currentSource.buffer = audioBuffer;
        this.currentSource.connect(this.audioContext.destination);

        this.isPlaying = true;

        // Handle playback end
        this.currentSource.onended = () => {
          this.isPlaying = false;
          this.currentSource = null;
          resolve();
        };

        // Start playback
        this.currentSource.start(0);
      } catch (error) {
        this.isPlaying = false;
        reject(error);
      }
    });
  }

  /**
   * Stop current audio playback
   */
  stop() {
    if (this.currentSource) {
      try {
        this.currentSource.stop();
      } catch (e) {
        // Ignore if already stopped
      }
      this.currentSource = null;
    }
    this.isPlaying = false;
  }

  /**
   * Cache an audio buffer
   * @param {string} word - Word key
   * @param {AudioBuffer} buffer - Audio buffer to cache
   * @private
   */
  cacheBuffer(word, buffer) {
    // Remove oldest entries if cache is full
    if (this.cache.size >= this.maxCacheSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }

    this.cache.set(word, buffer);
    log(`TTS cached audio for: ${word}`);
  }

  /**
   * Clear the audio cache
   */
  clearCache() {
    this.cache.clear();
    log('TTS audio cache cleared');
  }

  /**
   * Get cache size
   * @returns {number} Number of cached items
   */
  getCacheSize() {
    return this.cache.size;
  }

  /**
   * Check if API key is configured
   * @returns {Promise<boolean>}
   */
  async isConfigured() {
    const apiKey = await storageManager.getAPIKey('elevenlabs');
    return !!apiKey;
  }
}

// Export singleton instance
export default new TTSService();

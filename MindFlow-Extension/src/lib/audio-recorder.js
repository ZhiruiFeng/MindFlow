/**
 * @fileoverview Audio recording service using MediaRecorder API
 * @module audio-recorder
 *
 * Handles audio capture from the user's microphone and provides
 * audio level monitoring for visual feedback.
 *
 * @example
 * const recorder = new AudioRecorder();
 * await recorder.startRecording();
 * const audioBlob = await recorder.stopRecording();
 */

import { AUDIO_CONFIG, VALIDATION, ERROR_MESSAGES } from '../common/constants.js';
import { RecordingError } from '../common/errors.js';
import { log, logError } from '../common/utils.js';

export class AudioRecorder {
  constructor() {
    this.startTime = null;
    this.isPaused = false;
    this.isRecording = false;
    this.useOffscreen = true; // Use offscreen document for recording
  }

  /**
   * Check if browser supports audio recording
   * @returns {boolean} True if supported
   */
  static isSupported() {
    return !!(navigator.mediaDevices &&
              navigator.mediaDevices.getUserMedia &&
              window.MediaRecorder);
  }

  /**
   * Start recording audio
   * @returns {Promise<void>}
   * @throws {RecordingError} If recording cannot start
   */
  async startRecording() {
    if (!AudioRecorder.isSupported()) {
      throw new RecordingError('Audio recording is not supported in this browser');
    }

    try {
      // Send message to service worker which will route to offscreen document
      const response = await chrome.runtime.sendMessage({
        type: 'START_RECORDING'
      });

      if (!response || !response.success) {
        // Check if it's a permission error
        if (response?.errorName === 'NotAllowedError' ||
            response?.error?.includes('denied') ||
            response?.error?.includes('Permission')) {
          throw new RecordingError(ERROR_MESSAGES.NO_MICROPHONE);
        }
        throw new RecordingError(response?.error || 'Failed to start recording');
      }

      this.startTime = Date.now();
      this.isPaused = false;
      this.isRecording = true;

      log('Recording started');
    } catch (error) {
      await this.cleanup();

      if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
        throw new RecordingError(ERROR_MESSAGES.NO_MICROPHONE);
      }

      logError('Start recording error:', error);

      // Re-throw if already a RecordingError
      if (error instanceof RecordingError) {
        throw error;
      }

      throw new RecordingError('Failed to start recording: ' + error.message);
    }
  }

  /**
   * Get supported MIME type for this browser
   * @returns {string} Supported MIME type
   */
  getSupportedMimeType() {
    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4'
    ];

    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    // Fallback to default
    return '';
  }

  /**
   * Pause recording
   * @throws {RecordingError} If not recording
   */
  async pauseRecording() {
    if (!this.isRecording || this.isPaused) {
      throw new RecordingError('Cannot pause - not recording');
    }

    const response = await chrome.runtime.sendMessage({
      type: 'PAUSE_RECORDING'
    });

    if (response && response.success) {
      this.isPaused = true;
      log('Recording paused');
    }
  }

  /**
   * Resume recording
   * @throws {RecordingError} If not paused
   */
  async resumeRecording() {
    if (!this.isRecording || !this.isPaused) {
      throw new RecordingError('Cannot resume - not paused');
    }

    const response = await chrome.runtime.sendMessage({
      type: 'RESUME_RECORDING'
    });

    if (response && response.success) {
      this.isPaused = false;
      log('Recording resumed');
    }
  }

  /**
   * Stop recording and return audio blob
   * @returns {Promise<Blob>} Audio blob
   * @throws {RecordingError} If not recording or recording too short
   */
  async stopRecording() {
    if (!this.isRecording) {
      throw new RecordingError('Cannot stop - not recording');
    }

    // Check minimum duration
    const duration = Date.now() - this.startTime;
    if (duration < VALIDATION.MIN_RECORDING_DURATION) {
      await this.cleanup();
      throw new RecordingError(ERROR_MESSAGES.RECORDING_TOO_SHORT);
    }

    // Check maximum duration
    if (duration > VALIDATION.MAX_RECORDING_DURATION) {
      await this.cleanup();
      throw new RecordingError(ERROR_MESSAGES.RECORDING_TOO_LONG);
    }

    try {
      // Request audio blob from offscreen document
      const response = await chrome.runtime.sendMessage({
        type: 'STOP_RECORDING'
      });

      if (!response || !response.success) {
        throw new RecordingError(response?.error || 'Failed to stop recording');
      }

      // Convert base64 back to blob
      const audioBlob = await this.dataURLToBlob(response.audioData);

      log('Recording stopped, blob size:', audioBlob.size);

      // Cleanup
      await this.cleanup();

      return audioBlob;
    } catch (error) {
      logError('Stop recording error:', error);
      await this.cleanup();
      throw new RecordingError('Failed to stop recording: ' + error.message);
    }
  }

  /**
   * Convert data URL to Blob
   */
  async dataURLToBlob(dataURL) {
    const response = await fetch(dataURL);
    return await response.blob();
  }

  /**
   * Cancel recording without returning audio
   */
  async cancelRecording() {
    if (this.isRecording) {
      await chrome.runtime.sendMessage({
        type: 'CANCEL_RECORDING'
      });
    }
    await this.cleanup();
    log('Recording cancelled');
  }

  /**
   * Get current audio level (0.0 - 1.0)
   * Used for waveform visualization
   * @returns {number} Audio level
   */
  async getAudioLevel() {
    if (!this.isRecording || this.isPaused) {
      return 0;
    }

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'GET_AUDIO_LEVEL'
      });

      if (response && response.success) {
        return response.level;
      }
    } catch (error) {
      // Ignore errors for audio level
    }

    return 0;
  }

  /**
   * Get recording duration in seconds
   * @returns {number} Duration in seconds
   */
  getDuration() {
    if (!this.startTime) {
      return 0;
    }
    return (Date.now() - this.startTime) / 1000;
  }

  /**
   * Check if currently recording
   * @returns {boolean} True if recording
   */
  isRecordingState() {
    return this.isRecording && !this.isPaused;
  }

  /**
   * Check if currently paused
   * @returns {boolean} True if paused
   */
  isPausedState() {
    return this.isPaused;
  }

  /**
   * Clean up resources
   */
  async cleanup() {
    this.isRecording = false;
    this.startTime = null;
    this.isPaused = false;

    log('AudioRecorder cleaned up');
  }

  /**
   * Get recording state
   * @returns {string} Current state ('inactive', 'recording', 'paused')
   */
  getState() {
    if (!this.isRecording) {
      return 'inactive';
    }
    if (this.isPaused) {
      return 'paused';
    }
    return 'recording';
  }
}

// Export singleton instance
export default new AudioRecorder();

/**
 * @fileoverview Popup UI controller with state management
 * @module popup
 *
 * Manages the popup interface, handling user interactions and coordinating
 * between audio recording, transcription, and text optimization services.
 */

import { RECORDING_STATES, MESSAGE_TYPES } from '../common/constants.js';
import { log, logError, formatDuration, getUserErrorMessage, copyToClipboard } from '../common/utils.js';
import audioRecorder from '../lib/audio-recorder.js';
import sttService from '../lib/stt-service.js';
import llmService from '../lib/llm-service.js';
import storageManager from '../lib/storage-manager.js';

class PopupController {
  constructor() {
    this.state = RECORDING_STATES.IDLE;
    this.duration = 0;
    this.timerInterval = null;
    this.waveformInterval = null;
    this.currentResult = null;

    // DOM elements (will be initialized after DOM loads)
    this.elements = {};
  }

  /**
   * Initialize the popup
   */
  async init() {
    log('Initializing popup...');

    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setup());
    } else {
      this.setup();
    }
  }

  /**
   * Setup after DOM is ready
   */
  async setup() {
    // Cache DOM elements
    this.cacheElements();

    // Attach event listeners
    this.attachEventListeners();

    // Check for API configuration
    await this.checkConfiguration();

    // Initialize services
    try {
      await sttService.initialize();
      await llmService.initialize();
      log('Services initialized');
    } catch (error) {
      logError('Service initialization error:', error);
      // Continue anyway, will show error when user tries to use it
    }

    // Set initial state
    this.setState(RECORDING_STATES.IDLE);

    log('Popup ready');
  }

  /**
   * Cache DOM elements
   */
  cacheElements() {
    this.elements = {
      // Views
      recordingView: document.getElementById('recording-view'),
      resultView: document.getElementById('result-view'),
      errorView: document.getElementById('error-view'),

      // Recording view elements
      statusIndicator: document.getElementById('status-indicator'),
      statusText: document.getElementById('status-text'),
      timer: document.getElementById('timer'),
      waveform: document.getElementById('waveform'),
      startBtn: document.getElementById('start-btn'),
      pauseBtn: document.getElementById('pause-btn'),
      stopBtn: document.getElementById('stop-btn'),
      processingIndicator: document.getElementById('processing-indicator'),
      processingText: document.getElementById('processing-text'),

      // Result view elements
      originalText: document.getElementById('original-text'),
      optimizedText: document.getElementById('optimized-text'),
      optimizationLevel: document.getElementById('optimization-level'),
      copyBtn: document.getElementById('copy-btn'),
      reoptimizeBtn: document.getElementById('reoptimize-btn'),
      insertBtn: document.getElementById('insert-btn'),
      newRecordingBtn: document.getElementById('new-recording-btn'),

      // Error view elements
      errorMessage: document.getElementById('error-message'),
      retryBtn: document.getElementById('retry-btn'),

      // Settings
      settingsBtn: document.getElementById('settings-btn'),

      // Toast
      toast: document.getElementById('toast'),
      toastMessage: document.getElementById('toast-message')
    };
  }

  /**
   * Attach event listeners
   */
  attachEventListeners() {
    // Recording controls
    this.elements.startBtn.addEventListener('click', () => this.handleStart());
    this.elements.pauseBtn.addEventListener('click', () => this.handlePause());
    this.elements.stopBtn.addEventListener('click', () => this.handleStop());

    // Result actions
    this.elements.copyBtn.addEventListener('click', () => this.handleCopy());
    this.elements.reoptimizeBtn.addEventListener('click', () => this.handleReoptimize());
    this.elements.insertBtn.addEventListener('click', () => this.handleInsert());
    this.elements.newRecordingBtn.addEventListener('click', () => this.handleNewRecording());

    // Error retry
    this.elements.retryBtn.addEventListener('click', () => this.handleNewRecording());

    // Settings
    this.elements.settingsBtn.addEventListener('click', () => this.handleSettings());

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if (this.state === RECORDING_STATES.RECORDING) {
          this.handleStop();
        }
      }
    });

    // Listen for messages from background script
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      if (request.type === 'TOGGLE_RECORDING') {
        if (this.state === RECORDING_STATES.IDLE) {
          this.handleStart();
        } else if (this.state === RECORDING_STATES.RECORDING) {
          this.handleStop();
        }
      }
    });
  }

  /**
   * Check if API keys are configured
   */
  async checkConfiguration() {
    const openaiKey = await storageManager.getAPIKey('openai');

    if (!openaiKey) {
      this.showToast('⚠️ Please configure your API key in settings', 5000);
    }
  }

  /**
   * Handle start recording
   */
  async handleStart() {
    log('Start recording');

    try {
      // Check API key
      const apiKey = await storageManager.getAPIKey('openai');
      if (!apiKey) {
        this.showError('Please configure your OpenAI API key in settings first.');
        return;
      }

      // Start recording
      await audioRecorder.startRecording();

      // Update state
      this.setState(RECORDING_STATES.RECORDING);

      // Start timer
      this.startTimer();

      // Start waveform animation
      this.startWaveform();

    } catch (error) {
      logError('Start recording error:', error);
      this.showError(getUserErrorMessage(error));
    }
  }

  /**
   * Handle pause/resume recording
   */
  handlePause() {
    try {
      if (audioRecorder.isPausedState()) {
        audioRecorder.resumeRecording();
        this.elements.pauseBtn.innerHTML = '<span class="btn-icon">⏸</span> Pause';
        this.elements.statusText.textContent = 'Recording...';
        this.startWaveform();
      } else {
        audioRecorder.pauseRecording();
        this.elements.pauseBtn.innerHTML = '<span class="btn-icon">▶️</span> Resume';
        this.elements.statusText.textContent = 'Paused';
        this.stopWaveform();
      }
    } catch (error) {
      logError('Pause/resume error:', error);
      this.showError(getUserErrorMessage(error));
    }
  }

  /**
   * Handle stop recording
   */
  async handleStop() {
    log('Stop recording');

    try {
      // Stop timer and waveform
      this.stopTimer();
      this.stopWaveform();

      // Update state
      this.setState(RECORDING_STATES.PROCESSING);

      // Stop recording and get audio blob
      const audioBlob = await audioRecorder.stopRecording();

      log('Audio blob size:', audioBlob.size);

      // Transcribe
      await this.transcribe(audioBlob);

    } catch (error) {
      logError('Stop recording error:', error);
      this.showError(getUserErrorMessage(error));
    }
  }

  /**
   * Transcribe audio
   */
  async transcribe(audioBlob) {
    this.setState(RECORDING_STATES.TRANSCRIBING);

    try {
      const result = await sttService.transcribe(audioBlob);

      log('Transcription:', result.text);

      // Store original text
      this.currentResult = {
        original: result.text,
        provider: result.provider,
        model: result.model
      };

      // Optimize
      await this.optimize(result.text);

    } catch (error) {
      logError('Transcription error:', error);
      this.showError(getUserErrorMessage(error));
    }
  }

  /**
   * Optimize text
   */
  async optimize(text) {
    this.setState(RECORDING_STATES.OPTIMIZING);

    try {
      const optimized = await llmService.optimizeText(text);

      log('Optimization complete');

      // Store optimized text
      this.currentResult.optimized = optimized;

      // Get settings for display
      const settings = await storageManager.getSettings();
      this.currentResult.level = settings.optimizationLevel;

      // Show results
      this.showResults();

      // Save to history if enabled
      if (settings.keepHistory) {
        await storageManager.saveHistoryEntry({
          original: this.currentResult.original,
          optimized: this.currentResult.optimized,
          level: this.currentResult.level
        });
      }

    } catch (error) {
      logError('Optimization error:', error);

      // Still show result with original text
      this.currentResult.optimized = this.currentResult.original;
      this.currentResult.level = 'none';

      this.showResults();

      this.showToast('⚠️ Optimization failed, showing original text', 5000);
    }
  }

  /**
   * Show results view
   */
  showResults() {
    this.setState(RECORDING_STATES.COMPLETED);

    // Populate text boxes
    this.elements.originalText.textContent = this.currentResult.original;
    this.elements.optimizedText.textContent = this.currentResult.optimized;

    // Show optimization level
    const levelText = this.currentResult.level.charAt(0).toUpperCase() +
                      this.currentResult.level.slice(1);
    this.elements.optimizationLevel.textContent = levelText;

    // Auto-insert if enabled
    storageManager.getSettings().then(settings => {
      if (settings.autoInsert) {
        setTimeout(() => this.handleInsert(), 500);
      }
    });
  }

  /**
   * Handle copy to clipboard
   */
  async handleCopy() {
    const text = this.currentResult.optimized || this.currentResult.original;

    const success = await copyToClipboard(text);

    if (success) {
      this.showToast('✓ Copied to clipboard');
    } else {
      this.showToast('⚠️ Failed to copy');
    }
  }

  /**
   * Handle re-optimize
   */
  async handleReoptimize() {
    if (!this.currentResult || !this.currentResult.original) {
      return;
    }

    this.setState(RECORDING_STATES.OPTIMIZING);

    await this.optimize(this.currentResult.original);
  }

  /**
   * Handle insert text
   */
  async handleInsert() {
    const text = this.currentResult.optimized || this.currentResult.original;

    try {
      // Send message to background script to insert text
      const response = await chrome.runtime.sendMessage({
        type: MESSAGE_TYPES.INSERT_TEXT,
        text: text
      });

      if (response && response.success) {
        this.showToast('✓ Text inserted');

        // Close popup after short delay
        setTimeout(() => window.close(), 800);
      } else {
        throw new Error(response?.error || 'Failed to insert text');
      }
    } catch (error) {
      logError('Insert text error:', error);
      this.showToast('⚠️ Failed to insert. Try copying instead.');
    }
  }

  /**
   * Handle new recording
   */
  handleNewRecording() {
    this.currentResult = null;
    this.duration = 0;
    this.elements.timer.textContent = '00:00';
    this.setState(RECORDING_STATES.IDLE);
  }

  /**
   * Handle settings
   */
  handleSettings() {
    chrome.runtime.openOptionsPage();
  }

  /**
   * Show error
   */
  showError(message) {
    this.setState(RECORDING_STATES.ERROR);
    this.elements.errorMessage.textContent = message;
  }

  /**
   * Show toast notification
   */
  showToast(message, duration = 3000) {
    this.elements.toastMessage.textContent = message;
    this.elements.toast.style.display = 'block';

    setTimeout(() => {
      this.elements.toast.style.display = 'none';
    }, duration);
  }

  /**
   * Set state and update UI
   */
  setState(newState) {
    this.state = newState;

    // Hide all views
    this.elements.recordingView.classList.remove('active');
    this.elements.recordingView.style.display = 'none';
    this.elements.resultView.classList.remove('active');
    this.elements.resultView.style.display = 'none';
    this.elements.errorView.classList.remove('active');
    this.elements.errorView.style.display = 'none';

    // Update UI based on state
    switch (newState) {
      case RECORDING_STATES.IDLE:
        this.elements.recordingView.classList.add('active');
        this.elements.recordingView.style.display = 'block';
        this.elements.statusText.textContent = 'Ready to record';
        this.elements.statusIndicator.classList.remove('recording');
        this.elements.startBtn.style.display = 'flex';
        this.elements.pauseBtn.style.display = 'none';
        this.elements.stopBtn.style.display = 'none';
        this.elements.processingIndicator.style.display = 'none';
        break;

      case RECORDING_STATES.RECORDING:
        this.elements.recordingView.classList.add('active');
        this.elements.recordingView.style.display = 'block';
        this.elements.statusText.textContent = 'Recording...';
        this.elements.statusIndicator.classList.add('recording');
        this.elements.startBtn.style.display = 'none';
        this.elements.pauseBtn.style.display = 'flex';
        this.elements.stopBtn.style.display = 'flex';
        this.elements.processingIndicator.style.display = 'none';
        break;

      case RECORDING_STATES.PROCESSING:
        this.elements.recordingView.classList.add('active');
        this.elements.recordingView.style.display = 'block';
        this.elements.statusIndicator.classList.remove('recording');
        this.elements.startBtn.style.display = 'none';
        this.elements.pauseBtn.style.display = 'none';
        this.elements.stopBtn.style.display = 'none';
        this.elements.processingIndicator.style.display = 'block';
        this.elements.processingText.textContent = 'Processing...';
        break;

      case RECORDING_STATES.TRANSCRIBING:
        this.elements.processingText.textContent = 'Transcribing...';
        break;

      case RECORDING_STATES.OPTIMIZING:
        this.elements.processingText.textContent = 'Optimizing...';
        break;

      case RECORDING_STATES.COMPLETED:
        this.elements.resultView.classList.add('active');
        this.elements.resultView.style.display = 'block';
        break;

      case RECORDING_STATES.ERROR:
        this.elements.errorView.classList.add('active');
        this.elements.errorView.style.display = 'block';
        break;
    }
  }

  /**
   * Start timer
   */
  startTimer() {
    this.duration = 0;
    this.timerInterval = setInterval(() => {
      this.duration += 0.1;
      this.elements.timer.textContent = formatDuration(this.duration);
    }, 100);
  }

  /**
   * Stop timer
   */
  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
  }

  /**
   * Start waveform animation
   */
  startWaveform() {
    this.elements.waveform.classList.add('active');

    // Update waveform bars based on audio level
    this.waveformInterval = setInterval(async () => {
      const level = await audioRecorder.getAudioLevel();
      const bars = this.elements.waveform.querySelectorAll('.wave-bar');

      bars.forEach((bar, index) => {
        const height = 20 + (level * 40) + (Math.random() * 10);
        bar.style.height = `${height}px`;
      });
    }, 100);
  }

  /**
   * Stop waveform animation
   */
  stopWaveform() {
    this.elements.waveform.classList.remove('active');

    if (this.waveformInterval) {
      clearInterval(this.waveformInterval);
      this.waveformInterval = null;
    }

    // Reset bars
    const bars = this.elements.waveform.querySelectorAll('.wave-bar');
    bars.forEach(bar => {
      bar.style.height = '20px';
    });
  }
}

// Initialize popup when loaded
const popup = new PopupController();
popup.init();

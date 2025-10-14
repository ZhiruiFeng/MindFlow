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
import supabaseAuth from '../lib/supabase-auth.js';
import zmemoryAPI from '../lib/zmemory-api.js';

class PopupController {
  constructor() {
    this.state = RECORDING_STATES.IDLE;
    this.duration = 0;
    this.timerInterval = null;
    this.waveformInterval = null;
    this.currentResult = null;
    this.hasActiveField = false; // Track if user clicked in a text field
    this.recordingStartTime = null; // Track recording start time for duration

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

    // Check if user has an active text field
    await this.checkActiveField();

    // Check for API configuration
    await this.checkConfiguration();

    // Initialize services
    try {
      await sttService.initialize();
      await llmService.initialize();
      await supabaseAuth.initialize();
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
      teacherNotesSection: document.getElementById('teacher-notes-section'),
      teacherNotes: document.getElementById('teacher-notes'),
      optimizationLevel: document.getElementById('optimization-level'),
      copyBtn: document.getElementById('copy-btn'),
      reoptimizeBtn: document.getElementById('reoptimize-btn'),
      insertBtn: document.getElementById('insert-btn'),
      newRecordingBtn: document.getElementById('new-recording-btn'),

      // Error view elements
      errorMessage: document.getElementById('error-message'),
      retryBtn: document.getElementById('retry-btn'),

      // Header buttons
      historyBtn: document.getElementById('history-btn'),
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

    // Header buttons
    this.elements.historyBtn.addEventListener('click', () => this.handleHistory());
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
   * Check if there's an active editable field in the current tab
   */
  async checkActiveField() {
    try {
      // Get active tab
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

      if (!tab) {
        this.hasActiveField = false;
        return;
      }

      // Skip if restricted page
      if (tab.url && (tab.url.startsWith('chrome://') ||
                       tab.url.startsWith('chrome-extension://') ||
                       tab.url.startsWith('edge://') ||
                       tab.url.startsWith('about:'))) {
        this.hasActiveField = false;
        return;
      }

      // Inject content script if needed
      try {
        await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ['src/content/content-script.js']
        });
        await new Promise(resolve => setTimeout(resolve, 50));
      } catch (error) {
        // Content script might already be injected
        log('Content script injection skipped:', error.message);
      }

      // Check for active editable field
      const response = await chrome.tabs.sendMessage(tab.id, {
        type: 'GET_ACTIVE_ELEMENT_INFO'
      });

      this.hasActiveField = response && response.isEditable;
      log('Active editable field detected:', this.hasActiveField);
    } catch (error) {
      logError('Failed to check active field:', error);
      this.hasActiveField = false;
    }
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

      // Track recording start time
      this.recordingStartTime = Date.now();

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

      // Calculate audio duration
      const audioDuration = this.recordingStartTime
        ? (Date.now() - this.recordingStartTime) / 1000
        : null;

      // Store original text
      this.currentResult = {
        original: result.text,
        provider: result.provider,
        model: result.model,
        audioDuration: audioDuration
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
      const result = await llmService.optimizeText(text);

      log('Optimization complete');

      // Get settings for display
      const settings = await storageManager.getSettings();
      this.currentResult.level = settings.optimizationLevel;

      // Handle result based on whether it includes teacher notes
      if (typeof result === 'object' && result.refinedText) {
        // Teacher notes included
        this.currentResult.optimized = result.refinedText;
        this.currentResult.teacherNotes = result.teacherNotes;
      } else {
        // Simple text result
        this.currentResult.optimized = result;
        this.currentResult.teacherNotes = null;
      }

      // Show results
      this.showResults();

      // Save to history if enabled
      if (settings.keepHistory) {
        await storageManager.saveHistoryEntry({
          original: this.currentResult.original,
          optimized: this.currentResult.optimized,
          teacherNotes: this.currentResult.teacherNotes,
          level: this.currentResult.level
        });
      }

      // Sync to ZephyrOS backend if authenticated
      await this.syncToBackend();

    } catch (error) {
      logError('Optimization error:', error);

      // Still show result with original text
      this.currentResult.optimized = this.currentResult.original;
      this.currentResult.level = 'none';
      this.currentResult.teacherNotes = null;

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

    // Show/hide teacher notes section
    if (this.currentResult.teacherNotes) {
      this.elements.teacherNotes.textContent = this.currentResult.teacherNotes;
      this.elements.teacherNotesSection.style.display = 'block';
    } else {
      this.elements.teacherNotesSection.style.display = 'none';
    }

    // Show optimization level
    const levelText = this.currentResult.level.charAt(0).toUpperCase() +
                      this.currentResult.level.slice(1);
    this.elements.optimizationLevel.textContent = levelText;

    // Adjust UI based on active field context
    this.adjustResultUI();

    // Auto-insert if enabled AND there's an active field
    storageManager.getSettings().then(settings => {
      if (settings.autoInsert && this.hasActiveField) {
        setTimeout(() => this.handleInsert(), 500);
      }
    });
  }

  /**
   * Adjust result UI based on whether there's an active field
   */
  adjustResultUI() {
    if (!this.hasActiveField) {
      // Journey A: No active field - hide/disable Insert button
      this.elements.insertBtn.style.display = 'none';

      // Make Copy button more prominent
      this.elements.copyBtn.style.order = '-1'; // Move to first position
    } else {
      // Journey B: Active field detected - show Insert button
      this.elements.insertBtn.style.display = 'flex';

      // Keep normal order
      this.elements.copyBtn.style.order = '';
    }
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

      // Show user-friendly error message
      const errorMsg = error.message || 'Failed to insert text';
      if (errorMsg.includes('Cannot insert text on this page')) {
        this.showToast('⚠️ Cannot insert on this page. Text copied to clipboard instead.', 4000);
        // Automatically copy to clipboard as fallback
        await this.handleCopy();
      } else if (errorMsg.includes('click in a text field')) {
        this.showToast('⚠️ Please click in a text field first', 3000);
      } else {
        this.showToast('⚠️ Failed to insert. Use Copy button instead.', 3000);
      }
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
   * Handle history
   */
  handleHistory() {
    chrome.tabs.create({
      url: chrome.runtime.getURL('src/history/history.html')
    });
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
        this.elements.processingText.textContent = 'Processing';
        break;

      case RECORDING_STATES.TRANSCRIBING:
        this.elements.recordingView.classList.add('active');
        this.elements.recordingView.style.display = 'block';
        this.elements.statusIndicator.classList.remove('recording');
        this.elements.startBtn.style.display = 'none';
        this.elements.pauseBtn.style.display = 'none';
        this.elements.stopBtn.style.display = 'none';
        this.elements.processingIndicator.style.display = 'block';
        this.elements.processingText.textContent = 'Transcribing audio';
        break;

      case RECORDING_STATES.OPTIMIZING:
        this.elements.recordingView.classList.add('active');
        this.elements.recordingView.style.display = 'block';
        this.elements.statusIndicator.classList.remove('recording');
        this.elements.startBtn.style.display = 'none';
        this.elements.pauseBtn.style.display = 'none';
        this.elements.stopBtn.style.display = 'none';
        this.elements.processingIndicator.style.display = 'block';
        this.elements.processingText.textContent = 'Refining text';
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
    // CSS animation handles the visual effect, no need for interval polling
  }

  /**
   * Stop waveform animation
   */
  stopWaveform() {
    this.elements.waveform.classList.remove('active');
    // CSS animation stops when 'active' class is removed
  }

  /**
   * Sync interaction to ZephyrOS backend
   */
  async syncToBackend() {
    log('🔄 syncToBackend called');

    // Only sync if user is authenticated
    if (!zmemoryAPI.isAuthenticated()) {
      log('⚠️ Not authenticated, skipping backend sync');
      return;
    }

    if (!this.currentResult) {
      log('⚠️ No current result, skipping backend sync');
      return;
    }

    try {
      log('📤 Syncing interaction to ZephyrOS backend...');

      const settings = await storageManager.getSettings();

      // Map provider names to backend format (OpenAI or ElevenLabs - capitalized)
      const transcriptionApi = this.currentResult.provider === 'elevenlabs' ? 'ElevenLabs' : 'OpenAI';

      // Map output style: 'casual' -> 'conversational', 'formal' -> 'formal'
      const outputStyle = settings.outputStyle === 'casual' ? 'conversational' : 'formal';

      const interaction = {
        transcriptionApi: transcriptionApi,
        transcriptionModel: this.currentResult.model || 'whisper-1',
        optimizationModel: settings.llmModel || 'gpt-4o-mini',
        optimizationLevel: this.currentResult.level || settings.optimizationLevel,
        outputStyle: outputStyle,
        originalText: this.currentResult.original,
        optimizedText: this.currentResult.optimized,
        teacherNotes: this.currentResult.teacherNotes || null,
        audioDurationSeconds: this.currentResult.audioDuration || null
      };

      log('📦 Interaction object to sync:', interaction);

      const result = await zmemoryAPI.createInteraction(interaction);

      log('✅ Interaction synced successfully:', result.id);
      this.showToast('✓ Synced to ZephyrOS', 2000);
    } catch (error) {
      logError('❌ Backend sync error:', error);
      logError('Error message:', error.message);
      logError('Error stack:', error.stack);
      // Don't show error to user, sync is optional
      log('Failed to sync to backend, continuing...');
    }
  }
}

// Initialize popup when loaded
const popup = new PopupController();
popup.init();

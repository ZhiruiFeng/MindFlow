/**
 * @fileoverview Settings page controller
 * @module settings
 */

import { log, logError } from '../common/utils.js';
import storageManager from '../lib/storage-manager.js';
import sttService from '../lib/stt-service.js';
import llmService from '../lib/llm-service.js';

class SettingsController {
  constructor() {
    this.elements = {};
  }

  /**
   * Initialize settings page
   */
  async init() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setup());
    } else {
      this.setup();
    }
  }

  /**
   * Setup after DOM ready
   */
  async setup() {
    this.cacheElements();
    this.attachEventListeners();
    await this.loadSettings();
    await this.updateStorageInfo();

    // Set version
    const manifest = chrome.runtime.getManifest();
    this.elements.version.textContent = manifest.version;

    log('Settings page ready');
  }

  /**
   * Cache DOM elements
   */
  cacheElements() {
    this.elements = {
      // API Keys
      openaiApiKey: document.getElementById('openai-api-key'),
      openaiToggle: document.getElementById('openai-toggle'),
      openaiStatus: document.getElementById('openai-status'),
      openaiTest: document.getElementById('openai-test'),

      elevenlabsApiKey: document.getElementById('elevenlabs-api-key'),
      elevenlabsToggle: document.getElementById('elevenlabs-toggle'),
      elevenlabsStatus: document.getElementById('elevenlabs-status'),
      elevenlabsTest: document.getElementById('elevenlabs-test'),

      // STT Provider
      sttProvider: document.querySelectorAll('input[name="stt-provider"]'),

      // LLM Settings
      llmModel: document.getElementById('llm-model'),
      optimizationLevel: document.querySelectorAll('input[name="optimization-level"]'),
      outputStyle: document.querySelectorAll('input[name="output-style"]'),

      // Behavior
      autoInsert: document.getElementById('auto-insert'),
      showNotifications: document.getElementById('show-notifications'),
      keepHistory: document.getElementById('keep-history'),
      showTeacherNotes: document.getElementById('show-teacher-notes'),

      // Actions
      saveBtn: document.getElementById('save-btn'),
      resetBtn: document.getElementById('reset-btn'),
      clearHistoryBtn: document.getElementById('clear-history-btn'),

      // Storage
      syncUsage: document.getElementById('sync-usage'),
      localUsage: document.getElementById('local-usage'),

      // Other
      closeBtn: document.getElementById('close-btn'),
      version: document.getElementById('version'),

      // Toast
      toast: document.getElementById('toast'),
      toastMessage: document.getElementById('toast-message')
    };
  }

  /**
   * Attach event listeners
   */
  attachEventListeners() {
    // API Key toggles
    this.elements.openaiToggle.addEventListener('click', () =>
      this.togglePasswordVisibility(this.elements.openaiApiKey)
    );
    this.elements.elevenlabsToggle.addEventListener('click', () =>
      this.togglePasswordVisibility(this.elements.elevenlabsApiKey)
    );

    // Test buttons
    this.elements.openaiTest.addEventListener('click', () =>
      this.testAPIKey('openai')
    );
    this.elements.elevenlabsTest.addEventListener('click', () =>
      this.testAPIKey('elevenlabs')
    );

    // Save button
    this.elements.saveBtn.addEventListener('click', () => this.saveSettings());

    // Reset button
    this.elements.resetBtn.addEventListener('click', () => this.resetSettings());

    // Clear history button
    this.elements.clearHistoryBtn.addEventListener('click', () => this.clearHistory());

    // Close button
    this.elements.closeBtn.addEventListener('click', () => window.close());

    // Auto-save on input (debounced)
    let saveTimeout;
    const autoSave = () => {
      clearTimeout(saveTimeout);
      saveTimeout = setTimeout(() => this.saveSettings(true), 1000);
    };

    this.elements.llmModel.addEventListener('change', autoSave);
    this.elements.sttProvider.forEach(radio => {
      radio.addEventListener('change', autoSave);
    });
    this.elements.optimizationLevel.forEach(radio => {
      radio.addEventListener('change', autoSave);
    });
    this.elements.outputStyle.forEach(radio => {
      radio.addEventListener('change', autoSave);
    });
    this.elements.autoInsert.addEventListener('change', autoSave);
    this.elements.showNotifications.addEventListener('change', autoSave);
    this.elements.keepHistory.addEventListener('change', autoSave);
    this.elements.showTeacherNotes.addEventListener('change', autoSave);
  }

  /**
   * Load settings from storage
   */
  async loadSettings() {
    try {
      // Load API keys
      const openaiKey = await storageManager.getAPIKey('openai');
      const elevenlabsKey = await storageManager.getAPIKey('elevenlabs');

      if (openaiKey) {
        this.elements.openaiApiKey.value = openaiKey;
        this.updateStatus('openai', 'valid');
      }

      if (elevenlabsKey) {
        this.elements.elevenlabsApiKey.value = elevenlabsKey;
        this.updateStatus('elevenlabs', 'valid');
      }

      // Load settings
      const settings = await storageManager.getSettings();

      // STT Provider
      this.elements.sttProvider.forEach(radio => {
        radio.checked = radio.value === settings.sttProvider;
      });

      // LLM Model
      this.elements.llmModel.value = settings.llmModel;

      // Optimization Level
      this.elements.optimizationLevel.forEach(radio => {
        radio.checked = radio.value === settings.optimizationLevel;
      });

      // Output Style
      this.elements.outputStyle.forEach(radio => {
        radio.checked = radio.value === settings.outputStyle;
      });

      // Behavior
      this.elements.autoInsert.checked = settings.autoInsert;
      this.elements.showNotifications.checked = settings.showNotifications;
      this.elements.keepHistory.checked = settings.keepHistory;
      this.elements.showTeacherNotes.checked = settings.showTeacherNotes;

      log('Settings loaded');
    } catch (error) {
      logError('Load settings error:', error);
      this.showToast('⚠️ Failed to load settings');
    }
  }

  /**
   * Save settings to storage
   */
  async saveSettings(silent = false) {
    try {
      this.elements.saveBtn.disabled = true;
      this.elements.saveBtn.textContent = 'Saving...';

      // Save API keys
      const openaiKey = this.elements.openaiApiKey.value.trim();
      const elevenlabsKey = this.elements.elevenlabsApiKey.value.trim();

      if (openaiKey) {
        await storageManager.saveAPIKey('openai', openaiKey);
      }

      if (elevenlabsKey) {
        await storageManager.saveAPIKey('elevenlabs', elevenlabsKey);
      }

      // Get selected values
      const sttProvider = Array.from(this.elements.sttProvider)
        .find(radio => radio.checked)?.value;

      const optimizationLevel = Array.from(this.elements.optimizationLevel)
        .find(radio => radio.checked)?.value;

      const outputStyle = Array.from(this.elements.outputStyle)
        .find(radio => radio.checked)?.value;

      // Save settings
      const settings = {
        sttProvider,
        llmModel: this.elements.llmModel.value,
        optimizationLevel,
        outputStyle,
        showTeacherNotes: this.elements.showTeacherNotes.checked,
        autoInsert: this.elements.autoInsert.checked,
        showNotifications: this.elements.showNotifications.checked,
        keepHistory: this.elements.keepHistory.checked
      };

      await storageManager.saveSettings(settings);

      log('Settings saved:', settings);

      if (!silent) {
        this.showToast('✓ Settings saved');
      }

      // Update storage info
      await this.updateStorageInfo();

    } catch (error) {
      logError('Save settings error:', error);
      this.showToast('⚠️ Failed to save settings');
    } finally {
      this.elements.saveBtn.disabled = false;
      this.elements.saveBtn.textContent = 'Save Settings';
    }
  }

  /**
   * Reset settings to defaults
   */
  async resetSettings() {
    if (!confirm('Reset all settings to defaults? This will not delete your API keys.')) {
      return;
    }

    try {
      await storageManager.resetSettings();
      await this.loadSettings();
      this.showToast('✓ Settings reset to defaults');
    } catch (error) {
      logError('Reset settings error:', error);
      this.showToast('⚠️ Failed to reset settings');
    }
  }

  /**
   * Clear history
   */
  async clearHistory() {
    if (!confirm('Clear all history? This cannot be undone.')) {
      return;
    }

    try {
      await storageManager.clearHistory();
      await this.updateStorageInfo();
      this.showToast('✓ History cleared');
    } catch (error) {
      logError('Clear history error:', error);
      this.showToast('⚠️ Failed to clear history');
    }
  }

  /**
   * Toggle password visibility
   */
  togglePasswordVisibility(input) {
    if (input.type === 'password') {
      input.type = 'text';
    } else {
      input.type = 'password';
    }
  }

  /**
   * Test API key
   */
  async testAPIKey(provider) {
    const isOpenAI = provider === 'openai';
    const input = isOpenAI ? this.elements.openaiApiKey : this.elements.elevenlabsApiKey;
    const testBtn = isOpenAI ? this.elements.openaiTest : this.elements.elevenlabsTest;

    const apiKey = input.value.trim();

    if (!apiKey) {
      this.showToast('Please enter an API key first');
      return;
    }

    try {
      this.updateStatus(provider, 'testing');
      testBtn.disabled = true;
      testBtn.textContent = 'Testing...';

      let isValid = false;

      if (isOpenAI) {
        // Test with LLM service (simpler than STT)
        isValid = await llmService.validateAPIKey(apiKey);
      } else {
        // Test with STT service
        isValid = await sttService.validateAPIKey(provider, apiKey);
      }

      if (isValid) {
        this.updateStatus(provider, 'valid');
        this.showToast('✓ API key is valid');

        // Auto-save
        if (isOpenAI) {
          await storageManager.saveAPIKey('openai', apiKey);
        } else {
          await storageManager.saveAPIKey('elevenlabs', apiKey);
        }
      } else {
        this.updateStatus(provider, 'invalid');
        this.showToast('⚠️ API key is invalid');
      }

    } catch (error) {
      logError('Test API key error:', error);
      this.updateStatus(provider, 'invalid');
      this.showToast('⚠️ Failed to test API key');
    } finally {
      testBtn.disabled = false;
      testBtn.textContent = 'Test API Key';
    }
  }

  /**
   * Update status display
   */
  updateStatus(provider, status) {
    const statusEl = provider === 'openai' ?
      this.elements.openaiStatus :
      this.elements.elevenlabsStatus;

    statusEl.className = `status ${status}`;

    switch (status) {
      case 'valid':
        statusEl.textContent = '✓ Valid';
        break;
      case 'invalid':
        statusEl.textContent = '✗ Invalid';
        break;
      case 'testing':
        statusEl.textContent = '⏳ Testing...';
        break;
      default:
        statusEl.textContent = '';
    }
  }

  /**
   * Update storage usage info
   */
  async updateStorageInfo() {
    try {
      const usage = await storageManager.getStorageUsage();

      if (usage) {
        const syncPercent = usage.sync.percentUsed.toFixed(1);
        const localPercent = usage.local.percentUsed.toFixed(1);

        this.elements.syncUsage.textContent =
          `${(usage.sync.used / 1024).toFixed(1)} KB / 100 KB (${syncPercent}%)`;

        this.elements.localUsage.textContent =
          `${(usage.local.used / 1024).toFixed(1)} KB / 5 MB (${localPercent}%)`;
      }
    } catch (error) {
      logError('Update storage info error:', error);
    }
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
}

// Initialize settings page
const settings = new SettingsController();
settings.init();

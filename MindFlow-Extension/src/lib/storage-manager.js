/**
 * @fileoverview Secure storage manager for API keys and settings
 * @module storage-manager
 *
 * Uses chrome.storage.sync for encrypted, synced storage of sensitive data.
 * API keys and settings are automatically synced across user's Chrome installations.
 *
 * @example
 * const storage = new StorageManager();
 * await storage.saveAPIKey('openai', 'sk-...');
 * const key = await storage.getAPIKey('openai');
 */

import { STORAGE_KEYS, DEFAULT_SETTINGS, STORAGE_LIMITS } from '../common/constants.js';
import { StorageError } from '../common/errors.js';
import { log, logError, deepClone } from '../common/utils.js';

export class StorageManager {
  constructor() {
    this.storage = chrome.storage;
  }

  /**
   * Save API key securely
   * @param {string} provider - Provider name ('openai' | 'elevenlabs')
   * @param {string} key - API key
   * @returns {Promise<void>}
   * @throws {StorageError} If save fails
   */
  async saveAPIKey(provider, key) {
    if (!key || typeof key !== 'string') {
      throw new StorageError('Invalid API key');
    }

    const storageKey = provider === 'openai'
      ? STORAGE_KEYS.OPENAI_API_KEY
      : STORAGE_KEYS.ELEVENLABS_API_KEY;

    try {
      await this.storage.sync.set({ [storageKey]: key });
      log(`API key saved for ${provider}`);
    } catch (error) {
      logError('Failed to save API key:', error);
      throw new StorageError('Failed to save API key. Storage may be full.');
    }
  }

  /**
   * Get API key
   * @param {string} provider - Provider name ('openai' | 'elevenlabs')
   * @returns {Promise<string|null>} API key or null if not found
   */
  async getAPIKey(provider) {
    const storageKey = provider === 'openai'
      ? STORAGE_KEYS.OPENAI_API_KEY
      : STORAGE_KEYS.ELEVENLABS_API_KEY;

    try {
      const result = await this.storage.sync.get(storageKey);
      return result[storageKey] || null;
    } catch (error) {
      logError('Failed to get API key:', error);
      return null;
    }
  }

  /**
   * Remove API key
   * @param {string} provider - Provider name
   * @returns {Promise<void>}
   */
  async removeAPIKey(provider) {
    const storageKey = provider === 'openai'
      ? STORAGE_KEYS.OPENAI_API_KEY
      : STORAGE_KEYS.ELEVENLABS_API_KEY;

    try {
      await this.storage.sync.remove(storageKey);
      log(`API key removed for ${provider}`);
    } catch (error) {
      logError('Failed to remove API key:', error);
    }
  }

  /**
   * Save settings
   * @param {Object} settings - Settings object
   * @returns {Promise<void>}
   * @throws {StorageError} If save fails
   */
  async saveSettings(settings) {
    if (!settings || typeof settings !== 'object') {
      throw new StorageError('Invalid settings object');
    }

    // Merge with defaults to ensure all required fields exist
    const mergedSettings = {
      ...DEFAULT_SETTINGS,
      ...settings
    };

    try {
      await this.storage.sync.set({
        [STORAGE_KEYS.SETTINGS]: mergedSettings
      });
      log('Settings saved:', mergedSettings);
    } catch (error) {
      logError('Failed to save settings:', error);
      throw new StorageError('Failed to save settings');
    }
  }

  /**
   * Get settings
   * @returns {Promise<Object>} Settings object
   */
  async getSettings() {
    try {
      const result = await this.storage.sync.get(STORAGE_KEYS.SETTINGS);
      const settings = result[STORAGE_KEYS.SETTINGS];

      // Return merged with defaults to ensure all fields exist
      return {
        ...DEFAULT_SETTINGS,
        ...(settings || {})
      };
    } catch (error) {
      logError('Failed to get settings:', error);
      return deepClone(DEFAULT_SETTINGS);
    }
  }

  /**
   * Update specific setting
   * @param {string} key - Setting key
   * @param {any} value - Setting value
   * @returns {Promise<void>}
   */
  async updateSetting(key, value) {
    const settings = await this.getSettings();
    settings[key] = value;
    await this.saveSettings(settings);
  }

  /**
   * Reset settings to defaults
   * @returns {Promise<void>}
   */
  async resetSettings() {
    await this.saveSettings(deepClone(DEFAULT_SETTINGS));
    log('Settings reset to defaults');
  }

  /**
   * Save recording state (for service worker lifecycle)
   * @param {Object} state - Recording state
   * @returns {Promise<void>}
   */
  async saveRecordingState(state) {
    try {
      await this.storage.local.set({
        [STORAGE_KEYS.RECORDING_STATE]: {
          ...state,
          timestamp: Date.now()
        }
      });
      log('Recording state saved');
    } catch (error) {
      logError('Failed to save recording state:', error);
    }
  }

  /**
   * Get recording state
   * @returns {Promise<Object|null>} Recording state or null
   */
  async getRecordingState() {
    try {
      const result = await this.storage.local.get(STORAGE_KEYS.RECORDING_STATE);
      const state = result[STORAGE_KEYS.RECORDING_STATE];

      // Check if state is stale (older than 1 hour)
      if (state && Date.now() - state.timestamp > 3600000) {
        await this.clearRecordingState();
        return null;
      }

      return state || null;
    } catch (error) {
      logError('Failed to get recording state:', error);
      return null;
    }
  }

  /**
   * Clear recording state
   * @returns {Promise<void>}
   */
  async clearRecordingState() {
    try {
      await this.storage.local.remove(STORAGE_KEYS.RECORDING_STATE);
      log('Recording state cleared');
    } catch (error) {
      logError('Failed to clear recording state:', error);
    }
  }

  /**
   * Save history entry (if history feature is enabled)
   * @param {Object} entry - History entry
   * @returns {Promise<void>}
   */
  async saveHistoryEntry(entry) {
    try {
      const history = await this.getHistory();
      history.unshift({
        ...entry,
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        timestamp: Date.now()
      });

      // Keep only last 50 entries
      const trimmedHistory = history.slice(0, 50);

      await this.storage.local.set({
        [STORAGE_KEYS.HISTORY]: trimmedHistory
      });

      log('History entry saved');
    } catch (error) {
      logError('Failed to save history entry:', error);
    }
  }

  /**
   * Get history
   * @returns {Promise<Array>} History entries
   */
  async getHistory() {
    try {
      const result = await this.storage.local.get(STORAGE_KEYS.HISTORY);
      return result[STORAGE_KEYS.HISTORY] || [];
    } catch (error) {
      logError('Failed to get history:', error);
      return [];
    }
  }

  /**
   * Clear history
   * @returns {Promise<void>}
   */
  async clearHistory() {
    try {
      await this.storage.local.remove(STORAGE_KEYS.HISTORY);
      log('History cleared');
    } catch (error) {
      logError('Failed to clear history:', error);
    }
  }

  /**
   * Delete history entry
   * @param {string} id - Entry ID
   * @returns {Promise<void>}
   */
  async deleteHistoryEntry(id) {
    try {
      const history = await this.getHistory();
      const filtered = history.filter(entry => entry.id !== id);

      await this.storage.local.set({
        [STORAGE_KEYS.HISTORY]: filtered
      });

      log('History entry deleted:', id);
    } catch (error) {
      logError('Failed to delete history entry:', error);
    }
  }

  /**
   * Get storage usage info
   * @returns {Promise<Object>} Storage usage statistics
   */
  async getStorageUsage() {
    try {
      const syncUsage = await this.storage.sync.getBytesInUse();
      const localUsage = await this.storage.local.getBytesInUse();

      return {
        sync: {
          used: syncUsage,
          quota: STORAGE_LIMITS.SYNC_QUOTA_BYTES,
          percentUsed: (syncUsage / STORAGE_LIMITS.SYNC_QUOTA_BYTES) * 100
        },
        local: {
          used: localUsage,
          quota: STORAGE_LIMITS.LOCAL_QUOTA_BYTES,
          percentUsed: (localUsage / STORAGE_LIMITS.LOCAL_QUOTA_BYTES) * 100
        }
      };
    } catch (error) {
      logError('Failed to get storage usage:', error);
      return null;
    }
  }

  /**
   * Clear all data (for reset/uninstall)
   * @returns {Promise<void>}
   */
  async clearAll() {
    try {
      await this.storage.sync.clear();
      await this.storage.local.clear();
      log('All storage cleared');
    } catch (error) {
      logError('Failed to clear all storage:', error);
      throw new StorageError('Failed to clear storage');
    }
  }

  /**
   * Export all data
   * @returns {Promise<Object>} Exported data
   */
  async exportData() {
    try {
      const [syncData, localData] = await Promise.all([
        this.storage.sync.get(null),
        this.storage.local.get(null)
      ]);

      return {
        sync: syncData,
        local: localData,
        exportedAt: new Date().toISOString()
      };
    } catch (error) {
      logError('Failed to export data:', error);
      throw new StorageError('Failed to export data');
    }
  }

  /**
   * Import data (be careful - overwrites existing data)
   * @param {Object} data - Data to import
   * @returns {Promise<void>}
   */
  async importData(data) {
    if (!data || typeof data !== 'object') {
      throw new StorageError('Invalid import data');
    }

    try {
      if (data.sync) {
        await this.storage.sync.set(data.sync);
      }

      if (data.local) {
        await this.storage.local.set(data.local);
      }

      log('Data imported successfully');
    } catch (error) {
      logError('Failed to import data:', error);
      throw new StorageError('Failed to import data');
    }
  }

  /**
   * Save Supabase configuration
   * @param {Object} config - Supabase config (url, anonKey, redirectURI)
   * @returns {Promise<void>}
   */
  async saveSupabaseConfig(config) {
    try {
      await this.storage.sync.set({
        [STORAGE_KEYS.SUPABASE_CONFIG]: config
      });
      log('Supabase config saved');
    } catch (error) {
      logError('Failed to save Supabase config:', error);
      throw new StorageError('Failed to save Supabase configuration');
    }
  }

  /**
   * Get Supabase configuration
   * @returns {Promise<Object|null>}
   */
  async getSupabaseConfig() {
    try {
      const result = await this.storage.sync.get(STORAGE_KEYS.SUPABASE_CONFIG);
      return result[STORAGE_KEYS.SUPABASE_CONFIG] || null;
    } catch (error) {
      logError('Failed to get Supabase config:', error);
      return null;
    }
  }

  /**
   * Save Supabase access token
   * @param {string} token
   * @returns {Promise<void>}
   */
  async saveSupabaseAccessToken(token) {
    try {
      await this.storage.local.set({
        [STORAGE_KEYS.SUPABASE_ACCESS_TOKEN]: token
      });
      log('Supabase access token saved');
    } catch (error) {
      logError('Failed to save access token:', error);
    }
  }

  /**
   * Get Supabase access token
   * @returns {Promise<string|null>}
   */
  async getSupabaseAccessToken() {
    try {
      const result = await this.storage.local.get(STORAGE_KEYS.SUPABASE_ACCESS_TOKEN);
      return result[STORAGE_KEYS.SUPABASE_ACCESS_TOKEN] || null;
    } catch (error) {
      logError('Failed to get access token:', error);
      return null;
    }
  }

  /**
   * Save Supabase refresh token
   * @param {string} token
   * @returns {Promise<void>}
   */
  async saveSupabaseRefreshToken(token) {
    try {
      await this.storage.local.set({
        [STORAGE_KEYS.SUPABASE_REFRESH_TOKEN]: token
      });
      log('Supabase refresh token saved');
    } catch (error) {
      logError('Failed to save refresh token:', error);
    }
  }

  /**
   * Get Supabase refresh token
   * @returns {Promise<string|null>}
   */
  async getSupabaseRefreshToken() {
    try {
      const result = await this.storage.local.get(STORAGE_KEYS.SUPABASE_REFRESH_TOKEN);
      return result[STORAGE_KEYS.SUPABASE_REFRESH_TOKEN] || null;
    } catch (error) {
      logError('Failed to get refresh token:', error);
      return null;
    }
  }

  /**
   * Save Supabase user info
   * @param {Object} userInfo
   * @returns {Promise<void>}
   */
  async saveSupabaseUserInfo(userInfo) {
    try {
      await this.storage.local.set({
        [STORAGE_KEYS.SUPABASE_USER_INFO]: userInfo
      });
      log('Supabase user info saved');
    } catch (error) {
      logError('Failed to save user info:', error);
    }
  }

  /**
   * Get Supabase user info
   * @returns {Promise<Object|null>}
   */
  async getSupabaseUserInfo() {
    try {
      const result = await this.storage.local.get(STORAGE_KEYS.SUPABASE_USER_INFO);
      return result[STORAGE_KEYS.SUPABASE_USER_INFO] || null;
    } catch (error) {
      logError('Failed to get user info:', error);
      return null;
    }
  }

  /**
   * Clear all Supabase credentials
   * @returns {Promise<void>}
   */
  async clearSupabaseCredentials() {
    try {
      await this.storage.local.remove([
        STORAGE_KEYS.SUPABASE_ACCESS_TOKEN,
        STORAGE_KEYS.SUPABASE_REFRESH_TOKEN,
        STORAGE_KEYS.SUPABASE_USER_INFO
      ]);
      log('Supabase credentials cleared');
    } catch (error) {
      logError('Failed to clear Supabase credentials:', error);
    }
  }
}

// Export singleton instance
export default new StorageManager();

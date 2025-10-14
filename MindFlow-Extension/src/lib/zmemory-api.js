/**
 * @fileoverview ZMemory API client for MindFlow browser extension
 * @module zmemory-api
 *
 * Handles communication with ZephyrOS backend
 * Sends voice-to-text interaction records
 * Syncs with Zflow platform
 */

import { log, logError } from '../common/utils.js';
import supabaseAuth from './supabase-auth.js';

export class ZMemoryAPIClient {
  constructor() {
    // Default to production ZMemory API
    this.baseURL = 'https://zmemory.zephyros.app';
    this.initialized = false;
  }

  /**
   * Initialize and load config from storage
   */
  async initialize() {
    if (this.initialized) return;

    const storageManager = (await import('./storage-manager.js')).default;
    const config = await storageManager.getSupabaseConfig();

    if (config && config.zmemoryUrl) {
      this.baseURL = config.zmemoryUrl;
      log('ZMemory API loaded from config:', this.baseURL);
    } else {
      log('ZMemory API using default URL:', this.baseURL);
    }

    this.initialized = true;
  }

  /**
   * Set custom base URL
   * @param {string} url - Base URL for ZMemory API
   */
  setBaseURL(url) {
    this.baseURL = url;
    log('ZMemory API base URL set to:', url);
  }

  /**
   * Create a new MindFlow STT interaction record
   * @param {Object} interaction - Interaction data
   * @returns {Promise<Object>} Created interaction record
   */
  async createInteraction(interaction) {
    // Ensure initialized
    await this.initialize();

    const accessToken = supabaseAuth.getAccessToken();

    if (!accessToken) {
      throw new Error('Not authenticated. Please sign in first.');
    }

    const url = `${this.baseURL}/api/mindflow-stt-interactions`;

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

    log('📤 Creating interaction record');
    log('🌐 Base URL:', this.baseURL);
    log('🌐 Full URL:', url);
    log('📦 Request body:', JSON.stringify(requestBody, null, 2));
    log('🔑 Access token present:', !!accessToken);
    log('🔑 Token (first 20 chars):', accessToken ? accessToken.substring(0, 20) + '...' : 'none');

    const requestOptions = {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    };

    log('📋 Request options:', {
      method: requestOptions.method,
      headers: requestOptions.headers,
      bodyLength: requestOptions.body.length
    });

    // Test if the URL is accessible first
    try {
      log('🧪 Testing base URL accessibility...');
      const testResponse = await fetch(this.baseURL, { method: 'HEAD' }).catch(e => {
        log('⚠️ Base URL test failed:', e.message);
        return null;
      });
      if (testResponse) {
        log('✅ Base URL is accessible, status:', testResponse.status);
      }
    } catch (e) {
      log('⚠️ Base URL test error:', e);
    }

    try {
      log('🚀 Sending fetch request...');
      const response = await fetch(url, requestOptions);

      log('📥 Response received');
      log('📥 Response status:', response.status);
      log('📥 Response statusText:', response.statusText);
      log('📥 Response URL:', response.url);
      log('📥 Response headers:', JSON.stringify([...response.headers.entries()]));

      if (!response.ok) {
        const responseText = await response.text();
        log('❌ Error response body:', responseText);

        let errorData = {};
        try {
          errorData = JSON.parse(responseText);
        } catch (e) {
          logError('Could not parse error response as JSON');
        }

        const errorMessage = errorData.message || errorData.error || responseText || `HTTP ${response.status}`;
        logError('Failed to create interaction:', errorMessage);
        throw new Error(`Failed to create interaction: ${errorMessage}`);
      }

      const data = await response.json();
      log('✅ Interaction created successfully:', data.interaction.id);

      return data.interaction;
    } catch (error) {
      logError('❌ Create interaction error:', error);
      logError('Error stack:', error.stack);
      throw error;
    }
  }

  /**
   * Get all interactions for authenticated user
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Array of interaction records
   */
  async getInteractions(options = {}) {
    const accessToken = supabaseAuth.getAccessToken();

    if (!accessToken) {
      throw new Error('Not authenticated. Please sign in first.');
    }

    // Build query parameters
    const params = new URLSearchParams();

    if (options.transcriptionApi) {
      params.append('transcription_api', options.transcriptionApi);
    }
    if (options.optimizationLevel) {
      params.append('optimization_level', options.optimizationLevel);
    }
    if (options.limit) {
      params.append('limit', options.limit.toString());
    }
    if (options.offset) {
      params.append('offset', options.offset.toString());
    }

    const queryString = params.toString();
    const url = `${this.baseURL}/api/mindflow-stt-interactions${queryString ? '?' + queryString : ''}`;

    log('Fetching interactions...', options);

    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const errorMessage = errorData.message || `HTTP ${response.status}`;
        logError('Failed to fetch interactions:', errorMessage);
        throw new Error(`Failed to fetch interactions: ${errorMessage}`);
      }

      const data = await response.json();
      log(`Fetched ${data.interactions.length} interactions`);

      return data.interactions;
    } catch (error) {
      logError('Fetch interactions error:', error);
      throw error;
    }
  }

  /**
   * Get a single interaction by ID
   * @param {string} id - Interaction ID (UUID)
   * @returns {Promise<Object>} Interaction record
   */
  async getInteraction(id) {
    const accessToken = supabaseAuth.getAccessToken();

    if (!accessToken) {
      throw new Error('Not authenticated. Please sign in first.');
    }

    const url = `${this.baseURL}/api/mindflow-stt-interactions/${id}`;

    log('Fetching interaction:', id);

    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const errorMessage = errorData.message || `HTTP ${response.status}`;
        logError('Failed to fetch interaction:', errorMessage);
        throw new Error(`Failed to fetch interaction: ${errorMessage}`);
      }

      const data = await response.json();
      log('Interaction fetched successfully');

      return data.interaction;
    } catch (error) {
      logError('Fetch interaction error:', error);
      throw error;
    }
  }

  /**
   * Delete an interaction by ID
   * @param {string} id - Interaction ID (UUID)
   * @returns {Promise<void>}
   */
  async deleteInteraction(id) {
    const accessToken = supabaseAuth.getAccessToken();

    if (!accessToken) {
      throw new Error('Not authenticated. Please sign in first.');
    }

    const url = `${this.baseURL}/api/mindflow-stt-interactions/${id}`;

    log('Deleting interaction:', id);

    try {
      const response = await fetch(url, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const errorMessage = errorData.message || `HTTP ${response.status}`;
        logError('Failed to delete interaction:', errorMessage);
        throw new Error(`Failed to delete interaction: ${errorMessage}`);
      }

      log('Interaction deleted successfully');
    } catch (error) {
      logError('Delete interaction error:', error);
      throw error;
    }
  }

  /**
   * Check if user is authenticated
   * @returns {boolean}
   */
  isAuthenticated() {
    return supabaseAuth.isAuthenticated;
  }

  /**
   * Get current user info
   * @returns {Object}
   */
  getUserInfo() {
    return supabaseAuth.getUserInfo();
  }
}

// Export singleton instance
export default new ZMemoryAPIClient();

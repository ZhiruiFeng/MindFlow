/**
 * @fileoverview Supabase authentication service for browser extension
 * @module supabase-auth
 *
 * Handles Supabase OAuth authentication with Google provider
 * Manages user session state and token storage
 * Syncs with ZephyrOS ecosystem
 */

import { log, logError } from '../common/utils.js';
import storageManager from './storage-manager.js';

export class SupabaseAuthService {
  constructor() {
    this.isAuthenticated = false;
    this.accessToken = null;
    this.userEmail = null;
    this.userName = null;
    this.userId = null;

    // Configuration - should match macOS app
    this.supabaseURL = null;
    this.supabaseAnonKey = null;
    this.redirectURI = null;
  }

  /**
   * Initialize the auth service
   */
  async initialize() {
    // Load configuration from storage
    await this.loadConfiguration();

    // Try to restore existing session
    await this.restoreSession();

    log('SupabaseAuthService initialized', {
      isAuthenticated: this.isAuthenticated,
      userEmail: this.userEmail
    });
  }

  /**
   * Load configuration from storage
   */
  async loadConfiguration() {
    try {
      const config = await storageManager.getSupabaseConfig();

      if (config) {
        this.supabaseURL = config.url;
        this.supabaseAnonKey = config.anonKey;
        this.redirectURI = config.redirectURI || chrome.identity.getRedirectURL();
      } else {
        // Use default values
        this.redirectURI = chrome.identity.getRedirectURL();
        log('⚠️ Supabase configuration not found in storage');
      }
    } catch (error) {
      logError('Failed to load Supabase configuration:', error);
      this.redirectURI = chrome.identity.getRedirectURL();
    }
  }

  /**
   * Check if configured
   */
  isConfigured() {
    return !!(this.supabaseURL && this.supabaseAnonKey);
  }

  /**
   * Save configuration
   */
  async saveConfiguration(url, anonKey) {
    await storageManager.saveSupabaseConfig({
      url,
      anonKey,
      redirectURI: this.redirectURI
    });

    this.supabaseURL = url;
    this.supabaseAnonKey = anonKey;

    log('Supabase configuration saved');
  }

  /**
   * Initiate Google OAuth sign-in flow
   * Uses chrome.identity API for OAuth in browser extension
   */
  async signIn() {
    if (!this.isConfigured()) {
      throw new Error('Supabase is not configured. Please add Supabase URL and Anon Key in settings.');
    }

    try {
      log('Starting OAuth sign-in flow...');

      // Build Supabase OAuth URL
      const authURL = this.buildSupabaseAuthURL();

      log('Auth URL:', authURL);

      // Launch OAuth flow using chrome.identity
      const responseURL = await new Promise((resolve, reject) => {
        chrome.identity.launchWebAuthFlow(
          {
            url: authURL,
            interactive: true
          },
          (redirectURL) => {
            if (chrome.runtime.lastError) {
              reject(new Error(chrome.runtime.lastError.message));
            } else {
              resolve(redirectURL);
            }
          }
        );
      });

      log('OAuth callback received');

      // Handle the callback
      await this.handleCallback(responseURL);

      log('Sign-in successful');

      return true;
    } catch (error) {
      logError('Sign-in failed:', error);
      throw error;
    }
  }

  /**
   * Sign out the current user
   */
  async signOut() {
    this.accessToken = null;
    this.userEmail = null;
    this.userName = null;
    this.userId = null;
    this.isAuthenticated = false;

    await this.clearStoredCredentials();

    log('User signed out');
  }

  /**
   * Restore session from stored credentials
   */
  async restoreSession() {
    try {
      const token = await storageManager.getSupabaseAccessToken();

      if (!token) {
        log('No stored access token found');
        return false;
      }

      if (!this.isConfigured()) {
        log('Supabase not configured, cannot restore session');
        return false;
      }

      // Validate token by fetching user info
      await this.fetchUserInfo(token);

      this.accessToken = token;
      this.isAuthenticated = true;

      log('Session restored successfully');
      return true;
    } catch (error) {
      logError('Failed to restore session:', error);
      await this.signOut();
      return false;
    }
  }

  /**
   * Get current user info
   */
  getUserInfo() {
    return {
      isAuthenticated: this.isAuthenticated,
      userId: this.userId,
      email: this.userEmail,
      name: this.userName
    };
  }

  /**
   * Get access token
   */
  getAccessToken() {
    return this.accessToken;
  }

  /**
   * Build Supabase OAuth URL
   * @private
   */
  buildSupabaseAuthURL() {
    const params = new URLSearchParams({
      provider: 'google',
      redirect_to: this.redirectURI
    });

    return `${this.supabaseURL}/auth/v1/authorize?${params.toString()}`;
  }

  /**
   * Handle OAuth callback
   * @private
   */
  async handleCallback(callbackURL) {
    if (!callbackURL) {
      throw new Error('No callback URL received');
    }

    log('Processing callback URL...');

    // Parse the callback URL
    const url = new URL(callbackURL);

    // Supabase returns tokens in the URL fragment
    const fragment = url.hash.substring(1); // Remove '#'

    if (!fragment) {
      throw new Error('Invalid callback URL format - no fragment');
    }

    const params = this.parseFragmentParameters(fragment);

    const accessToken = params['access_token'];
    const refreshToken = params['refresh_token'];

    if (!accessToken) {
      throw new Error('No access token found in callback');
    }

    // Store tokens
    this.accessToken = accessToken;
    await storageManager.saveSupabaseAccessToken(accessToken);

    if (refreshToken) {
      await storageManager.saveSupabaseRefreshToken(refreshToken);
    }

    // Fetch user info
    await this.fetchUserInfo(accessToken);

    this.isAuthenticated = true;
  }

  /**
   * Parse fragment parameters from URL
   * @private
   */
  parseFragmentParameters(fragment) {
    const params = {};

    fragment.split('&').forEach(param => {
      const [key, value] = param.split('=');
      if (key && value) {
        params[key] = decodeURIComponent(value);
      }
    });

    return params;
  }

  /**
   * Fetch user info from Supabase
   * @private
   */
  async fetchUserInfo(token) {
    const url = `${this.supabaseURL}/auth/v1/user`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': this.supabaseAnonKey
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch user info: ${response.status}`);
    }

    const userInfo = await response.json();

    this.userId = userInfo.id;
    this.userEmail = userInfo.email;
    this.userName = userInfo.user_metadata?.full_name || userInfo.email;

    await this.storeUserInfo();

    log('User info fetched:', { email: this.userEmail, name: this.userName });
  }

  /**
   * Store user info in storage
   * @private
   */
  async storeUserInfo() {
    const userInfo = {
      userId: this.userId,
      email: this.userEmail,
      name: this.userName
    };

    await storageManager.saveSupabaseUserInfo(userInfo);
  }

  /**
   * Clear stored credentials
   * @private
   */
  async clearStoredCredentials() {
    await storageManager.clearSupabaseCredentials();
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshAccessToken() {
    try {
      const refreshToken = await storageManager.getSupabaseRefreshToken();

      if (!refreshToken) {
        throw new Error('No refresh token available');
      }

      if (!this.isConfigured()) {
        throw new Error('Supabase not configured');
      }

      const response = await fetch(`${this.supabaseURL}/auth/v1/token?grant_type=refresh_token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.supabaseAnonKey
        },
        body: JSON.stringify({
          refresh_token: refreshToken
        })
      });

      if (!response.ok) {
        throw new Error(`Token refresh failed: ${response.status}`);
      }

      const data = await response.json();

      this.accessToken = data.access_token;
      await storageManager.saveSupabaseAccessToken(data.access_token);

      if (data.refresh_token) {
        await storageManager.saveSupabaseRefreshToken(data.refresh_token);
      }

      log('Access token refreshed');
      return data.access_token;
    } catch (error) {
      logError('Token refresh failed:', error);
      // Sign out on refresh failure
      await this.signOut();
      throw error;
    }
  }
}

// Export singleton instance
export default new SupabaseAuthService();

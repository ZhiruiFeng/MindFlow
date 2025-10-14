/**
 * @fileoverview Utility functions
 * @module utils
 */

import { VALIDATION, ERROR_MESSAGES } from './constants.js';

/**
 * Format duration in seconds to MM:SS
 * @param {number} seconds - Duration in seconds
 * @returns {string} Formatted time string
 */
export function formatDuration(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

/**
 * Validate API key format
 * @param {string} apiKey - API key to validate
 * @returns {boolean} True if valid format
 */
export function validateApiKeyFormat(apiKey) {
  if (!apiKey || typeof apiKey !== 'string') {
    return false;
  }

  return apiKey.length >= VALIDATION.API_KEY_MIN_LENGTH;
}

/**
 * Sanitize text for safe display
 * @param {string} text - Text to sanitize
 * @returns {string} Sanitized text
 */
export function sanitizeText(text) {
  if (typeof text !== 'string') {
    return '';
  }

  // Remove potentially dangerous characters
  return text
    .replace(/[<>]/g, '')
    .trim();
}

/**
 * Truncate text to maximum length
 * @param {string} text - Text to truncate
 * @param {number} maxLength - Maximum length
 * @returns {string} Truncated text
 */
export function truncateText(text, maxLength = VALIDATION.MAX_TEXT_LENGTH) {
  if (!text || text.length <= maxLength) {
    return text;
  }

  return text.substring(0, maxLength) + '...';
}

/**
 * Delay execution for specified milliseconds
 * @param {number} ms - Milliseconds to delay
 * @returns {Promise<void>}
 */
export function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Generate a unique ID
 * @returns {string} Unique identifier
 */
export function generateId() {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Deep clone an object
 * @param {Object} obj - Object to clone
 * @returns {Object} Cloned object
 */
export function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

/**
 * Check if extension is running in development mode
 * @returns {boolean} True if in development
 */
export function isDevelopment() {
  return !('update_url' in chrome.runtime.getManifest());
}

/**
 * Log message (only in development)
 * @param {...any} args - Arguments to log
 */
export function log(...args) {
  if (isDevelopment()) {
    console.log('[MindFlow]', ...args);
  }
}

/**
 * Log error (always logs)
 * @param {...any} args - Arguments to log
 */
export function logError(...args) {
  // Serialize objects for better error display
  const serialized = args.map(arg => {
    if (arg && typeof arg === 'object' && !(arg instanceof Error)) {
      try {
        return JSON.stringify(arg);
      } catch {
        return String(arg);
      }
    }
    return arg;
  });
  console.error('[MindFlow Error]', ...serialized);
}

/**
 * Convert Blob to Base64
 * @param {Blob} blob - Blob to convert
 * @returns {Promise<string>} Base64 string
 */
export function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

/**
 * Get user-friendly error message
 * @param {Error} error - Error object
 * @returns {string} User-friendly error message
 */
export function getUserErrorMessage(error) {
  if (!error) {
    return ERROR_MESSAGES.UNKNOWN_ERROR;
  }

  // If error is a string, return it
  if (typeof error === 'string') {
    return error;
  }

  // Get the message from the error object
  const message = error.message || error.toString();

  // Check for specific error types
  if (message.includes('API key') || message.includes('401')) {
    return ERROR_MESSAGES.INVALID_API_KEY;
  }

  if (message.includes('429') || message.includes('rate limit')) {
    return ERROR_MESSAGES.RATE_LIMIT;
  }

  if (message.includes('network') || message.includes('fetch') || message.includes('Failed to fetch')) {
    return ERROR_MESSAGES.NETWORK_ERROR;
  }

  if (message.includes('microphone') || message.includes('Microphone')) {
    return ERROR_MESSAGES.NO_MICROPHONE;
  }

  if (message.includes('NotAllowedError') || message.includes('Permission')) {
    return ERROR_MESSAGES.NO_MICROPHONE;
  }

  // Return the error message if it's already user-friendly
  if (message && !message.includes('TypeError') &&
      !message.includes('undefined') &&
      !message.includes('[object')) {
    return message;
  }

  return ERROR_MESSAGES.UNKNOWN_ERROR;
}

/**
 * Debounce function execution
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in milliseconds
 * @returns {Function} Debounced function
 */
export function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Check if value is empty
 * @param {any} value - Value to check
 * @returns {boolean} True if empty
 */
export function isEmpty(value) {
  if (value === null || value === undefined) {
    return true;
  }

  if (typeof value === 'string') {
    return value.trim().length === 0;
  }

  if (Array.isArray(value)) {
    return value.length === 0;
  }

  if (typeof value === 'object') {
    return Object.keys(value).length === 0;
  }

  return false;
}

/**
 * Safely parse JSON
 * @param {string} jsonString - JSON string to parse
 * @param {any} defaultValue - Default value if parsing fails
 * @returns {any} Parsed object or default value
 */
export function safeJSONParse(jsonString, defaultValue = null) {
  try {
    return JSON.parse(jsonString);
  } catch (error) {
    logError('JSON parse error:', error);
    return defaultValue;
  }
}

/**
 * Copy text to clipboard
 * @param {string} text - Text to copy
 * @returns {Promise<boolean>} True if successful
 */
export async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (error) {
    logError('Clipboard copy failed:', error);
    return false;
  }
}

/**
 * Show browser notification
 * @param {string} title - Notification title
 * @param {string} message - Notification message
 * @param {string} type - Notification type ('basic', 'error', 'success')
 */
export function showNotification(title, message, type = 'basic') {
  if (!chrome.notifications) {
    return;
  }

  const iconUrl = type === 'error'
    ? 'assets/icons/icon-128-error.png'
    : 'assets/icons/icon-128.png';

  chrome.notifications.create({
    type: 'basic',
    iconUrl: iconUrl,
    title: title,
    message: message,
    priority: type === 'error' ? 2 : 1
  });
}
